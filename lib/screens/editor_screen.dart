import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pasteboard/pasteboard.dart';

import '../app_controller.dart';
import '../models/article.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.controller,
    required this.article,
  });
  final AppController controller;
  final Article article;
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _category;
  late final TextEditingController _author;
  late final TextEditingController _cover;
  late final TextEditingController _excerpt;
  late final TextEditingController _tags;
  late final TextEditingController _body;
  late DateTime _date;
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    final article = widget.article;
    _tabs = TabController(length: 2, vsync: this);
    _title = TextEditingController(text: article.title);
    _slug = TextEditingController(text: article.slug);
    _category = TextEditingController(text: article.category);
    _author = TextEditingController(text: article.author);
    _cover = TextEditingController(text: article.cover);
    _excerpt = TextEditingController(text: article.excerpt);
    _tags = TextEditingController(text: article.tags.join(', '));
    _body = TextEditingController(text: article.body)
      ..addListener(_refreshPreview);
    _date = article.date;
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _title,
      _slug,
      _category,
      _author,
      _cover,
      _excerpt,
      _tags,
      _body,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_title.text.isEmpty ? '新文章' : _title.text),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: '编辑'),
              Tab(text: '预览'),
            ],
          ),
          actions: [
            if (widget.article.filePath != null)
              IconButton(
                tooltip: '删除文章',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: widget.controller.busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存并提交'),
              ),
            ),
          ],
        ),
        body: TabBarView(controller: _tabs, children: [_editor(), _preview()]),
      );

  Widget _editor() => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fields = [
                      _field(
                        _title,
                        '标题',
                        onChanged: (_) => setState(() {
                          if (_slug.text.isEmpty) {
                            _slug.text =
                                widget.controller.articleService.slugify(
                              _title.text,
                            );
                          }
                        }),
                      ),
                      _field(_slug, 'Slug / 文件名'),
                      _field(_category, '分类'),
                      _field(_author, '作者'),
                    ];
                    if (constraints.maxWidth < 700) {
                      return Column(children: fields);
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[1]),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: fields[2]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[3]),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: '日期'),
                        child: Text(_formatDate(_date)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(_cover, '封面 URL'),
                _field(_excerpt, '摘要', maxLines: 2),
                _field(_tags, '标签（逗号分隔）'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('正文', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _uploading ? null : _pasteImage,
                      icon: _uploading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('粘贴图片到 R2'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _markdownToolbar(),
                const SizedBox(height: 8),
                CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.keyV,
                        control: true): _paste,
                  },
                  child: TextField(
                    controller: _body,
                    minLines: 22,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style:
                        const TextStyle(fontFamily: 'monospace', height: 1.55),
                    decoration: const InputDecoration(
                      hintText: '# 从这里开始写作…',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _markdownToolbar() {
    final actions = <(String, IconData, VoidCallback)>[
      ('一级标题', Icons.looks_one_outlined, () => _prefix('# ')),
      ('二级标题', Icons.looks_two_outlined, () => _prefix('## ')),
      ('三级标题', Icons.looks_3_outlined, () => _prefix('### ')),
      ('四级标题', Icons.looks_4_outlined, () => _prefix('#### ')),
      ('引用', Icons.format_quote, () => _prefix('> ')),
      ('表格', Icons.table_chart_outlined, _table),
      ('多行代码', Icons.code, () => _wrap('```\n', '\n```', '代码')),
      ('加粗', Icons.format_bold, () => _wrap('**', '**', '粗体文本')),
      ('删除线', Icons.format_strikethrough, () => _wrap('~~', '~~', '删除线文本')),
      ('倾斜', Icons.format_italic, () => _wrap('*', '*', '斜体文本')),
      ('无序列表', Icons.format_list_bulleted, () => _prefix('- ')),
      ('有序列表', Icons.format_list_numbered, _orderedList),
      ('超链接', Icons.link, () => _wrap('[', '](https://)', '链接文字')),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: actions
                .map((action) => Tooltip(
                      message: action.$1,
                      child: IconButton(
                        onPressed: action.$3,
                        icon: Icon(action.$2),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  ({int start, int end, String selected}) get _selection {
    final selection = _body.selection;
    if (!selection.isValid) {
      final end = _body.text.length;
      return (start: end, end: end, selected: '');
    }
    final start =
        selection.start < selection.end ? selection.start : selection.end;
    final end =
        selection.start < selection.end ? selection.end : selection.start;
    return (
      start: start,
      end: end,
      selected: _body.text.substring(start, end),
    );
  }

  void _wrap(String before, String after, String placeholder) {
    final selection = _selection;
    final content =
        selection.selected.isEmpty ? placeholder : selection.selected;
    final replacement = '$before$content$after';
    _body.value = TextEditingValue(
      text:
          _body.text.replaceRange(selection.start, selection.end, replacement),
      selection: TextSelection(
        baseOffset: selection.start + before.length,
        extentOffset: selection.start + before.length + content.length,
      ),
    );
  }

  void _prefix(String prefix) => _prefixLines(
        (index) => prefix,
        placeholder: '文本',
      );

  void _orderedList() => _prefixLines(
        (index) => '${index + 1}. ',
        placeholder: '列表项',
      );

  void _prefixLines(
    String Function(int index) prefix, {
    required String placeholder,
  }) {
    final selection = _selection;
    final content =
        selection.selected.isEmpty ? placeholder : selection.selected;
    final lines = content.split('\n');
    final replacement = [
      for (var i = 0; i < lines.length; i++) '${prefix(i)}${lines[i]}',
    ].join('\n');
    _body.value = TextEditingValue(
      text:
          _body.text.replaceRange(selection.start, selection.end, replacement),
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + replacement.length,
      ),
    );
  }

  void _table() {
    final selection = _selection;
    final content = selection.selected.isEmpty ? '内容' : selection.selected;
    final table = '| 标题 1 | 标题 2 |\n| --- | --- |\n| $content | 内容 |';
    _body.value = TextEditingValue(
      text: _body.text.replaceRange(selection.start, selection.end, table),
      selection: TextSelection(
        baseOffset: selection.start + table.indexOf(content),
        extentOffset: selection.start + table.indexOf(content) + content.length,
      ),
    );
  }

  Widget _preview() => Markdown(
        data: _body.text,
        selectable: true,
        padding: const EdgeInsets.all(28),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _paste() async {
    final image = await Pasteboard.image;
    if (image != null && image.isNotEmpty) {
      await _uploadImage(image);
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) _insert(data!.text!);
  }

  Future<void> _pasteImage() async {
    final image = await Pasteboard.image;
    if (image == null || image.isEmpty) {
      _message('剪贴板里没有图片。');
      return;
    }
    await _uploadImage(image);
  }

  Future<void> _uploadImage(List<int> bytes) async {
    setState(() => _uploading = true);
    try {
      final url = await widget.controller.r2Service.uploadBytes(
        widget.controller.settings,
        Uint8List.fromList(bytes),
        filename: 'clipboard.png',
      );
      _insert(
        '![${_title.text.trim().isEmpty ? '图片' : _title.text.trim()}]($url)',
      );
      _message('图片已上传并插入 Markdown。');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _insert(String value) {
    final selection = _body.selection;
    final start = selection.isValid ? selection.start : _body.text.length;
    final end = selection.isValid ? selection.end : _body.text.length;
    _body.value = TextEditingValue(
      text: _body.text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    final article = widget.article
      ..title = _title.text.trim()
      ..slug = _slug.text.trim()
      ..category = _category.text.trim()
      ..author = _author.text.trim()
      ..cover = _cover.text.trim()
      ..excerpt = _excerpt.text.trim()
      ..tags = _tags.text
          .split(RegExp('[,，]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList()
      ..body = _body.text
      ..date = _date;
    try {
      final commit = await widget.controller.saveArticle(article);
      if (mounted) _message(commit == null ? '没有新的改动。' : '已保存并提交 $commit');
    } catch (_) {
      if (mounted) _message(widget.controller.error ?? '保存失败');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这篇文章？'),
        content: const Text('删除操作也会创建一个可撤销的 Git 提交。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.controller.deleteArticle(widget.article);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) _message(widget.controller.error ?? '删除失败');
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  void _message(String value) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
}
