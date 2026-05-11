@Tags(['integration'])
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelens/services/minigen_service.dart';
import 'package:lifelens/services/minigen_downloader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // Allow real network requests

  tearDownAll(() async {
    final d = Directory('${Directory.current.path}/build/test_models');
    if (d.existsSync()) d.deleteSync(recursive: true);
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          // Use a local build directory so the model is persisted between test runs.
          final dir = Directory('${Directory.current.path}/build/test_models');
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          return dir.path;
        }
        return null;
      },
    );
  });

  test('Test MiniGen load', () async {
    print('Ensuring model...');
    try {
      final path = await MiniGenDownloader.ensureModel();
      print('Model path: $path');
      
      final service = MiniGenService();
      print('Loading model...');
      await service.load(path);
      print('Model loaded! isLoaded: ${service.isLoaded}');
    } catch (e, st) {
      print('Failed to load: $e');
      print(st);
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
