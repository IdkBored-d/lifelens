import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Downloads the MiniGen GGUF model from HuggingFace on first launch.
///
/// The model is stored in [getApplicationSupportDirectory] to avoid
/// polluting the iOS iCloud backup quota (Documents/ is backed up).
class MiniGenDownloader {
  MiniGenDownloader._();

  static const String _url =
      'https://huggingface.co/testingtest111/minigen-f16/resolve/main/minigen-f16.gguf?download=true';
  static const String _filename = 'minigen-f16.gguf';
  static const String _bundledAsset = 'assets/models/minigen-f16.gguf';

  // Injected at build time via --dart-define=HF_TOKEN=hf_...
  // If empty, the Authorization header is omitted (public repos work without it).
  static const String _hfToken = String.fromEnvironment('HF_TOKEN');

  // Guard against partial downloads. Q8_0 model is ~51.3 MB; 45 MB is a safe floor. f16 is 98314
  static const int _minValidBytes = 45 * 1024 * 1024 * 2; // *2 is for f16

  // At most one download in flight; concurrent callers await the same future.
  static Completer<String>? _inFlight;

  /// Returns the local filesystem path to the GGUF model file.
  /// Downloads it from HuggingFace if not already present or if the cached
  /// file is smaller than [_minValidBytes] (guards against partial downloads).
  ///
  /// Concurrent calls are collapsed: the second caller awaits the first
  /// download rather than starting a parallel one.
  ///
  /// [onProgress] receives values from 0.0 to 1.0.
  static Future<String> ensureModel({
    void Function(double progress)? onProgress,
  }) async {
    // No await before this assignment — safe from Dart's single-threaded event loop.
    if (_inFlight != null) {
      debugPrint('[MiniGenDownloader] download already in progress, waiting…');
      return _inFlight!.future;
    }

    final completer = Completer<String>();
    _inFlight = completer;

    try {
      final result = await _doEnsureModel(onProgress: onProgress);
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _inFlight = null;
    }
  }

  static Future<String> _doEnsureModel({
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    // Use Platform.pathSeparator to avoid mixed-separator issues on Windows.
    final file = File('${dir.path}${Platform.pathSeparator}$_filename');

    // 1. Cached file — fastest path.
    if (file.existsSync()) {
      final bytes = file.lengthSync();
      if (bytes >= _minValidBytes) {
        debugPrint('[MiniGenDownloader] model already present: ${file.path}');
        return file.path;
      }
      debugPrint(
        '[MiniGenDownloader] deleting incomplete file ($bytes bytes < $_minValidBytes minimum)',
      );
      file.deleteSync();
    }

    // 2. Bundled asset — available on first launch without a network round-trip.
    try {
      final data = await rootBundle.load(_bundledAsset);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (file.lengthSync() >= _minValidBytes) {
        debugPrint('[MiniGenDownloader] model extracted from bundled asset');
        return file.path;
      }
      // Bundle was smaller than expected (bad build?) — delete and fall through.
      file.deleteSync();
    } catch (_) {
      // rootBundle throws if the asset isn't declared or the binding isn't
      // available (e.g. background isolate without widget binding). Fall through
      // to the network download.
    }

    // 3. Network download — last resort.
    debugPrint('[MiniGenDownloader] downloading model to ${file.path}');

    final dio = Dio();
    try {
      await dio.download(
        _url,
        file.path,
        options: Options(
          headers: _hfToken.isNotEmpty
              ? {'Authorization': 'Bearer $_hfToken'}
              : null,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );
    } catch (e) {
      if (file.existsSync()) file.deleteSync();
      rethrow;
    } finally {
      dio.close();
    }

    debugPrint(
      '[MiniGenDownloader] download complete (${file.lengthSync()} bytes)',
    );
    return file.path;
  }

  /// Check if a valid (fully downloaded) model file exists locally.
  static Future<bool> isModelAvailable() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_filename');
    return file.existsSync() && file.lengthSync() >= _minValidBytes;
  }

  /// Delete the cached model file (e.g. to force re-download).
  static Future<void> deleteModel() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_filename');
    if (file.existsSync()) {
      file.deleteSync();
      debugPrint('[MiniGenDownloader] deleted cached model');
    }
  }
}
