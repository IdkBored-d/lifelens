import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

  /// Returns the local filesystem path to the GGUF model file.
  /// Downloads it from HuggingFace if not already present.
  ///
  /// [onProgress] receives values from 0.0 to 1.0.
  static Future<String> ensureModel({
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_filename');

    if (file.existsSync()) {
      debugPrint('[MiniGenDownloader] model already present: ${file.path}');
      return file.path;
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

    debugPrint('[MiniGenDownloader] download complete (${file.lengthSync()} bytes)');
    return file.path;
  }

  /// Check if the model file already exists locally.
  static Future<bool> isModelAvailable() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_filename').existsSync();
  }

  /// Delete the cached model file (e.g. to force re-download).
  static Future<void> deleteModel() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_filename');
    if (file.existsSync()) {
      file.deleteSync();
      debugPrint('[MiniGenDownloader] deleted cached model');
    }
  }
}
