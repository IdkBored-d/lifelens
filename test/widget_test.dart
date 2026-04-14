import 'package:flutter_test/flutter_test.dart';
import 'package:lifelens/theme_controller.dart';

void main() {
  test('ThemeController starts in the default theme mode', () {
    final controller = ThemeController();

    expect(controller.isCalmMode, isFalse);
  });

  test('ThemeController toggles calm mode', () {
    final controller = ThemeController();

    controller.setCalmMode(true);
    expect(controller.isCalmMode, isTrue);

    controller.setCalmMode(false);
    expect(controller.isCalmMode, isFalse);
  });
}
