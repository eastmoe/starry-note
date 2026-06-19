import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starry_note/services/config_service.dart';

void main() {
  test('updates common values without destroying other config', () async {
    final root = await Directory.systemTemp.createTemp('starry-config-test');
    addTearDown(() => root.delete(recursive: true));
    final public = Directory('${root.path}${Platform.pathSeparator}public');
    await public.create();
    final file = File('${public.path}${Platform.pathSeparator}config.js');
    await file.writeAsString(
      "export default { siteName: 'Old', siteQuote: 'Hi', siteAvatar: '/a.png', siteIcon: '/i.png', defaultThemeColor: '#fff', untouched: true }",
    );
    final service = ConfigService();
    final config = await service.load(root.path);
    config.siteName = "Starry's Blog";
    await service.saveCommon(root.path, config);
    final result = await file.readAsString();
    expect(result, contains(r"siteName: 'Starry\'s Blog'"));
    expect(result, contains('untouched: true'));
  });
}
