import 'package:flutter/material.dart';

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
  final _controllers = <String, TextEditingController>{};
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.controller.configService.load(
        widget.controller.settings.repositoryPath,
      );
      _config = value;
      _controllers
        ..clear()
        ..addAll({
          'siteName': TextEditingController(text: value.siteName),
          'siteAvatar': TextEditingController(text: value.siteAvatar),
          'siteIcon': TextEditingController(text: value.siteIcon),
          'siteQuote': TextEditingController(text: value.siteQuote),
          'defaultThemeColor': TextEditingController(
            text: value.defaultThemeColor,
          ),
          'raw': TextEditingController(text: value.raw),
        });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_config == null) {
      return const Center(child: Text('无法加载 public/config.js'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(text: '常用配置'),
                    Tab(text: '完整 config.js'),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存配置'),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _field('siteName', '网站名称'),
                  _field('siteQuote', '网站格言'),
                  _field('siteAvatar', '博主头像路径'),
                  _field('siteIcon', '网站 LOGO / 图标路径'),
                  _field('defaultThemeColor', '默认主题色'),
                  const SizedBox(height: 12),
                  const Text('菜单、字体、视觉效果、动画和评论细项可在“完整 config.js”中编辑。'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controllers['raw'],
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    labelText: 'public/config.js',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String key, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _controllers[key],
          decoration: InputDecoration(labelText: label),
        ),
      );
  Future<void> _save() async {
    try {
      if (_tabs.index == 1) {
        await widget.controller.configService.saveRaw(
          widget.controller.settings.repositoryPath,
          _controllers['raw']!.text,
        );
      } else {
        final config = _config!
          ..siteName = _controllers['siteName']!.text
          ..siteQuote = _controllers['siteQuote']!.text
          ..siteAvatar = _controllers['siteAvatar']!.text
          ..siteIcon = _controllers['siteIcon']!.text
          ..defaultThemeColor = _controllers['defaultThemeColor']!.text;
        await widget.controller.configService.saveCommon(
          widget.controller.settings.repositoryPath,
          config,
        );
      }
      String? commit;
      final gitAvailable = await widget.controller.gitService.isAvailable;
      if (gitAvailable) {
        commit = await widget.controller.gitService.saveCommit(
          widget.controller.settings.repositoryPath,
          message: 'config: update site settings',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !gitAvailable
                  ? '配置已保存；当前设备没有 Git，未创建提交。'
                  : (commit == null ? '配置没有变化。' : '配置已保存并提交 $commit'),
            ),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}
