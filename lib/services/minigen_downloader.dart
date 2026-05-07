import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:path_provider/path_provider.dart';

/// Downloads the MiniGen F16 GGUF model from HuggingFace on first launch.
///
/// The model is stored in [getApplicationSupportDirectory] to avoid
/// polluting the iOS iCloud backup quota (Documents/ is backed up).
///
/// NOTE: logic may be incorrect -- this is replacing our old version.
class MiniGenDownloader {
  MiniGenDownloader._();

  static const String _url =
      'https://huggingface.co/testingtest111/minigen-f16/resolve/main/minigen-f16.gguf?download=true';

  static const String _filename = 'minigen-f16.gguf';
  static const String _compatibleFilename = 'minigen-f16-qwen3-compat.gguf';
  static const int _expectedBytes = 96065248;
  static const String _sourceArchitecture = 'llama';
  static const String _compatibleArchitecture = 'qwen3';
  static const String _sourceArchitecturePrefix = 'llama.';
  static const String _compatibleArchitecturePrefix = 'qwen3.';
  static const String _sourcePretokenizer = 'gpt2';
  static const String _compatiblePretokenizer = 'gpt-2';

  /// Returns the local filesystem path to the GGUF model file.
  /// Downloads it from HuggingFace if not already present.
  ///
  /// [onProgress] receives values from 0.0 to 1.0.
  static Future<String> ensureModel({
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_filename');
    final compatibleFile = File('${dir.path}/$_compatibleFilename');

    if (compatibleFile.existsSync()) {
      final compatibility = inspectModelCompatibility(compatibleFile);
      if (compatibility.canAttemptLoad) {
        debugPrint(
          '[MiniGenDownloader] compatible model already present: '
          '${compatibleFile.path} (${compatibleFile.lengthSync()} bytes)',
        );
        return compatibleFile.path;
      }
      debugPrint(
        '[MiniGenDownloader] deleting invalid compatible model: '
        '${compatibleFile.path}',
      );
      compatibleFile.deleteSync();
    }

    if (file.existsSync() && _hasExpectedDownloadShape(file)) {
      final compatibility = inspectModelCompatibility(file);
      if (compatibility.canAttemptLoad) {
        debugPrint(
          '[MiniGenDownloader] model already present: ${file.path} '
          '(${file.lengthSync()} bytes)',
        );
        return file.path;
      }
      debugPrint(
        '[MiniGenDownloader] creating compatible MiniGen copy: '
        '$compatibility',
      );
      return _writeCompatibleCopy(file, compatibleFile);
    }

    if (file.existsSync()) {
      debugPrint(
        '[MiniGenDownloader] deleting invalid cached model: ${file.path} '
        '(${file.lengthSync()} bytes)',
      );
      file.deleteSync();
    }

    debugPrint('[MiniGenDownloader] downloading model to ${file.path}');

    final dio = Dio();
    try {
      await dio.download(
        _url,
        file.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );
    } catch (e) {
      // Clean up partial download on failure
      if (file.existsSync()) {
        file.deleteSync();
      }
      rethrow;
    } finally {
      dio.close();
    }

    if (!_hasExpectedDownloadShape(file)) {
      final size = file.existsSync() ? file.lengthSync() : 0;
      if (file.existsSync()) {
        file.deleteSync();
      }
      throw StateError(
        'Downloaded MiniGen model failed validation '
        '(bytes=$size, expected=$_expectedBytes).',
      );
    }

    final compatibility = inspectModelCompatibility(file);
    if (compatibility.canAttemptLoad) {
      debugPrint(
        '[MiniGenDownloader] download complete (${file.lengthSync()} bytes)',
      );
      return file.path;
    }

    debugPrint(
      '[MiniGenDownloader] download complete; creating compatible MiniGen copy: '
      '$compatibility',
    );
    return _writeCompatibleCopy(file, compatibleFile);
  }

  /// Check if the model file already exists locally.
  static Future<bool> isModelAvailable() async {
    final dir = await getApplicationSupportDirectory();
    final compatibleFile = File('${dir.path}/$_compatibleFilename');
    if (compatibleFile.existsSync() &&
        inspectModelCompatibility(compatibleFile).canAttemptLoad) {
      return true;
    }
    return _hasExpectedDownloadShape(File('${dir.path}/$_filename'));
  }

  /// Delete the cached model file (e.g. to force re-download).
  static Future<void> deleteModel() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_filename');
    if (file.existsSync()) {
      file.deleteSync();
      debugPrint('[MiniGenDownloader] deleted cached model');
    }
    final compatibleFile = File('${dir.path}/$_compatibleFilename');
    if (compatibleFile.existsSync()) {
      compatibleFile.deleteSync();
      debugPrint('[MiniGenDownloader] deleted compatible cached model');
    }
  }

