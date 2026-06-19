import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/comment.dart';

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  Future<List<BlogComment>>? _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = widget.controller.comments());

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Text('评论管理', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<BlogComment>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _empty('无法读取评论\n${snapshot.error}');
            final comments = snapshot.data ?? [];
            if (comments.isEmpty) return _empty('暂无评论');
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            comment.nickname,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          comment.slug,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${comment.content}\n${comment.createdAt.toLocal()}',
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '删除',
                      onPressed: () => _delete(comment),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  Widget _empty(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
  Future<void> _delete(BlogComment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除评论？'),
        content: Text(comment.content),
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
      await widget.controller.deleteComment(comment.id);
      _reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}
