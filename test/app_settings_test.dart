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
      autoBackupEnabled: true,
      backupDirectory: r'E:\Backups',
      backupIntervalHours: 6,
      backupTables: ['comments', 'profiles'],
      lastBackupAt: '2026-06-20T10:00:00.000',
    );

    final restored = AppSettings.fromMap(settings.toMap());

    expect(restored.onboardingCompleted, isTrue);
    expect(restored.followSystemTheme, isFalse);
    expect(restored.darkMode, isTrue);
    expect(restored.pureBlackMode, isTrue);
    expect(restored.primaryColorValue, 0xffe11d48);
    expect(restored.autoBackupEnabled, isTrue);
    expect(restored.backupDirectory, r'E:\Backups');
    expect(restored.backupIntervalHours, 6);
    expect(restored.backupTables, ['comments', 'profiles']);
    expect(restored.lastBackupAt, '2026-06-20T10:00:00.000');
  });
}