  static bool _hasExpectedDownloadShape(File file) {
    if (!file.existsSync() || file.lengthSync() != _expectedBytes) {
      return false;
    }
    return inspectModelCompatibility(file).isGguf;
  }

  static MiniGenModelCompatibility inspectModelCompatibility(File file) {
    if (!file.existsSync()) {
      return const MiniGenModelCompatibility(
        isGguf: false,
        canAttemptLoad: false,
        reason: 'model file is missing',
      );
    }

    final reader = file.openSync();
    try {
      final data = reader.readSync(1024 * 1024);
      final isGguf =
          data.length >= 4 &&
          data[0] == 0x47 &&
          data[1] == 0x47 &&
          data[2] == 0x55 &&
          data[3] == 0x46;
      if (!isGguf) {
        return const MiniGenModelCompatibility(
          isGguf: false,
          canAttemptLoad: false,
          reason: 'model file does not start with GGUF header',
        );
      }

      final architecture = _findAsciiMetadataValue(
        data,
        'general.architecture',
      );
      final tokenizerPre = _findAsciiMetadataValue(data, 'tokenizer.ggml.pre');
      if (architecture == _compatibleArchitecture &&
          tokenizerPre == _compatiblePretokenizer) {
        return MiniGenModelCompatibility(
          isGguf: true,
          canAttemptLoad: true,
          architecture: architecture,
          tokenizerPretokenizer: tokenizerPre,
        );
      }
      if (architecture == _sourceArchitecture) {
        return MiniGenModelCompatibility(
          isGguf: true,
          canAttemptLoad: false,
          architecture: architecture,
          tokenizerPretokenizer: tokenizerPre,
          reason:
              'MiniGen tensors include per-layer q/k norms; bundled llama.cpp '
              'loads them through general.architecture=$_compatibleArchitecture',
        );
      }
      if (tokenizerPre == _sourcePretokenizer) {
        return MiniGenModelCompatibility(
          isGguf: true,
          canAttemptLoad: false,
          architecture: architecture,
          tokenizerPretokenizer: tokenizerPre,
          reason:
              'bundled llama.cpp expects tokenizer.ggml.pre=$_compatiblePretokenizer',
        );
      }

      return MiniGenModelCompatibility(
        isGguf: true,
        canAttemptLoad: true,
        architecture: architecture,
        tokenizerPretokenizer: tokenizerPre,
      );
    } finally {
      reader.closeSync();
    }
  }

