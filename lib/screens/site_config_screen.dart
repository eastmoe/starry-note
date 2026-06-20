import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app_controller.dart';
import '../services/config_service.dart';

class SiteConfigScreen extends StatefulWidget {
  const SiteConfigScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<SiteConfigScreen> createState() => _SiteConfigScreenState();
}

class _SiteConfigScreenState extends State<SiteConfigScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  SiteConfig? _config;
  final c = <String, TextEditingController>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 8, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final v = await widget.controller.configService
          .load(widget.controller.settings.repositoryPath);
      for (final controller in c.values) {
        controller.dispose();
      }
      _config = v;
      void add(String key, Object value) =>
          c[key] = TextEditingController(text: '$value');
      add('siteName', v.siteName);
      add('siteQuote', v.siteQuote);
      add('theme', v.defaultThemeColor);
      add('icp', v.footerIcp);
      add('icpLink', v.footerIcpLink);
      add('copyright', v.footerCopyright);
      add('opacity', v.backgroundOpacity);
      add('blur', v.backgroundBlur);
      add('snowSize', v.snowSize);
      add('snowDensity', v.snowDensity);
      add('particleColor', v.particlesColor);
      add('particleSize', v.particlesSize);
      add('particleDensity', v.particlesDensity);
      add('shadow', v.cardShadowStrength);
      add('glow', v.cardGlowStrength);
      add('pageMs', v.pageTransitionMs);
      add('loaderMs', v.loaderMinMs);
      add('menuMs', v.bellMenuMs);
      add('shakeMs', v.bellShakeMs);
      add('articleMs', v.articleTransitionMs);
      add('gravatar', v.gravatarBaseUrl);
      add('filterKeywords', v.keywordFilterKeywords.join('\n'));
      add('filterReplacement', v.keywordFilterReplacement);
      add('supabaseUrl', v.supabaseUrl);
      add('anonKey', v.supabaseAnonKey);
      add('seoDescription', v.seoDescription);
      add('canonicalUrl', v.seoCanonicalUrl);
      add('seoKeywords', v.seoKeywords.join(', '));
      add('titleTemplate', v.seoTitleTemplate);
      add('extraPaths', v.sitemapExtraPaths.join('\n'));
      add('raw', v.raw);
    } catch (e) {
      _message('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_config == null) {
      return const Center(child: Text('无法加载 public/config.js'));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        child: Row(children: [
          Expanded(
              child: TabBar(controller: _tabs, isScrollable: true, tabs: const [
            Tab(text: '基本设置'),
            Tab(text: '外观与动画'),
            Tab(text: '菜单'),
            Tab(text: '字体'),
            Tab(text: '友情链接'),
            Tab(text: '评论与数据库'),
            Tab(text: 'SEO'),
            Tab(text: '高级'),
          ])),
          const SizedBox(width: 12),
          FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存配置')),
        ]),
      ),
      Expanded(
          child: TabBarView(controller: _tabs, children: [
        _scroll([
          _heading('站点信息'),
          _field('siteName', '网站名称'),
          _field('siteQuote', '网站格言'),
          _assetChooser('博主头像', _config!.siteAvatar,
              (v) => setState(() => _config!.siteAvatar = v)),
          _assetChooser('网站图标 / Icon', _config!.siteIcon,
              (v) => setState(() => _config!.siteIcon = v)),
          _heading('页脚'),
          _field('icp', 'ICP备案号'),
          _field('icpLink', '备案链接'),
          _field('copyright', '版权文本')
        ]),
        _appearance(),
        _menu(),
        _fonts(),
        _friendLinks(),
        _scroll([
          _heading('评论'),
          _field('gravatar', 'Gravatar 镜像地址'),
          _switch('启用关键词过滤', _config!.keywordFilterEnabled,
              (v) => _config!.keywordFilterEnabled = v),
          _field('filterKeywords', '过滤关键词（每行一个）', lines: 5),
          _field('filterReplacement', '替换文本'),
          _heading('Supabase 前端数据库'),
          const Text('这里保存的是博客前端使用的公开 anon key；管理密钥仍在“连接”中安全保存。'),
          const SizedBox(height: 12),
          _field('supabaseUrl', 'Supabase URL'),
          _field('anonKey', 'Anon Public Key', lines: 3)
        ]),
        _seo(),
        _advanced(),
      ])),
    ]);
  }

  Widget _appearance() => _scroll([
        _heading('主题与背景'),
        _colorField('theme', '默认主题色'),
        _assetChooser('站点背景图片', _config!.backgroundImage,
            (v) => setState(() => _config!.backgroundImage = v),
            allowEmpty: true),
        _sliderField('opacity', '背景透明度', 0, 1),
        _sliderField('blur', '背景模糊（px）', 0, 30),
        _heading('雪花'),
        _switch('启用飘雪', _config!.snowEnabled, (v) => _config!.snowEnabled = v),
        _numberRow([_field('snowSize', '大小倍率'), _field('snowDensity', '密度')]),
        _heading('粒子'),
        _switch('启用发光粒子', _config!.particlesEnabled,
            (v) => _config!.particlesEnabled = v),
        _colorField('particleColor', '粒子颜色'),
        _numberRow(
            [_field('particleSize', '大小倍率'), _field('particleDensity', '密度')]),
        _heading('铃铛与卡片'),
        _switch('点击铃铛时晃动', _config!.bellShakeOnClick,
            (v) => _config!.bellShakeOnClick = v),
        _numberRow(
            [_field('shadow', '阴影强度（0–2）'), _field('glow', '辉光强度（0–2）')]),
        _heading('动画'),
        _switch('尊重系统“减少动态效果”', _config!.respectReducedMotion,
            (v) => _config!.respectReducedMotion = v),
        _numberRow(
            [_field('pageMs', '页面切换 ms'), _field('loaderMs', '加载动画 ms')]),
        _numberRow([_field('menuMs', '菜单展开 ms'), _field('shakeMs', '铃铛晃动 ms')]),
        _field('articleMs', '文章转场 ms'),
      ]);

  Widget _menu() => _scroll([
        Row(children: [
          _heading('导航菜单'),
          const Spacer(),
          FilledButton.tonalIcon(
              onPressed: () => _editMenu(),
              icon: const Icon(Icons.add),
              label: const Text('添加菜单'))
        ]),
        const Text('拖动排序在桌面端不够顺手，因此提供明确的上移/下移按钮。'),
        const SizedBox(height: 10),
        ..._config!.menu.asMap().entries.map((e) => Card(
                child: ListTile(
              leading: CircleAvatar(child: Text('${e.key + 1}')),
              title: Text(e.value.name),
              subtitle: Text(e.value.link),
              trailing: Wrap(children: [
                IconButton(
                    tooltip: '上移',
                    onPressed: e.key == 0 ? null : () => _moveMenu(e.key, -1),
                    icon: const Icon(Icons.arrow_upward)),
                IconButton(
                    tooltip: '下移',
                    onPressed: e.key == _config!.menu.length - 1
                        ? null
                        : () => _moveMenu(e.key, 1),
                    icon: const Icon(Icons.arrow_downward)),
                IconButton(
                    tooltip: '编辑',
                    onPressed: () => _editMenu(index: e.key),
                    icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    tooltip: '删除',
                    onPressed: () =>
                        setState(() => _config!.menu.removeAt(e.key)),
                    icon: const Icon(Icons.delete_outline)),
              ]),
            ))),
      ]);

  Widget _fonts() {
    const labels = {
      'siteName': '站点名称',
      'quote': '格言',
      'postTitle': '文章标题',
      'postContent': '文章正文',
      'menu': '菜单'
    };
    final families = _config!.fontFaces.map((e) => e.family).toList();
    return _scroll([
      Row(children: [
        _heading('本地字体'),
        const Spacer(),
        FilledButton.tonalIcon(
            onPressed: _importFont,
            icon: const Icon(Icons.font_download_outlined),
            label: const Text('导入字体'))
      ]),
      if (_config!.fontFaces.isEmpty)
        const Card(
            child: ListTile(
                title: Text('尚未导入本地字体'),
                subtitle: Text('支持 TTF、OTF、WOFF 和 WOFF2'))),
      ..._config!.fontFaces.asMap().entries.map((e) => Card(
              child: ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text(e.value.family),
            subtitle:
                Text('${e.value.src} · ${e.value.format} · ${e.value.weight}'),
            trailing: Wrap(children: [
              IconButton(
                  onPressed: () => _editFont(e.key),
                  icon: const Icon(Icons.edit_outlined)),
              IconButton(
                  onPressed: () =>
                      setState(() => _config!.fontFaces.removeAt(e.key)),
                  icon: const Icon(Icons.delete_outline))
            ]),
          ))),
      _heading('区域字体分配'),
      ...labels.entries.map((e) => Card(
          child: ListTile(
              title: Text(e.value),
              subtitle: Text(_config!.fonts[e.key] ?? ''),
              trailing: PopupMenuButton<String>(
                tooltip: '选择字体',
                onSelected: (family) => setState(
                    () => _config!.fonts[e.key] = "'$family', sans-serif"),
                itemBuilder: (_) => families
                    .map((f) => PopupMenuItem(value: f, child: Text(f)))
                    .toList(),
                icon: const Icon(Icons.arrow_drop_down_circle_outlined),
              )))),
    ]);
  }

  Widget _friendLinks() => _scroll([
        Row(children: [
          _heading('友情链接'),
          const Spacer(),
          FilledButton.tonalIcon(
              onPressed: () => _editFriendLink(),
              icon: const Icon(Icons.add_link),
              label: const Text('添加友链'))
        ]),
        const Text('名称与网址必填；头像可从站点图片中选择，也可填写外链。'),
        const SizedBox(height: 10),
        if (_config!.friendLinks.isEmpty)
          const Card(child: ListTile(title: Text('还没有友情链接'))),
        ..._config!.friendLinks.asMap().entries.map((entry) {
          final item = entry.value;
          final avatar = _publicFile(item.avatar);
          return Card(
              child: ListTile(
            leading: CircleAvatar(
                backgroundImage: avatar != null && avatar.existsSync()
                    ? FileImage(avatar)
                    : null,
                child: avatar == null || !avatar.existsSync()
                    ? const Icon(Icons.link)
                    : null),
            title: Text(item.name),
            subtitle: Text([item.url, item.description]
                .where((value) => value.isNotEmpty)
                .join('\n')),
            trailing: Wrap(children: [
              IconButton(
                  tooltip: '上移',
                  onPressed: entry.key == 0
                      ? null
                      : () => _moveFriendLink(entry.key, -1),
                  icon: const Icon(Icons.arrow_upward)),
              IconButton(
                  tooltip: '下移',
                  onPressed: entry.key == _config!.friendLinks.length - 1
                      ? null
                      : () => _moveFriendLink(entry.key, 1),
                  icon: const Icon(Icons.arrow_downward)),
              IconButton(
                  tooltip: '编辑',
                  onPressed: () => _editFriendLink(index: entry.key),
                  icon: const Icon(Icons.edit_outlined)),
              IconButton(
                  tooltip: '删除',
                  onPressed: () =>
                      setState(() => _config!.friendLinks.removeAt(entry.key)),
                  icon: const Icon(Icons.delete_outline)),
            ]),
          ));
        }),
      ]);

  Widget _seo() => _scroll([
        _heading('搜索与分享'),
        _field('seoDescription', '站点描述', lines: 3),
        _field('canonicalUrl', 'Canonical 站点根地址'),
        _field('seoKeywords', '关键词（逗号分隔）'),
        _field('titleTemplate', '标题模板（如 {title} | {siteName}）'),
        _assetChooser('社交分享图', _config!.seoSocialImage,
            (v) => setState(() => _config!.seoSocialImage = v),
            allowEmpty: true),
        _heading('Sitemap'),
        _switch('构建时生成 sitemap.xml', _config!.sitemapEnabled,
            (v) => _config!.sitemapEnabled = v),
        _field('extraPaths', '额外收录路径（每行一个）', lines: 4),
        Row(children: [
          _heading('Robots 规则'),
          const Spacer(),
          FilledButton.tonalIcon(
              onPressed: () => _editRobotsRule(),
              icon: const Icon(Icons.add),
              label: const Text('添加规则'))
        ]),
        _switch('构建时生成 robots.txt', _config!.robotsEnabled,
            (v) => _config!.robotsEnabled = v),
        ..._config!.robotsRules.asMap().entries.map((entry) => Card(
                child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text('User-Agent: ${entry.value.userAgent}'),
              subtitle: Text(
                  '允许：${entry.value.allow.join(', ')}\n禁止：${entry.value.disallow.join(', ')}'),
              trailing: Wrap(children: [
                IconButton(
                    tooltip: '编辑',
                    onPressed: () => _editRobotsRule(index: entry.key),
                    icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    tooltip: '删除',
                    onPressed: () => setState(
                        () => _config!.robotsRules.removeAt(entry.key)),
                    icon: const Icon(Icons.delete_outline))
              ]),
            ))),
      ]);

  Widget _advanced() => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('完整 config.js'),
            subtitle: Text('面向高级用户。这里的修改会直接覆盖表单尚未保存的内容。')),
        Expanded(
            child: TextField(
                controller: c['raw'],
                expands: true,
                maxLines: null,
                minLines: null,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                    labelText: 'public/config.js', alignLabelWithHint: true))),
      ]));

  Widget _scroll(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(20), children: children);
  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge));
  Widget _field(String key, String label, {int lines = 1}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
          controller: c[key],
          maxLines: lines,
          decoration: InputDecoration(labelText: label)));
  Widget _numberRow(List<Widget> items) => LayoutBuilder(
      builder: (_, box) => box.maxWidth < 560
          ? Column(children: items)
          : Row(
              children: items
                  .map((e) => Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(right: 12), child: e)))
                  .toList()));
  Widget _colorField(String key, String label) => Row(children: [
        Expanded(child: _field(key, label)),
        Container(
            margin: const EdgeInsets.only(left: 8, bottom: 12),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: _parseColor(c[key]!.text),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant)))
      ]);
  Widget _sliderField(String key, String label, double min, double max) {
    final value = (double.tryParse(c[key]!.text) ?? min).clamp(min, max);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label：${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}'),
      Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (v) => setState(() => c[key]!.text = '$v'))
    ]);
  }

  Widget _switch(String title, bool value, void Function(bool) write) =>
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          value: value,
          onChanged: (v) => setState(() => write(v)));

  Widget _assetChooser(
      String label, String value, ValueChanged<String> onChanged,
      {bool allowEmpty = false}) {
    final file = _publicFile(value);
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                  width: 100,
                  height: 76,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest),
                  child: file != null && file.existsSync()
                      ? Image.file(file,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported_outlined))
                      : const Icon(Icons.image_outlined, size: 36)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(value.isEmpty ? '未设置' : value,
                        overflow: TextOverflow.ellipsis)
                  ])),
              if (allowEmpty && value.isNotEmpty)
                IconButton(
                    onPressed: () => onChanged(''),
                    tooltip: '清除',
                    icon: const Icon(Icons.clear)),
              FilledButton.tonalIcon(
                  onPressed: () => _chooseImage(onChanged),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('选择')),
            ])));
  }

  File? _publicFile(String url) => url.startsWith('/')
      ? File(p.joinAll([
          widget.controller.settings.repositoryPath,
          'public',
          ...url.substring(1).split('/')
        ]))
      : null;
  Color _parseColor(String value) {
    final hex = value.replaceFirst('#', '');
    return Color(int.tryParse('ff$hex', radix: 16) ?? 0xff888888);
  }

  Future<void> _chooseImage(ValueChanged<String> onChanged) async {
    final files = await widget.controller.assetService
        .list(widget.controller.settings.repositoryPath);
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('选择站点图片'),
                content: SizedBox(
                    width: 680,
                    height: 430,
                    child: files.isEmpty
                        ? const Center(child: Text('public/images 中暂无图片，请先导入'))
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 180,
                                    mainAxisExtent: 155,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8),
                            itemCount: files.length,
                            itemBuilder: (_, i) => InkWell(
                                onTap: () {
                                  onChanged(
                                      '/images/${p.basename(files[i].path)}');
                                  Navigator.pop(dialogContext);
                                },
                                child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(children: [
                                      Expanded(
                                          child: Image.file(files[i],
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons
                                                      .insert_drive_file_outlined))),
                                      Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Text(p.basename(files[i].path),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis))
                                    ]))))),
                actions: [
                  TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _importImage(onChanged);
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('导入新图片')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('取消'))
                ]));
  }

  Future<void> _importImage(ValueChanged<String> onChanged) async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    final path = picked?.files.single.path;
    if (path == null) return;
    final target = await widget.controller.assetService
        .import(widget.controller.settings.repositoryPath, File(path));
    setState(() => onChanged('/images/${p.basename(target.path)}'));
  }

  void _moveMenu(int index, int delta) => setState(() {
        final item = _config!.menu.removeAt(index);
        _config!.menu.insert(index + delta, item);
      });

  Future<void> _editMenu({int? index}) async {
    final item = index == null
        ? MenuItemConfig(name: '', link: '/')
        : _config!.menu[index];
    final name = TextEditingController(text: item.name),
        link = TextEditingController(text: item.link);
    final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: Text(index == null ? '添加菜单' : '编辑菜单'),
                    content: SizedBox(
                        width: 420,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                              controller: name,
                              decoration:
                                  const InputDecoration(labelText: '菜单名称')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: link,
                              decoration:
                                  const InputDecoration(labelText: '链接 / 路由'))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('确定'))
                    ])) ??
        false;
    if (ok && name.text.trim().isNotEmpty) {
      setState(() {
        if (index == null) {
          _config!.menu.add(
              MenuItemConfig(name: name.text.trim(), link: link.text.trim()));
        } else {
          item.name = name.text.trim();
          item.link = link.text.trim();
        }
      });
    }
    name.dispose();
    link.dispose();
  }

  void _moveFriendLink(int index, int delta) => setState(() {
        final item = _config!.friendLinks.removeAt(index);
        _config!.friendLinks.insert(index + delta, item);
      });

  Future<void> _editFriendLink({int? index}) async {
    final item = index == null
        ? FriendLinkConfig(name: '', url: '')
        : _config!.friendLinks[index];
    final name = TextEditingController(text: item.name);
    final url = TextEditingController(text: item.url);
    final description = TextEditingController(text: item.description);
    final avatar = TextEditingController(text: item.avatar);
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(index == null ? '添加友情链接' : '编辑友情链接'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: '名称')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: url,
                      decoration: const InputDecoration(labelText: '网址')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: '描述（可选）')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: avatar,
                      decoration: InputDecoration(
                          labelText: '头像（可选）',
                          suffixIcon: IconButton(
                              tooltip: '从站点图片选择',
                              onPressed: () =>
                                  _chooseImage((value) => avatar.text = value),
                              icon: const Icon(Icons.photo_library_outlined))))
                ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('确定'))
            ],
          ),
        ) ??
        false;
    if (ok && name.text.trim().isNotEmpty && url.text.trim().isNotEmpty) {
      setState(() {
        if (index == null) {
          _config!.friendLinks.add(FriendLinkConfig(
              name: name.text.trim(),
              url: url.text.trim(),
              description: description.text.trim(),
              avatar: avatar.text.trim()));
        } else {
          item
            ..name = name.text.trim()
            ..url = url.text.trim()
            ..description = description.text.trim()
            ..avatar = avatar.text.trim();
        }
      });
    }
    for (final controller in [name, url, description, avatar]) {
      controller.dispose();
    }
  }

  Future<void> _editRobotsRule({int? index}) async {
    final rule =
        index == null ? RobotsRuleConfig() : _config!.robotsRules[index];
    final agent = TextEditingController(text: rule.userAgent);
    final allow = TextEditingController(text: rule.allow.join('\n'));
    final disallow = TextEditingController(text: rule.disallow.join('\n'));
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(index == null ? '添加 Robots 规则' : '编辑 Robots 规则'),
            content: SizedBox(
              width: 520,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: agent,
                    decoration: const InputDecoration(labelText: 'User-Agent')),
                const SizedBox(height: 12),
                TextField(
                    controller: allow,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '允许路径（每行一个）')),
                const SizedBox(height: 12),
                TextField(
                    controller: disallow,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '禁止路径（每行一个）')),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('确定'))
            ],
          ),
        ) ??
        false;
    if (ok) {
      final updated = RobotsRuleConfig(
        userAgent: agent.text.trim().isEmpty ? '*' : agent.text.trim(),
        allow: _lines(allow.text),
        disallow: _lines(disallow.text),
      );
      setState(() {
        if (index == null) {
          _config!.robotsRules.add(updated);
        } else {
          _config!.robotsRules[index] = updated;
        }
      });
    }
    for (final controller in [agent, allow, disallow]) {
      controller.dispose();
    }
  }

  Future<void> _importFont() async {
    final pick = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf', 'woff', 'woff2']);
    final source = pick?.files.single.path;
    if (source == null) return;
    final dir = Directory(
        p.join(widget.controller.settings.repositoryPath, 'public', 'font'));
    await dir.create(recursive: true);
    final target =
        await File(source).copy(p.join(dir.path, p.basename(source)));
    final ext = p.extension(target.path).substring(1);
    setState(() => _config!.fontFaces.add(FontFaceConfig(
        family: p.basenameWithoutExtension(target.path),
        src: '/font/${p.basename(target.path)}',
        format: ext == 'ttf'
            ? 'truetype'
            : ext == 'otf'
                ? 'opentype'
                : ext)));
  }

  Future<void> _editFont(int index) async {
    final f = _config!.fontFaces[index];
    final family = TextEditingController(text: f.family),
        weight = TextEditingController(text: f.weight);
    final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('编辑字体'),
                    content: SizedBox(
                        width: 420,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                              controller: family,
                              decoration:
                                  const InputDecoration(labelText: '字体族名称')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: weight,
                              decoration:
                                  const InputDecoration(labelText: '字重'))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('确定'))
                    ])) ??
        false;
    if (ok) {
      setState(() {
        f.family = family.text.trim();
        f.weight = weight.text.trim();
      });
    }
    family.dispose();
    weight.dispose();
  }

  double _d(String key, double fallback) =>
      double.tryParse(c[key]!.text.trim()) ?? fallback;
  int _i(String key, int fallback) =>
      int.tryParse(c[key]!.text.trim()) ?? fallback;
  List<String> _lines(String value) => value
      .split(RegExp(r'[\r\n]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  Future<void> _save() async {
    final v = _config!;
    if (_tabs.index == 7) {
      try {
        await widget.controller.configService
            .saveRaw(widget.controller.settings.repositoryPath, c['raw']!.text);
        await _commitAndReload();
      } catch (e) {
        _message('$e');
      }
      return;
    }
    v.siteName = c['siteName']!.text;
    v.siteQuote = c['siteQuote']!.text;
    v.defaultThemeColor = c['theme']!.text;
    v.footerIcp = c['icp']!.text;
    v.footerIcpLink = c['icpLink']!.text;
    v.footerCopyright = c['copyright']!.text;
    v.backgroundOpacity = _d('opacity', .25);
    v.backgroundBlur = _d('blur', 0);
    v.snowSize = _d('snowSize', 1);
    v.snowDensity = _d('snowDensity', .0001);
    v.particlesColor = c['particleColor']!.text;
    v.particlesSize = _d('particleSize', 1);
    v.particlesDensity = _d('particleDensity', .0001);
    v.cardShadowStrength = _d('shadow', 1);
    v.cardGlowStrength = _d('glow', 1);
    v.pageTransitionMs = _i('pageMs', 620);
    v.loaderMinMs = _i('loaderMs', 620);
    v.bellMenuMs = _i('menuMs', 620);
    v.bellShakeMs = _i('shakeMs', 620);
    v.articleTransitionMs = _i('articleMs', 720);
    v.gravatarBaseUrl = c['gravatar']!.text;
    v.keywordFilterKeywords = _lines(c['filterKeywords']!.text);
    v.keywordFilterReplacement = c['filterReplacement']!.text;
    v.supabaseUrl = c['supabaseUrl']!.text;
    v.supabaseAnonKey = c['anonKey']!.text;
    v.seoDescription = c['seoDescription']!.text;
    v.seoCanonicalUrl = c['canonicalUrl']!.text;
    v.seoKeywords = c['seoKeywords']!
        .text
        .split(RegExp('[,，]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    v.seoTitleTemplate = c['titleTemplate']!.text;
    v.sitemapExtraPaths = _lines(c['extraPaths']!.text);
    try {
      await widget.controller.configService
          .saveCommon(widget.controller.settings.repositoryPath, v);
      await _commitAndReload();
    } catch (e) {
      _message('$e');
    }
  }

  Future<void> _commitAndReload() async {
    String? commit;
    if (await widget.controller.gitService.isAvailable) {
      commit = await widget.controller.gitService.saveCommit(
          widget.controller.settings.repositoryPath,
          message: 'config: update site settings');
    }
    _message(commit == null ? '配置已保存。' : '配置已保存并提交 $commit');
    await _load();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}
