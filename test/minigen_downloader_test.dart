import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifelens/services/minigen_downloader.dart';

// Builds a minimal byte buffer that passes both the GGUF-header check and
// MiniGenDownloader's key scanner.  The scanner does a raw byte search for
// the key string, then looks for known value strings in the 128 bytes that
// follow — so a "real" GGUF binary structure is not required here.
Uint8List _minimalScannerGguf({
  required String arch,
  required String tokenizer,
}) {
  final bytes = <int>[];
  bytes.addAll([0x47, 0x47, 0x55, 0x46]); // "GGUF" magic
  bytes.addAll(List.filled(20, 0)); // version + tensor/metadata count stubs
  bytes.addAll('general.architecture'.codeUnits);
  bytes.addAll(List.filled(8, 0));
  bytes.addAll(arch.codeUnits);
  bytes.addAll(List.filled(8, 0));
  bytes.addAll('tokenizer.ggml.pre'.codeUnits);
  bytes.addAll(List.filled(8, 0));
  bytes.addAll(tokenizer.codeUnits);
  return Uint8List.fromList(bytes);
}

// Builds a minimal but structurally-valid GGUF that patchGgufBytes can parse.
Uint8List _validGguf({required String arch, required String tokenizer}) {
  final buf = BytesBuilder(copy: false);

  void writeUint32(int v) {
    final b = Uint8List(4);
    ByteData.sublistView(b).setUint32(0, v, Endian.little);
    buf.add(b);
  }

  void writeUint64(int v) {
    final b = Uint8List(8);
    ByteData.sublistView(b).setUint64(0, v, Endian.little);
    buf.add(b);
  }

  void writeGgufString(String s) {
    writeUint64(s.length);
    buf.add(s.codeUnits);
  }

  void writeStringMetadata(String key, String value) {
    writeGgufString(key);
    writeUint32(8); // type STRING
    writeGgufString(value);
  }

  buf.add([0x47, 0x47, 0x55, 0x46]); // magic
  writeUint32(3); // version
  writeUint64(0); // tensor_count
  writeUint64(2); // metadata_count
  writeStringMetadata('general.architecture', arch);
  writeStringMetadata('tokenizer.ggml.pre', tokenizer);
  // Pad metadata block to 32-byte alignment so the patch code can compute
  // originalDataStart without going out of range.
  final unpadded = buf.toBytes();
  final aligned = ((unpadded.length + 31) ~/ 32) * 32;
  final result = Uint8List(aligned);
  result.setRange(0, unpadded.length, unpadded);
  return result;
}

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('gguf_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('inspectModelCompatibility', () {
    test('missing file → isGguf:false, canAttemptLoad:false', () {
      final file = File('${tmpDir.path}/nonexistent.gguf');
      final r = MiniGenDownloader.inspectModelCompatibility(file);
      expect(r.isGguf, isFalse);
      expect(r.canAttemptLoad, isFalse);
    });

    test('non-GGUF file → isGguf:false', () {
      final file = File('${tmpDir.path}/bad.bin')
        ..writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);
      final r = MiniGenDownloader.inspectModelCompatibility(file);
      expect(r.isGguf, isFalse);
      expect(r.canAttemptLoad, isFalse);
    });

    test('llama / gpt2 → needs patching (canAttemptLoad:false)', () {
      final file = File('${tmpDir.path}/llama.gguf')
        ..writeAsBytesSync(_minimalScannerGguf(arch: 'llama', tokenizer: 'gpt2'));
      final r = MiniGenDownloader.inspectModelCompatibility(file);
      expect(r.isGguf, isTrue);
      expect(r.canAttemptLoad, isFalse);
      expect(r.architecture, 'llama');
    });

    test('qwen3 / gpt-2 → ready to load (canAttemptLoad:true)', () {
      final file = File('${tmpDir.path}/qwen3.gguf')
        ..writeAsBytesSync(_minimalScannerGguf(arch: 'qwen3', tokenizer: 'gpt-2'));
      final r = MiniGenDownloader.inspectModelCompatibility(file);
      expect(r.isGguf, isTrue);
      expect(r.canAttemptLoad, isTrue);
      expect(r.architecture, 'qwen3');
    });
  });

  group('patchGgufBytes', () {
    test('patches llama/gpt2 → qwen3/gpt-2; output is loadable', () {
      final source = _validGguf(arch: 'llama', tokenizer: 'gpt2');
      final patched = MiniGenDownloader.patchGgufBytes(source);

      final patchedFile = File('${tmpDir.path}/patched.gguf')
        ..writeAsBytesSync(patched, flush: true);
      final r = MiniGenDownloader.inspectModelCompatibility(patchedFile);
      expect(r.isGguf, isTrue);
      expect(r.canAttemptLoad, isTrue);
      expect(r.architecture, 'qwen3');
    });

    test('is idempotent on already-patched qwen3/gpt-2 input', () {
      final source = _validGguf(arch: 'qwen3', tokenizer: 'gpt-2');
      final patched = MiniGenDownloader.patchGgufBytes(source);

      final patchedFile = File('${tmpDir.path}/already_qwen3.gguf')
        ..writeAsBytesSync(patched, flush: true);
      final r = MiniGenDownloader.inspectModelCompatibility(patchedFile);
      expect(r.isGguf, isTrue);
      expect(r.canAttemptLoad, isTrue);
    });

    test('throws StateError on unsupported architecture', () {
      final source = _validGguf(arch: 'gpt2', tokenizer: 'gpt2');
      expect(
        () => MiniGenDownloader.patchGgufBytes(source),
        throwsA(isA<StateError>()),
      );
    });
  });
}
