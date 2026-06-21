import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/wordpress_import.dart';

class WordPressImportScreen extends StatefulWidget {
  const WordPressImportScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<WordPressImportScreen> createState() => _WordPressImportScreenState();
}

class _WordPressImportScreenState extends State<WordPressImportScreen> {
  final _path = TextEditingController();
  final _host = TextEditingController();
  final _ip = TextEditingController();
  final _password = TextEditingController();
  final _pageCategory = TextEditingController(text: '页面');
  WordPressImportPreview? _preview;
  WordPressImportProgress? _progress;
  WordPressImportResult? _result;
  bool _skipSsl = false;
  bool _media = true;
  bool _ignoreMissingMedia = true;
  bool _comments = true;
  bool _working = false;

  @override
  void dispose() {
    _path.dispose();
    _host.dispose();
    _ip.dispose();
    _password.dispose();
    _pageCategory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('WordPress 导入',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('先预检 WXR，再顺序迁移媒体并一次性写入文章。导入成功后只创建一个 Git 提交，Push 仍由你手动触发。'),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                  child: _field(_path, 'WordPress WXR/XML 文件', readOnly: true)),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _working ? null : _choose,
                icon: const Icon(Icons.folder_open),
                label: const Text('选择并预检'),
              ),
            ],
          ),
          if (_preview != null) ...[
            const SizedBox(height: 16),
            _previewCard(_preview!),
            const SizedBox(height: 16),
            Text('媒体来源', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(width: 300, child: _field(_host, '允许的源主机名')),
                SizedBox(width: 300, child: _field(_ip, '实际连接 IP（可选）')),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('跳过此源主机的 SSL 证书验证'),
              subtitle: const Text('仅用于可信的本地测试环境，不影响 R2 或其他网络请求。'),
              value: _skipSsl,
              onChanged:
                  _working ? null : (value) => setState(() => _skipSsl = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('迁移正文引用和特色图媒体到 R2'),
              subtitle: const Text('单连接顺序处理，以 SHA-256 去重并保存可恢复的导入清单。'),
              value: _media,
              onChanged:
                  _working ? null : (value) => setState(() => _media = value),
            ),
            if (_media)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('遇到媒体 404 时继续导入'),
                subtitle: const Text('保留正文中的原 URL，并在结果中统计缺失媒体；其他网络错误仍会中止。'),
                value: _ignoreMissingMedia,
                onChanged: _working
                    ? null
                    : (value) => setState(() => _ignoreMissingMedia = value),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('导入已批准评论'),
              subtitle: const Text('回复关系会转换为当前 Markdown 引用格式。'),
              value: _comments,
              onChanged: _working
                  ? null
                  : (value) => setState(() => _comments = value),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(width: 300, child: _field(_pageCategory, '页面专用分类')),
                if (_preview!.privateItems > 0)
                  SizedBox(
                    width: 300,
                    child: _field(
                      _password,
                      '私密内容统一密码',
                      obscureText: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _working ? null : _start,
              icon: const Icon(Icons.move_to_inbox),
              label: const Text('开始导入'),
            ),
          ],
          if (_progress != null) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(value: _progress!.fraction),
            const SizedBox(height: 6),
            Text(_progress!.message),
          ],
          if (_result != null) ...[
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '导入完成：${_result!.articles} 篇文章、${_result!.pages} 个页面、'
                  '${_result!.privateItems} 项私密内容；媒体上传 ${_result!.mediaUploaded}、'
                  '复用 ${_result!.mediaReused}、缺失 ${_result!.mediaMissing}；'
                  '评论导入 ${_result!.commentsImported}。',
                ),
              ),
            ),
          ],
        ],
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    bool obscureText = false,
  }) =>
      TextField(
        controller: controller,
        readOnly: readOnly,
        obscureText: obscureText,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      );

  Widget _previewCard(WordPressImportPreview preview) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(preview.siteTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(preview.sourceUrl),
              const SizedBox(height: 8),
              Text(
                '${preview.posts} 篇文章 · ${preview.pages} 个页面 · '
                '${preview.privateItems} 项私密 · ${preview.referencedMedia} 个引用媒体 · '
                '${preview.comments} 条评论 · 跳过 ${preview.skippedItems} 项',
              ),
              for (final warning in preview.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('⚠ $warning'),
                ),
            ],
          ),
        ),
      );

  Future<void> _choose() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xml'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() {
      _working = true;
      _path.text = path;
      _preview = null;
      _result = null;
      _progress = null;
    });
    try {
      final preview = await widget.controller.inspectWordPress(path);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _host.text = preview.sourceHost;
      });
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _start() async {
    if (_preview!.privateItems > 0 && _password.text.isEmpty) {
      return _message('请先为私密内容设置统一密码。');
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开始批量导入？'),
        content: Text(
            '将写入 ${_preview!.articleCount} 个 Markdown 文件。媒体迁移可能需要较长时间，期间请勿关闭应用。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('开始')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _working = true;
      _result = null;
      _progress = const WordPressImportProgress(0, 0, '准备导入…');
    });
    try {
      final result = await widget.controller.importWordPress(
        WordPressImportOptions(
          xmlPath: _path.text,
          sourceHost: _host.text,
          sourceIp: _ip.text,
          skipSslVerification: _skipSsl,
          migrateMedia: _media,
          ignoreMissingMedia: _ignoreMissingMedia,
          importComments: _comments,
          privatePassword: _password.text,
          pageCategory: _pageCategory.text,
        ),
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) _message(widget.controller.error ?? 'WordPress 导入失败');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