  static String? _findAsciiMetadataValue(List<int> data, String key) {
    final keyBytes = key.codeUnits;
    for (var i = 0; i <= data.length - keyBytes.length; i++) {
      var matches = true;
      for (var j = 0; j < keyBytes.length; j++) {
        if (data[i + j] != keyBytes[j]) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;

      final searchStart = i + keyBytes.length;
      final searchEnd = (searchStart + 128).clamp(0, data.length);
      for (var j = searchStart; j <= searchEnd - 5; j++) {
        if (data[j] == 0x71 &&
            data[j + 1] == 0x77 &&
            data[j + 2] == 0x65 &&
            data[j + 3] == 0x6e &&
            data[j + 4] == 0x33) {
          return _compatibleArchitecture;
        }
      }
      for (var j = searchStart; j <= searchEnd - 5; j++) {
        if (data[j] == 0x6c &&
            data[j + 1] == 0x6c &&
            data[j + 2] == 0x61 &&
            data[j + 3] == 0x6d &&
            data[j + 4] == 0x61) {
          return _sourceArchitecture;
        }
      }
      for (var j = searchStart; j <= searchEnd - 5; j++) {
        if (data[j] == 0x67 &&
            data[j + 1] == 0x70 &&
            data[j + 2] == 0x74 &&
            data[j + 3] == 0x2d &&
            data[j + 4] == 0x32) {
          return _compatiblePretokenizer;
        }
      }
      for (var j = searchStart; j <= searchEnd - 4; j++) {
        if (data[j] == 0x67 &&
            data[j + 1] == 0x70 &&
            data[j + 2] == 0x74 &&
            data[j + 3] == 0x32) {
          return _sourcePretokenizer;
        }
      }
    }
    return null;
  }

  static String _writeCompatibleCopy(File source, File destination) {
    final bytes = source.readAsBytesSync();
    final patched = patchGgufBytes(bytes);
    destination.writeAsBytesSync(patched, flush: true);

    final compatibility = inspectModelCompatibility(destination);
    if (!compatibility.canAttemptLoad) {
      if (destination.existsSync()) {
        destination.deleteSync();
      }
      throw StateError(
        'Failed to create compatible MiniGen model: $compatibility',
      );
    }

    debugPrint(
      '[MiniGenDownloader] compatible MiniGen model ready: '
      '${destination.path} (${destination.lengthSync()} bytes)',
    );
    return destination.path;
  }

  @visibleForTesting
  static Uint8List patchGgufBytes(Uint8List bytes) {
    final patchedBytes = Uint8List.fromList(bytes);
    final reader = _GgufReader(patchedBytes);
    if (reader.readAscii(4) != 'GGUF') {
      throw StateError('MiniGen model does not start with GGUF header.');
    }

    reader.skip(4); // version
    final tensorCount = reader.readUint64();
    final metadataCount = reader.readUint64();

    var alignment = 32;
    final metadata = <_GgufMetadataEntry>[];
    for (var index = 0; index < metadataCount; index++) {
      final entryStart = reader.offset;
      final keyStart = reader.offset;
      final key = reader.readString();
      final valueTypeOffset = reader.offset;
      final valueType = reader.readUint32();
      final valueStart = reader.offset;
      reader.skipValue(valueType);
      final valueEnd = reader.offset;

      if (key == 'general.alignment' && valueType == 4) {
        alignment = ByteData.sublistView(
          bytes,
          valueStart,
          valueEnd,
        ).getUint32(0, Endian.little);
      }

      metadata.add(
        _GgufMetadataEntry(
          key: key,
          keyStart: keyStart,
          entryStart: entryStart,
          valueTypeOffset: valueTypeOffset,
          valueType: valueType,
          valueStart: valueStart,
          valueEnd: valueEnd,
        ),
      );
    }

    var architecturePatched = false;
    for (final entry in metadata) {
      if (entry.key == 'general.architecture' && entry.valueType == 8) {
        final currentArchitecture = _readGgufString(
          patchedBytes,
          entry.valueStart,
        );
        if (currentArchitecture == _sourceArchitecture) {
          _replaceAsciiSameLength(
            patchedBytes,
            entry.valueStart + 8,
            _sourceArchitecture,
            _compatibleArchitecture,
          );
          architecturePatched = true;
        } else if (currentArchitecture == _compatibleArchitecture) {
          architecturePatched = true;
        } else {
          throw StateError(
            'Cannot patch unsupported MiniGen architecture='
            '$currentArchitecture.',
          );
        }
      }

      if (entry.key.startsWith(_sourceArchitecturePrefix)) {
        _replaceAsciiSameLength(
          patchedBytes,
          entry.keyStart + 8,
          _sourceArchitecturePrefix,
          _compatibleArchitecturePrefix,
        );
      }
    }

    if (!architecturePatched) {
      throw StateError(
        'MiniGen GGUF is missing general.architecture metadata.',
      );
    }

    final tokenizerEntry = metadata.where((entry) {
      return entry.key == 'tokenizer.ggml.pre' && entry.valueType == 8;
    }).firstOrNull;
    if (tokenizerEntry == null) {
      throw StateError('MiniGen GGUF is missing tokenizer.ggml.pre metadata.');
    }

    final currentTokenizerPre = _readGgufString(
      patchedBytes,
      tokenizerEntry.valueStart,
    );
    if (currentTokenizerPre == _compatiblePretokenizer) {
      return patchedBytes;
    }
    if (currentTokenizerPre != _sourcePretokenizer) {
      throw StateError(
        'Cannot patch unsupported tokenizer.ggml.pre=$currentTokenizerPre.',
      );
    }

    for (var index = 0; index < tensorCount; index++) {
      reader.readString();
      final dimensions = reader.readUint32();
      reader.skip(dimensions * 8); // tensor dimensions
      reader.skip(4); // tensor type
      reader.skip(8); // tensor data offset
    }

    final originalTensorInfoEnd = reader.offset;
    final originalDataStart = _alignOffset(originalTensorInfoEnd, alignment);

    final output = BytesBuilder(copy: false)
      ..add(patchedBytes.sublist(0, tokenizerEntry.valueStart))
      ..add(_encodeGgufString(_compatiblePretokenizer))
      ..add(
        patchedBytes.sublist(tokenizerEntry.valueEnd, originalTensorInfoEnd),
      );

    final newTensorInfoEnd = output.length;
    final newDataStart = _alignOffset(newTensorInfoEnd, alignment);
    output.add(Uint8List(newDataStart - newTensorInfoEnd));
    output.add(patchedBytes.sublist(originalDataStart));

    return output.toBytes();
  }

  static String _readGgufString(Uint8List bytes, int offset) {
    final length = ByteData.sublistView(
      bytes,
      offset,
      offset + 8,
    ).getUint64(0, Endian.little);
    final start = offset + 8;
    return String.fromCharCodes(bytes.sublist(start, start + length));
  }

  static Uint8List _encodeGgufString(String value) {
    final chars = value.codeUnits;
    final encoded = Uint8List(8 + chars.length);
    ByteData.sublistView(encoded).setUint64(0, chars.length, Endian.little);
    encoded.setRange(8, encoded.length, chars);
    return encoded;
  }

  static void _replaceAsciiSameLength(
    Uint8List bytes,
    int offset,
    String from,
    String to,
  ) {
    if (from.length != to.length) {
      throw ArgumentError('Replacement must preserve GGUF field length.');
    }

    for (var index = 0; index < from.length; index++) {
      if (bytes[offset + index] != from.codeUnitAt(index)) {
        throw StateError('MiniGen GGUF metadata did not match expected $from.');
      }
    }

    for (var index = 0; index < to.length; index++) {
      bytes[offset + index] = to.codeUnitAt(index);
    }
  }

  static int _alignOffset(int offset, int alignment) {
    final effectiveAlignment = alignment <= 0 ? 32 : alignment;
    final remainder = offset % effectiveAlignment;
    return remainder == 0 ? offset : offset + effectiveAlignment - remainder;
  }
}

class _GgufMetadataEntry {
  const _GgufMetadataEntry({
    required this.key,
    required this.keyStart,
    required this.entryStart,
    required this.valueTypeOffset,
    required this.valueType,
    required this.valueStart,
    required this.valueEnd,
  });

