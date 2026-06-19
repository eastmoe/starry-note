import 'package:flutter_test/flutter_test.dart';
import 'package:starry_note/models/app_settings.dart';

void main() {
  test('persists onboarding and appearance preferences', () {
    const settings = AppSettings(
      onboardingCompleted: true,
      followSystemTheme: false,
      darkMode: true,
      pureBlackMode: true,
      primaryColorValue: 0xffe11d48,
    );

    final restored = AppSettings.fromMap(settings.toMap());

    expect(restored.onboardingCompleted, isTrue);
    expect(restored.followSystemTheme, isFalse);
    expect(restored.darkMode, isTrue);
    expect(restored.pureBlackMode, isTrue);
    expect(restored.primaryColorValue, 0xffe11d48);
  });
}
