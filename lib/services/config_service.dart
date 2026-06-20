import 'dart:io';

import 'package:path/path.dart' as p;

class MenuItemConfig {
  MenuItemConfig({required this.name, required this.link});
  String name;
  String link;
}

class FontFaceConfig {
  FontFaceConfig({
    required this.family,
    required this.src,
    this.format = 'truetype',
    this.weight = '400',
    this.style = 'normal',
    this.display = 'swap',
  });
  String family;
  String src;
  String format;
  String weight;
  String style;
  String display;
}

class FriendLinkConfig {
  FriendLinkConfig({
    required this.name,
    required this.url,
    this.description = '',
    this.avatar = '',
  });
  String name;
  String url;
  String description;
  String avatar;
}

class RobotsRuleConfig {
  RobotsRuleConfig({
    this.userAgent = '*',
    List<String>? allow,
    List<String>? disallow,
  })  : allow = allow ?? ['/'],
        disallow = disallow ?? [];
  String userAgent;
  List<String> allow;
  List<String> disallow;
}

class SiteConfig {
  SiteConfig({required this.raw});
  String raw;
  String siteName = '';
  String siteAvatar = '';
  String siteIcon = '';
  String siteQuote = '';
  String defaultThemeColor = '';
  String footerIcp = '';
  String footerIcpLink = '';
  String footerCopyright = '';
  String backgroundImage = '';
  double backgroundOpacity = .25;
  double backgroundBlur = 0;
  bool snowEnabled = false;
  double snowSize = 1;
  double snowDensity = .0001;
  bool particlesEnabled = false;
  String particlesColor = '#ffffff';
  double particlesSize = 1;
  double particlesDensity = .0001;
  bool bellShakeOnClick = true;
  double cardShadowStrength = 1;
  double cardGlowStrength = 1;
  bool respectReducedMotion = true;
  int pageTransitionMs = 620;
  int loaderMinMs = 620;
  int bellMenuMs = 620;
  int bellShakeMs = 620;
  int articleTransitionMs = 720;
  String gravatarBaseUrl = '';
  bool keywordFilterEnabled = false;
  List<String> keywordFilterKeywords = [];
  String keywordFilterReplacement = '***';
  String supabaseUrl = '';
  String supabaseAnonKey = '';
  String seoDescription = '';
  String seoCanonicalUrl = '';
  List<String> seoKeywords = [];
  String seoTitleTemplate = '';
  String seoSocialImage = '';
  bool sitemapEnabled = true;
  List<String> sitemapExtraPaths = [];
  bool robotsEnabled = true;
  List<MenuItemConfig> menu = [];
  List<FontFaceConfig> fontFaces = [];
  List<FriendLinkConfig> friendLinks = [];
  List<RobotsRuleConfig> robotsRules = [];
  Map<String, String> fonts = {};
}

class ConfigService {
  File file(String repositoryPath) =>
      File(p.join(repositoryPath, 'public', 'config.js'));

