import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the on-device Gemma 2 2B IT model file.
///
/// Responsibilities:
///  - Persisting the model path across app restarts (SharedPreferences)
///  - Streaming HTTP download with progress callbacks
///  - Dev/MVP shortcut: load from a pre-placed local path (no download)
///
/// Typical production flow:
///   1. Call [getSavedPath] at startup — non-empty means model is ready.
///   2. If empty and user hasn't skipped, show GemmaSetupScreen.
///   3. User taps "Download" → [downloadModel] streams the file.
///   4. On completion, call [savePath] then AppServices.loadGemmaModel().
///
/// Dev / MVP flow:
///   1. Push the .bin file to the device with adb:
///        adb push gemma-2-2b-it-gpu-int8.bin /sdcard/Download/
///   2. In GemmaSetupScreen, expand "Dev mode" and paste the path.
///   3. Tap "Load" — skips download entirely.
class GemmaModelManager {
  GemmaModelManager._();

  // ── SharedPreferences keys ────────────────────────────────────────────────

  static const _pathKey    = 'gemma_model_path';
  static const _skippedKey = 'gemma_setup_skipped';

  // ── Model source ─────────────────────────────────────────────────────────

  static const String modelUrl = 'https://huggingface.co/litert-community/Gemma2-2B-IT/resolve/main/gemma-2-2b-it-gpu-int8.bin';

  static const String modelFileName = 'gemma-2-2b-it-gpu-int8.bin';

  // ── Path persistence ─────────────────────────────────────────────────────

  /// Returns the saved on-device model path, or `''` if not yet set.
  static Future<String> getSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pathKey) ?? '';
  }

  /// Saves [path] so subsequent launches skip the download screen.
  static Future<void> savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, path);
  }

  /// Clears a saved path (e.g. if the file was deleted).
  static Future<void> clearPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey);
  }

  /// Returns true if a model path is saved AND the file exists on disk.
  /// Automatically clears a stale path if the file is gone.
  static Future<bool> isModelFilePresent() async {
    final path = await getSavedPath();
    if (path.isEmpty) return false;
    final exists = await File(path).exists();
    if (!exists) await clearPath();
    return exists;
  }

  // ── Skip flag ────────────────────────────────────────────────────────────

  /// Returns true if the user tapped "Skip" on the Gemma setup screen.
  static Future<bool> wasSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_skippedKey) ?? false;
  }

  /// Marks the setup as skipped so the setup screen is not shown again.
  static Future<void> markSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skippedKey, true);
  }

  /// Clears the skipped flag (e.g. if the user wants to retry setup).
  static Future<void> clearSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skippedKey);
  }

  // ── Download ──────────────────────────────────────────────────────────────

  /// Downloads the model to the app's documents directory.
  ///
  /// [onProgress] receives values 0.0 → 1.0 as data arrives.
  /// Pass a [CancellationToken] to support user-initiated cancellation.
  ///
  /// Returns the absolute path of the saved file on success.
  /// Throws on HTTP error, IO error, or cancellation.
  static Future<String> downloadModel({
    required void Function(double progress) onProgress,
    CancellationToken? cancel,
    String? customUrl,
  }) async {
    final url = customUrl ?? modelUrl;
    if (url.isEmpty) {
      throw Exception(
          'No download URL configured. Set GemmaModelManager.modelUrl '
          'or pass a customUrl.');
    }

    final dir  = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/$modelFileName');

    final client   = http.Client();
    final request  = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);

    if (response.statusCode != 200) {
      client.close();
      throw Exception('Download failed: HTTP ${response.statusCode}');
    }

    final total    = response.contentLength ?? 0;
    var   received = 0;
    final sink     = dest.openWrite();

    try {
      await for (final chunk in response.stream) {
        if (cancel?.isCancelled == true) {
          throw const _CancelException();
        }
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
    } on _CancelException {
      await sink.close();
      if (await dest.exists()) await dest.delete();
      rethrow;
    } catch (_) {
      await sink.close();
      if (await dest.exists()) await dest.delete();
      rethrow;
    } finally {
      client.close();
    }

    await sink.close();
    return dest.path;
  }

  // ── Dev / MVP shortcut ────────────────────────────────────────────────────

  /// Validates that [path] points to a readable file.
  /// Returns `null` on success or an error message string.
  static Future<String?> validateLocalPath(String path) async {
    if (path.trim().isEmpty) return 'Path cannot be empty.';
    final file = File(path.trim());
    if (!await file.exists()) return 'File not found at: $path';
    final size = await file.length();
    if (size < 1024 * 1024) return 'File is too small to be a valid model.';
    return null; // ok
  }
}

// ── Cancellation ─────────────────────────────────────────────────────────────

/// Token passed to [GemmaModelManager.downloadModel] to cancel mid-stream.
class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class _CancelException implements Exception {
  const _CancelException();
  @override
  String toString() => 'Download cancelled by user.';
}
