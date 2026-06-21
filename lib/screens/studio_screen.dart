import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'articles_screen.dart';
import 'assets_screen.dart';
import 'appearance_screen.dart';
import 'backup_screen.dart';
import 'comments_screen.dart';
import 'connection_screen.dart';
import 'site_config_screen.dart';
import 'wordpress_import_screen.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  var _index = 0;
  final _destinations = const [
    NavigationRailDestination(icon: Icon(Icons.edit_note), label: Text('文章')),
    NavigationRailDestination(
      icon: Icon(Icons.forum_outlined),
      label: Text('评论'),
    ),
    NavigationRailDestination(icon: Icon(Icons.tune), label: Text('网站配置')),
    NavigationRailDestination(
      icon: Icon(Icons.photo_library_outlined),
      label: Text('静态资源'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.cloud_outlined),
      label: Text('连接'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.backup_outlined),
      label: Text('备份'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.move_to_inbox_outlined),
      label: Text('WP 导入'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.palette_outlined),
      label: Text('外观'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      ArticlesScreen(controller: widget.controller),
      CommentsScreen(controller: widget.controller),
      SiteConfigScreen(controller: widget.controller),
      AssetsScreen(controller: widget.controller),
      ConnectionScreen(controller: widget.controller),
      BackupScreen(controller: widget.controller),
      WordPressImportScreen(controller: widget.controller),
      AppearanceScreen(controller: widget.controller),
    ];
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 20),
            SizedBox(width: 8),
            Text('StarryNote'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '撤销上一次提交',
            onPressed: widget.controller.busy ? null : _undo,
            icon: const Icon(Icons.undo),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: widget.controller.busy ? null : _push,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Push'),
            ),
          ),
        ],
        bottom: widget.controller.busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Row(
        children: [
          if (!compact)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              destinations: _destinations,
            ),
          if (!compact) const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: _destinations
                  .map(
                    (item) => NavigationDestination(
                      icon: item.icon,
                      label: (item.label as Text).data!,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }

  Future<void> _push() async {
    try {
      await widget.controller.push();
      if (mounted) _message('已推送到远程仓库。');
    } catch (_) {
      if (mounted) _message(widget.controller.error ?? 'Push 失败');
    }
  }

  Future<void> _undo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销上一次提交？'),
        content: const Text('提交会被撤销，但文件改动会保留在工作区，可继续编辑后重新保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销提交'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.controller.undoLastCommit();
      if (mounted) _message('上一次提交已撤销，改动仍保留。');
    } catch (_) {
      if (mounted) _message(widget.controller.error ?? '撤销失败');
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
