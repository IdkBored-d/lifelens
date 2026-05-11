import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime/onnxruntime.dart';

void main() {
  testWidgets('Test OrtSession Isolate sendability', (WidgetTester tester) async {
    OrtEnv.instance.init();
    
    // We just need a dummy small byte array that represents a valid ONNX model, or we can just try to see if a dummy OrtSessionOptions is sendable.
    // If OrtSessionOptions is not sendable, OrtSession isn't either.
    try {
      final opts = await Isolate.run(() {
        OrtEnv.instance.init(); // Init in isolate just in case
        return OrtSessionOptions();
      });
      print('OrtSessionOptions is sendable!');
    } catch (e) {
      print('OrtSessionOptions is NOT sendable: $e');
    }
  });
}
