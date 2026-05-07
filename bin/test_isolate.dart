import 'dart:isolate';
import 'package:onnxruntime/onnxruntime.dart';

void main() async {
  OrtEnv.instance.init();
  try {
    final opts = await Isolate.run(() {
      return OrtSessionOptions();
    });
    print('SUCCESS: sendable');
  } catch (e) {
    print('ERROR: not sendable: $e');
  }
}