  Future<SiteConfig> load(String repositoryPath) async {
    final raw = await file(repositoryPath).readAsString();
    final c = SiteConfig(raw: raw)
      ..siteName = _string(raw, ['siteName'])
      ..siteAvatar = _string(raw, ['siteAvatar'])
      ..siteIcon = _string(raw, ['siteIcon'])
      ..siteQuote = _string(raw, ['siteQuote'])
      ..defaultThemeColor = _string(raw, ['defaultThemeColor'])
      ..footerIcp = _string(raw, ['footer', 'icp'])
      ..footerIcpLink = _string(raw, ['footer', 'icpLink'])
      ..footerCopyright = _string(raw, ['footer', 'copyright'])
      ..backgroundImage = _string(raw, ['visualEffects', 'background', 'image'])
      ..backgroundOpacity =
          _number(raw, ['visualEffects', 'background', 'opacity'], .25)
      ..backgroundBlur =
          _number(raw, ['visualEffects', 'background', 'blur'], 0)
      ..snowEnabled = _bool(raw, ['visualEffects', 'snow', 'enabled'])
      ..snowSize = _number(raw, ['visualEffects', 'snow', 'size'], 1)
      ..snowDensity = _number(raw, ['visualEffects', 'snow', 'density'], .0001)
      ..particlesEnabled = _bool(raw, ['visualEffects', 'particles', 'enabled'])
      ..particlesColor = _string(raw, ['visualEffects', 'particles', 'color'])
      ..particlesSize = _number(raw, ['visualEffects', 'particles', 'size'], 1)
      ..particlesDensity =
          _number(raw, ['visualEffects', 'particles', 'density'], .0001)
      ..bellShakeOnClick =
          _bool(raw, ['visualEffects', 'bell', 'shakeOnClick'], true)
      ..cardShadowStrength =
          _number(raw, ['visualEffects', 'cards', 'shadowStrength'], 1)
      ..cardGlowStrength =
          _number(raw, ['visualEffects', 'cards', 'glowStrength'], 1)
      ..respectReducedMotion =
          _bool(raw, ['animations', 'respectReducedMotion'], true)
      ..pageTransitionMs =
          _integer(raw, ['animations', 'pageTransitionMs'], 620)
      ..loaderMinMs = _integer(raw, ['animations', 'loaderMinMs'], 620)
      ..bellMenuMs = _integer(raw, ['animations', 'bellMenuMs'], 620)
      ..bellShakeMs = _integer(raw, ['animations', 'bellShakeMs'], 620)
      ..articleTransitionMs =
          _integer(raw, ['animations', 'articleTransitionMs'], 720)
      ..gravatarBaseUrl = _string(raw, ['comments', 'gravatarBaseUrl'])
      ..keywordFilterEnabled =
          _bool(raw, ['comments', 'keywordFilter', 'enabled'])
      ..keywordFilterKeywords = _parseStringArray(
          _value(raw, ['comments', 'keywordFilter', 'keywords']) ?? '')
      ..keywordFilterReplacement =
          _string(raw, ['comments', 'keywordFilter', 'replacement'])
      ..supabaseUrl = _string(raw, ['supabase', 'url'])
      ..supabaseAnonKey = _string(raw, ['supabase', 'anonKey'])
      ..seoDescription = _string(raw, ['seo', 'description'])
      ..seoCanonicalUrl = _string(raw, ['seo', 'canonicalUrl'])
      ..seoKeywords = _parseStringArray(_value(raw, ['seo', 'keywords']) ?? '')
      ..seoTitleTemplate = _string(raw, ['seo', 'titleTemplate'])
      ..seoSocialImage = _string(raw, ['seo', 'socialImage'])
      ..sitemapEnabled = _bool(raw, ['seo', 'sitemap', 'enabled'], true)
      ..sitemapExtraPaths =
          _parseStringArray(_value(raw, ['seo', 'sitemap', 'extraPaths']) ?? '')
      ..robotsEnabled = _bool(raw, ['seo', 'robots', 'enabled'], true);
    c.menu = _parseMenu(_value(raw, ['menu']) ?? '');
    c.fontFaces = _parseFontFaces(_value(raw, ['fontFaces']) ?? '');
    c.friendLinks = _parseFriendLinks(_value(raw, ['friendLinks']) ?? '');
    c.robotsRules = _parseRobotsRules(
      _value(raw, ['seo', 'robots', 'rules']) ?? '',
    );
    c.fonts = {
      for (final key in [
        'siteName',
        'quote',
        'postTitle',
        'postContent',
        'menu'
      ])
        key: _string(raw, ['fonts', key]),
    };
    return c;
  }

