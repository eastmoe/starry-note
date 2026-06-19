import 'dart:io';

import 'package:path/path.dart' as p;

class SiteConfig {
  SiteConfig({
    required this.siteName,
    required this.siteAvatar,
    required this.siteIcon,
    required this.siteQuote,
    required this.defaultThemeColor,
    required this.raw,
  });
  String siteName;
  String siteAvatar;
  String siteIcon;
  String siteQuote;
  String defaultThemeColor;
  String raw;
}

class ConfigService {
  File file(String repositoryPath) =>
      File(p.join(repositoryPath, 'public', 'config.js'));

  Future<SiteConfig> load(String repositoryPath) async {
    final raw = await file(repositoryPath).readAsString();
    return SiteConfig(
      siteName: _readString(raw, 'siteName'),
      siteAvatar: _readString(raw, 'siteAvatar'),
      siteIcon: _readString(raw, 'siteIcon'),
      siteQuote: _readString(raw, 'siteQuote'),
      defaultThemeColor: _readString(raw, 'defaultThemeColor'),
      raw: raw,
    );
  }

  Future<void> saveCommon(String repositoryPath, SiteConfig config) async {
    var raw = config.raw;
    raw = _replaceString(raw, 'siteName', config.siteName);
    raw = _replaceString(raw, 'siteAvatar', config.siteAvatar);
    raw = _replaceString(raw, 'siteIcon', config.siteIcon);
    raw = _replaceString(raw, 'siteQuote', config.siteQuote);
    raw = _replaceString(raw, 'defaultThemeColor', config.defaultThemeColor);
    await file(repositoryPath).writeAsString(raw);
  }

  Future<void> saveRaw(String repositoryPath, String raw) async {
    if (!raw.contains('export default')) {
      throw Exception('config.js 必须包含 export default。');
    }
    await file(repositoryPath).writeAsString(raw);
  }

  String _readString(String raw, String key) {
    final match = RegExp("\\b$key\\s*:\\s*(['\"])(.*?)\\1").firstMatch(raw);
    return match?.group(2) ?? '';
  }

  String _replaceString(String raw, String key, String value) {
    final safe = value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    return raw.replaceFirstMapped(
      RegExp("(\\b$key\\s*:\\s*)(['\"])(.*?)\\2"),
      (match) => "${match.group(1)}'$safe'",
    );
  }
}
