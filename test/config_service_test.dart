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

  test('parses and updates nested visual, menu, font and database values',
      () async {
    final root = await Directory.systemTemp.createTemp('starry-config-nested');
    addTearDown(() => root.delete(recursive: true));
    final public = Directory('${root.path}${Platform.pathSeparator}public');
    await public.create();
    final file = File('${public.path}${Platform.pathSeparator}config.js');
    await file.writeAsString('''
export default {
  siteName: 'Starry', siteAvatar: '/images/a.png', siteIcon: '/images/i.png',
  siteQuote: 'Hello', defaultThemeColor: '#66ccff',
  fontFaces: [{ family: 'Local', src: '/font/local.ttf', format: 'truetype', weight: '400', style: 'normal', display: 'swap' }],
  menu: [{ name: '首页', link: '/' }, { name: '技术', link: '/tech' }],
  friendLinks: [{ name: '朋友', url: 'https://friend.example', description: '你好', avatar: '/images/friend.png' }],
  footer: { icp: 'ICP', icpLink: 'https://example.com', copyright: 'Mine' },
  fonts: { siteName: 'Local', quote: 'Local', postTitle: 'Local', postContent: 'sans-serif', menu: 'Local' },
  visualEffects: { background: { image: '/images/bg.webp', opacity: 0.2, blur: 3 }, snow: { enabled: true, size: 1, density: 0.1 }, particles: { enabled: false, color: '#fff', size: 1, density: 0.1 }, bell: { shakeOnClick: true }, cards: { shadowStrength: 1, glowStrength: 2 } },
  animations: { respectReducedMotion: false, pageTransitionMs: 600, loaderMinMs: 601, bellMenuMs: 602, bellShakeMs: 603, articleTransitionMs: 700 },
  comments: { gravatarBaseUrl: 'https://avatar/', verification: { questions: [{ question: '一年有几个月？', answers: ['12', '十二'] }] }, keywordFilter: { enabled: true, keywords: ['坏词', '广告'], replacement: '***' } },
  seo: { description: '站点描述', canonicalUrl: 'https://example.com/', keywords: ['博客', 'Flutter'], titleTemplate: '{title} | {siteName}', socialImage: '/images/social.png', sitemap: { enabled: true, extraPaths: ['/', '/about'] }, robots: { enabled: true, rules: [{ userAgent: '*', allow: ['/'], disallow: ['/search'] }] } },
  supabase: { url: 'https://db/', anonKey: 'public-key' }, untouched: true
}''');
    final service = ConfigService();
    final config = await service.load(root.path);
    expect(config.menu.map((e) => e.name), ['首页', '技术']);
    expect(config.fontFaces.single.family, 'Local');
    expect(config.backgroundImage, '/images/bg.webp');
    expect(config.pageTransitionMs, 600);
    expect(config.supabaseAnonKey, 'public-key');
    expect(config.friendLinks.single.description, '你好');
    expect(config.keywordFilterKeywords, ['坏词', '广告']);
    expect(config.verificationQuestions.single.question, '一年有几个月？');
    expect(config.verificationQuestions.single.answers, ['12', '十二']);
    expect(config.seoKeywords, ['博客', 'Flutter']);
    expect(config.robotsRules.single.disallow, ['/search']);
    config.menu.add(MenuItemConfig(name: '关于', link: '/about'));
    config.friendLinks.add(
      FriendLinkConfig(name: '新朋友', url: 'https://new.example'),
    );
    config.backgroundOpacity = 0.5;
    config.supabaseUrl = 'https://new-db/';
    config.keywordFilterReplacement = '[已过滤]';
    config.verificationQuestions.add(
      VerificationQuestionConfig(
        question: '博客叫什么？',
        answers: ['Starry', 'starry'],
      ),
    );
    config.robotsRules.single.disallow.add('/private');
    await service.saveCommon(root.path, config);
    final updated = await service.load(root.path);
    expect(updated.menu.last.link, '/about');
    expect(updated.backgroundOpacity, 0.5);
    expect(updated.supabaseUrl, 'https://new-db/');
    expect(updated.friendLinks.last.name, '新朋友');
    expect(updated.keywordFilterReplacement, '[已过滤]');
    expect(updated.verificationQuestions.last.answers, ['Starry', 'starry']);
    expect(updated.robotsRules.single.disallow, ['/search', '/private']);
    expect(await file.readAsString(), contains('untouched: true'));
  });
}
