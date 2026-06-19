import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/article.dart';
import 'editor_screen.dart';

class ArticlesScreen extends StatelessWidget {
  const ArticlesScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                '${controller.articles.length} 篇文章',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                onPressed: controller.refreshArticles,
                tooltip: '刷新',
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _open(context),
                icon: const Icon(Icons.add),
                label: const Text('新文章'),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.articles.isEmpty
              ? const Center(child: Text('还没有文章。写下第一颗星吧。'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.articles.length,
                  itemBuilder: (context, index) {
                    final article = controller.articles[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        title: Text(
                          article.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${article.formattedDate} · ${article.category} · /${article.slug}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(context, article),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Future<void> _open(BuildContext context, [Article? article]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          controller: controller,
          article:
              article ??
              Article(
                slug: '',
                title: '',
                date: DateTime.now(),
                category: 'life',
                author: '',
                cover: '',
                excerpt: '',
                tags: [],
                body: '',
              ),
        ),
      ),
    );
    await controller.refreshArticles();
  }
}
