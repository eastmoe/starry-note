import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_settings.dart';

class SettingsService {
  const SettingsService();

  static const _storage = FlutterSecureStorage();

  Future<AppSettings> load() async {
    final values = await _storage.readAll();
    return AppSettings.fromMap(values);
  }

  Future<void> save(AppSettings settings) async {
    for (final entry in settings.toMap().entries) {
      await _storage.write(key: entry.key, value: entry.value);
    }
  }
}