  Future<void> saveCommon(String repositoryPath, SiteConfig c) async {
    var raw = c.raw;
    final values = <List<String>, String>{
      ['siteName']: _quote(c.siteName),
      ['siteAvatar']: _quote(c.siteAvatar),
      ['siteIcon']: _quote(c.siteIcon),
      ['siteQuote']: _quote(c.siteQuote),
      ['defaultThemeColor']: _quote(c.defaultThemeColor),
      ['footer', 'icp']: _quote(c.footerIcp),
      ['footer', 'icpLink']: _quote(c.footerIcpLink),
      ['footer', 'copyright']: _quote(c.footerCopyright),
      ['visualEffects', 'background', 'image']: _quote(c.backgroundImage),
      ['visualEffects', 'background', 'opacity']: '${c.backgroundOpacity}',
      ['visualEffects', 'background', 'blur']: '${c.backgroundBlur}',
      ['visualEffects', 'snow', 'enabled']: '${c.snowEnabled}',
      ['visualEffects', 'snow', 'size']: '${c.snowSize}',
      ['visualEffects', 'snow', 'density']: '${c.snowDensity}',
      ['visualEffects', 'particles', 'enabled']: '${c.particlesEnabled}',
      ['visualEffects', 'particles', 'color']: _quote(c.particlesColor),
      ['visualEffects', 'particles', 'size']: '${c.particlesSize}',
      ['visualEffects', 'particles', 'density']: '${c.particlesDensity}',
      ['visualEffects', 'bell', 'shakeOnClick']: '${c.bellShakeOnClick}',
      ['visualEffects', 'cards', 'shadowStrength']: '${c.cardShadowStrength}',
      ['visualEffects', 'cards', 'glowStrength']: '${c.cardGlowStrength}',
      ['animations', 'respectReducedMotion']: '${c.respectReducedMotion}',
      ['animations', 'pageTransitionMs']: '${c.pageTransitionMs}',
      ['animations', 'loaderMinMs']: '${c.loaderMinMs}',
      ['animations', 'bellMenuMs']: '${c.bellMenuMs}',
      ['animations', 'bellShakeMs']: '${c.bellShakeMs}',
      ['animations', 'articleTransitionMs']: '${c.articleTransitionMs}',
      ['comments', 'gravatarBaseUrl']: _quote(c.gravatarBaseUrl),
      ['comments', 'keywordFilter', 'enabled']: '${c.keywordFilterEnabled}',
      ['comments', 'keywordFilter', 'keywords']:
          _stringArraySource(c.keywordFilterKeywords),
      ['comments', 'keywordFilter', 'replacement']:
          _quote(c.keywordFilterReplacement),
      ['supabase', 'url']: _quote(c.supabaseUrl),
      ['supabase', 'anonKey']: _quote(c.supabaseAnonKey),
      ['seo', 'description']: _quote(c.seoDescription),
      ['seo', 'canonicalUrl']: _quote(c.seoCanonicalUrl),
      ['seo', 'keywords']: _stringArraySource(c.seoKeywords),
      ['seo', 'titleTemplate']: _quote(c.seoTitleTemplate),
      ['seo', 'socialImage']: _quote(c.seoSocialImage),
      ['seo', 'sitemap', 'enabled']: '${c.sitemapEnabled}',
      ['seo', 'sitemap', 'extraPaths']: _stringArraySource(c.sitemapExtraPaths),
      ['seo', 'robots', 'enabled']: '${c.robotsEnabled}',
      ['seo', 'robots', 'rules']: _robotsRulesSource(c.robotsRules),
      ['menu']: _menuSource(c.menu),
      ['friendLinks']: _friendLinksSource(c.friendLinks),
      ['fontFaces']: _fontFacesSource(c.fontFaces),
      for (final entry in c.fonts.entries)
        ['fonts', entry.key]: _quote(entry.value),
    };
    for (final entry in values.entries) {
      raw = _replace(raw, entry.key, entry.value);
    }
    await file(repositoryPath).writeAsString(raw);
  }

  Future<void> saveRaw(String repositoryPath, String raw) async {
    if (!raw.contains('export default')) {
      throw Exception('config.js 必须包含 export default。');
    }
    await file(repositoryPath).writeAsString(raw);
  }

