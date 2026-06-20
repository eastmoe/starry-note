import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<SupabaseTableInfo> _tables = const [];
  late Set<String> _selected;
  late bool _automatic;
  late int _intervalHours;
  late String _directory;
  bool _loadingTables = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.settings;
    _selected = settings.backupTables.toSet();
    _automatic = settings.autoBackupEnabled;
    _intervalHours = settings.backupIntervalHours;
    _directory = settings.backupDirectory;
    _refreshTables();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('数据库备份', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '从 Supabase 导出数据型 SQL，可恢复到已有表结构的数据库。管理 API Key 仅保存在本机。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.table_chart_outlined),
                    const SizedBox(width: 10),
                    Text('备份范围', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      tooltip: '重新读取数据表',
                      onPressed: _loadingTables ? null : _refreshTables,
                      icon: const Icon(Icons.refresh),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  if (_loadingTables)
                    const LinearProgressIndicator()
                  else if (_tables.isEmpty)
                    const Text('未读取到数据表。请先在“连接”中配置 Supabase 管理凭据。')
                  else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tables
                          .map(
                            (table) => FilterChip(
                              label: Text(table.name),
                              selected: _selected.contains(table.name),
                              onSelected: (value) => setState(() {
                                value
                                    ? _selected.add(table.name)
                                    : _selected.remove(table.name);
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() {
                          if (_selected.length == _tables.length) {
                            _selected.clear();
                          } else {
                            _selected =
                                _tables.map((table) => table.name).toSet();
                          }
                        }),
                        child: Text(_selected.length == _tables.length
                            ? '取消全选'
                            : '选择全部'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: widget.controller.busy || _selected.isEmpty
                        ? null
                        : _exportNow,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('导出 SQL 文件'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自动定时备份'),
                    subtitle:
                        const Text('StarryNote 运行时到期自动执行；重启后会根据上次成功时间继续计算。'),
                    value: _automatic,
                    onChanged: (value) => setState(() => _automatic = value),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: '备份目录'),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          _directory.isEmpty ? '尚未选择' : _directory,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: '选择目录',
                        onPressed: _chooseDirectory,
                        icon: const Icon(Icons.folder_open_outlined),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _intervalHours,
                    decoration: const InputDecoration(labelText: '备份间隔'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('每小时')),
                      DropdownMenuItem(value: 6, child: Text('每 6 小时')),
                      DropdownMenuItem(value: 12, child: Text('每 12 小时')),
                      DropdownMenuItem(value: 24, child: Text('每天')),
                      DropdownMenuItem(value: 168, child: Text('每周')),
                    ],
                    onChanged: (value) =>
                        setState(() => _intervalHours = value ?? 24),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _saveSchedule,
                    icon: const Icon(Icons.schedule),
                    label: const Text('保存自动备份设置'),
                  ),
                ],
              ),
            ),
          ),
          if (widget.controller.settings.lastBackupAt.isNotEmpty ||
              widget.controller.backupStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('最近备份'),
                  subtitle: Text(widget.controller.backupStatus ??
                      widget.controller.settings.lastBackupAt),
                ),
              ),
            ),
        ],
      );

  Future<void> _refreshTables() async {
    setState(() => _loadingTables = true);
    try {
      final tables = await widget.controller.backupTables();
      if (!mounted) return;
      setState(() {
        _tables = tables;
        if (_selected.isEmpty) {
          _selected = tables.map((table) => table.name).toSet();
        } else {
          _selected.removeWhere(
            (name) => !tables.any((table) => table.name == name),
          );
        }
      });
    } catch (error) {
      if (mounted) _message(_clean(error));
    } finally {
      if (mounted) setState(() => _loadingTables = false);
    }
  }

  Future<void> _exportNow() async {
    var path = await FilePicker.saveFile(
      dialogTitle: '导出 Supabase SQL 备份',
      fileName: 'supabase-backup.sql',
      type: FileType.custom,
      allowedExtensions: const ['sql'],
      initialDirectory: _directory.isEmpty ? null : _directory,
      bytes: Uint8List(0),
    );
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.sql')) path = '$path.sql';
    try {
      final result = await widget.controller.backupDatabase(
        outputPath: path,
        tables: _selected.toList(),
      );
      if (mounted) {
        setState(() {});
        _message('已导出 ${result.tableCount} 个表、${result.rowCount} 行。');
      }
    } catch (error) {
      if (mounted) _message(_clean(error));
    }
  }

  Future<void> _chooseDirectory() async {
    final value = await FilePicker.getDirectoryPath(
      dialogTitle: '选择自动备份目录',
      initialDirectory: _directory.isEmpty ? null : _directory,
    );
    if (value != null && mounted) setState(() => _directory = value);
  }

  Future<void> _saveSchedule() async {
    if (_automatic && _directory.isEmpty) {
      _message('启用自动备份前，请先选择备份目录。');
      return;
    }
    await widget.controller.updateSettings(
      widget.controller.settings.copyWith(
        autoBackupEnabled: _automatic,
        backupDirectory: _directory,
        backupIntervalHours: _intervalHours,
        backupTables: _selected.toList(),
      ),
    );
    if (mounted) _message('自动备份设置已保存。');
  }

  String _clean(Object error) => '$error'.replaceFirst('Exception: ', '');

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
