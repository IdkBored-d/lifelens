import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          final dir = Directory('${Directory.current.path}/build/test_models');
          if (!dir.existsSync()) dir.createSync(recursive: true);
          return dir.path;
        }
        return null;
      },
    );
  });

  test('Test path_provider mock', () async {
    final dir = await getApplicationSupportDirectory();
    print('Dir: ${dir.path}');
  });
}