  String _string(String raw, List<String> path) {
    final v = _value(raw, path)?.trim() ?? '';
    if (v.length >= 2 && (v.startsWith("'") || v.startsWith('"'))) {
      return v
          .substring(1, v.length - 1)
          .replaceAll(r"\'", "'")
          .replaceAll(r'\\', r'\');
    }
    return '';
  }

  double _number(String raw, List<String> path, double fallback) =>
      double.tryParse(_value(raw, path)?.trim() ?? '') ?? fallback;
  int _integer(String raw, List<String> path, int fallback) =>
      int.tryParse(_value(raw, path)?.trim() ?? '') ?? fallback;
  bool _bool(String raw, List<String> path, [bool fallback = false]) {
    final v = _value(raw, path)?.trim();
    return v == null ? fallback : v == 'true';
  }

  String? _value(String raw, List<String> path) {
    var scope = raw;
    for (var i = 0; i < path.length; i++) {
      final range = _propertyRange(scope, path[i]);
      if (range == null) return null;
      final value = scope.substring(range.$1, range.$2);
      if (i == path.length - 1) return value;
      scope = value;
    }
    return null;
  }

  String _replace(String raw, List<String> path, String replacement) {
    if (path.length == 1) {
      final r = _propertyRange(raw, path.first);
      if (r == null) return raw;
      return raw.replaceRange(r.$1, r.$2, replacement);
    }
    final parent = _propertyRange(raw, path.first);
    if (parent == null) return raw;
    final block = raw.substring(parent.$1, parent.$2);
    final updated = _replace(block, path.sublist(1), replacement);
    return raw.replaceRange(parent.$1, parent.$2, updated);
  }

  (int, int)? _propertyRange(String text, String key) {
    final m = RegExp('\\b${RegExp.escape(key)}\\s*:').firstMatch(text);
    if (m == null) return null;
    var start = m.end;
    while (start < text.length && RegExp(r'\s').hasMatch(text[start])) {
      start++;
    }
    var i = start,
        quote = '',
        escaped = false,
        lineComment = false,
        blockComment = false;
    final stack = <String>[];
    for (; i < text.length; i++) {
      final ch = text[i], next = i + 1 < text.length ? text[i + 1] : '';
      if (lineComment) {
        if (ch == '\n') lineComment = false;
        continue;
      }
      if (blockComment) {
        if (ch == '*' && next == '/') {
          blockComment = false;
          i++;
        }
        continue;
      }
      if (quote.isNotEmpty) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == quote) {
          quote = '';
        }
        continue;
      }
      if (ch == '/' && next == '/') {
        lineComment = true;
        i++;
        continue;
      }
      if (ch == '/' && next == '*') {
        blockComment = true;
        i++;
        continue;
      }
      if (ch == "'" || ch == '"' || ch == '`') {
        quote = ch;
        continue;
      }
      if (ch == '{' || ch == '[' || ch == '(') stack.add(ch);
      if (ch == '}' || ch == ']' || ch == ')') {
        if (stack.isNotEmpty) {
          stack.removeLast();
        } else {
          return (start, i);
        }
      }
      if (stack.isEmpty && (ch == ',' || ch == '\n')) return (start, i);
    }
    return (start, i);
  }

  List<MenuItemConfig> _parseMenu(String source) =>
      RegExp(r'''name\s*:\s*(['"])(.*?)\1[\s\S]*?link\s*:\s*(['"])(.*?)\3''')
          .allMatches(source)
          .map((m) => MenuItemConfig(name: m.group(2)!, link: m.group(4)!))
          .toList();
  List<FontFaceConfig> _parseFontFaces(String source) =>
      RegExp(r'\{([\s\S]*?)\}')
          .allMatches(source)
          .map((m) {
            final b = m.group(1)!;
            String read(String key, [String fallback = '']) =>
                RegExp("\\b$key\\s*:\\s*(['\"])(.*?)\\1")
                    .firstMatch(b)
                    ?.group(2) ??
                fallback;
            return FontFaceConfig(
                family: read('family'),
                src: read('src'),
                format: read('format', 'truetype'),
                weight: read('weight', '400'),
                style: read('style', 'normal'),
                display: read('display', 'swap'));
          })
          .where((f) => f.family.isNotEmpty)
          .toList();
  List<FriendLinkConfig> _parseFriendLinks(String source) =>
      RegExp(r'\{([\s\S]*?)\}')
          .allMatches(source)
          .map((m) {
            final block = m.group(1)!;
            return FriendLinkConfig(
              name: _blockString(block, 'name'),
              url: _blockString(block, 'url'),
              description: _blockString(block, 'description'),
              avatar: _blockString(block, 'avatar'),
            );
          })
          .where((item) => item.name.isNotEmpty || item.url.isNotEmpty)
          .toList();
  List<RobotsRuleConfig> _parseRobotsRules(String source) =>
      RegExp(r'\{([\s\S]*?)\}').allMatches(source).map((m) {
        final block = m.group(1)!;
        final allow =
            RegExp(r'\ballow\s*:\s*(\[[\s\S]*?\])').firstMatch(block)?.group(1);
        final disallow = RegExp(r'\bdisallow\s*:\s*(\[[\s\S]*?\])')
            .firstMatch(block)
            ?.group(1);
        return RobotsRuleConfig(
          userAgent: _blockString(block, 'userAgent', '*'),
          allow: _parseStringArray(allow ?? ''),
          disallow: _parseStringArray(disallow ?? ''),
        );
      }).toList();
  String _blockString(String block, String key, [String fallback = '']) =>
      RegExp("\\b$key\\s*:\\s*(['\"])(.*?)\\1").firstMatch(block)?.group(2) ??
      fallback;
  List<String> _parseStringArray(String source) => RegExp(r'''(['"])(.*?)\1''')
      .allMatches(source)
      .map((m) => m.group(2)!)
      .toList();
  String _quote(String value) =>
      "'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'";
  String _menuSource(List<MenuItemConfig> items) =>
      '[\n${items.map((e) => "    { name: ${_quote(e.name)}, link: ${_quote(e.link)} }").join(',\n')}\n  ]';
  String _friendLinksSource(List<FriendLinkConfig> items) =>
      '[\n${items.map((e) => "    { name: ${_quote(e.name)}, url: ${_quote(e.url)}, description: ${_quote(e.description)}, avatar: ${_quote(e.avatar)} }").join(',\n')}\n  ]';
  String _stringArraySource(List<String> items) =>
      '[${items.map(_quote).join(', ')}]';
  String _robotsRulesSource(List<RobotsRuleConfig> rules) =>
      '[\n${rules.map((e) => "        { userAgent: ${_quote(e.userAgent)}, allow: ${_stringArraySource(e.allow)}, disallow: ${_stringArraySource(e.disallow)} }").join(',\n')}\n      ]';
  String _fontFacesSource(List<FontFaceConfig> items) =>
      '[\n${items.map((e) => "    { family: ${_quote(e.family)}, src: ${_quote(e.src)}, format: ${_quote(e.format)}, weight: ${_quote(e.weight)}, style: ${_quote(e.style)}, display: ${_quote(e.display)} }").join(',\n')}\n  ]';
}