  final String key;
  final int keyStart;
  final int entryStart;
  final int valueTypeOffset;
  final int valueType;
  final int valueStart;
  final int valueEnd;
}

class _GgufReader {
  _GgufReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;

  String readAscii(int length) {
    final value = String.fromCharCodes(bytes.sublist(offset, offset + length));
    offset += length;
    return value;
  }

  String readString() {
    final length = readUint64();
    final value = String.fromCharCodes(bytes.sublist(offset, offset + length));
    offset += length;
    return value;
  }

  int readUint32() {
    final value = ByteData.sublistView(
      bytes,
      offset,
      offset + 4,
    ).getUint32(0, Endian.little);
    offset += 4;
    return value;
  }

  int readUint64() {
    final value = ByteData.sublistView(
      bytes,
      offset,
      offset + 8,
    ).getUint64(0, Endian.little);
    offset += 8;
    return value;
  }

  void skip(int byteCount) {
    offset += byteCount;
  }

  void skipValue(int valueType) {
    switch (valueType) {
      case 0:
      case 1:
      case 7:
        skip(1);
      case 2:
      case 3:
        skip(2);
      case 4:
      case 5:
      case 6:
        skip(4);
      case 8:
        skip(readUint64());
      case 9:
        final elementType = readUint32();
        final length = readUint64();
        for (var index = 0; index < length; index++) {
          skipValue(elementType);
        }
      case 10:
      case 11:
      case 12:
        skip(8);
      default:
        throw StateError('Unsupported GGUF metadata type: $valueType');
    }
  }
}

class MiniGenModelCompatibility {
  const MiniGenModelCompatibility({
    required this.isGguf,
    required this.canAttemptLoad,
    this.tokenizerPretokenizer,
    this.architecture,
    this.reason,
  });

  final bool isGguf;
  final bool canAttemptLoad;
  final String? tokenizerPretokenizer;
  final String? architecture;
  final String? reason;

  @override
  String toString() {
    return 'MiniGenModelCompatibility('
        'isGguf: $isGguf, '
        'canAttemptLoad: $canAttemptLoad, '
        'architecture: $architecture, '
        'tokenizerPretokenizer: $tokenizerPretokenizer, '
        'reason: $reason'
        ')';
  }
}
