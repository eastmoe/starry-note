import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/article.dart';

class ArticleService {
  Directory articlesDirectory(String repositoryPath) =>
      Directory(p.join(repositoryPath, 'public', 'articles'));

  Future<List<Article>> loadAll(String repositoryPath) async {
    final directory = articlesDirectory(repositoryPath);
    if (!await directory.exists()) return [];
    final articles = <Article>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.md')) {
        articles.add(await load(entity));
      }
    }
    articles.sort((a, b) => b.date.compareTo(a.date));
    return articles;
  }

  Future<Article> load(File file) async {
    final raw = await file.readAsString();
    final parsed = parse(raw);
    parsed.filePath = file.path;
    if (parsed.slug.isEmpty) {
      parsed.slug = p.basenameWithoutExtension(file.path);
    }
    return parsed;
  }

  Article parse(String markdown) {
    final normalized = markdown.replaceAll('\r\n', '\n');
    final match = RegExp(r'^---\n([\s\S]*?)\n---\n?').firstMatch(normalized);
    final values = <String, String>{};
    var body = normalized;
    if (match != null) {
      body = normalized.substring(match.end);
      for (final line in match.group(1)!.split('\n')) {
        final colon = line.indexOf(':');
        if (colon > 0) {
          values[line.substring(0, colon).trim()] = _unquote(
            line.substring(colon + 1).trim(),
          );
        }
      }
    }
    final date = DateTime.tryParse(values['date'] ?? '') ?? DateTime.now();
    final tagsRaw = values['tags'] ?? '';
    final tags = tagsRaw
        .replaceAll(RegExp(r'^\[|\]$'), '')
        .split(',')
        .map((value) => _unquote(value.trim()))
        .where((value) => value.isNotEmpty)
        .toList();
    return Article(
      slug: '',
      title: values['title'] ?? '',
      date: date,
      category: values['category'] ?? '',
      author: values['author'] ?? '',
      cover: values['cover'] ?? '',
      excerpt: values['excerpt'] ?? '',
      tags: tags,
      body: body,
      page: (values['page'] ?? '').toLowerCase() == 'true',
      description: values['description'] ?? '',
      canonical: values['canonical'] ?? '',
      noindex: (values['noindex'] ?? '').toLowerCase() == 'true',
      isPrivate: (values['private'] ?? '').toLowerCase() == 'true',
      password: values['password'] ?? '',
    );
  }

  Future<File> save(String repositoryPath, Article article) async {
    final directory = articlesDirectory(repositoryPath);
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, '${article.slug}.md'));
    if (article.filePath != null && article.filePath != file.path) {
      final old = File(article.filePath!);
      if (await old.exists()) await old.delete();
    }
    await file.writeAsString(article.toMarkdown());
    article.filePath = file.path;
    await rebuildIndex(repositoryPath);
    return file;
  }

  Future<void> delete(String repositoryPath, Article article) async {
    if (article.filePath != null) {
      final file = File(article.filePath!);
      if (await file.exists()) await file.delete();
    }
    await rebuildIndex(repositoryPath);
  }

  Future<void> rebuildIndex(String repositoryPath) async {
    final articles = await loadAll(repositoryPath);
    final data = articles
        .map(
          (article) => {
            'slug': article.slug,
            'title': article.title,
            'date': article.formattedDate,
            'category': article.category,
            'author': article.author,
            'cover': article.cover,
            'excerpt': article.excerpt,
            'description': article.description,
            'tags': article.tags,
            'page': article.page,
            'canonical': article.canonical,
            'noindex': article.noindex,
            if (article.isPrivate) 'private': true,
          },
        )
        .toList();
    final index = File(
      p.join(articlesDirectory(repositoryPath).path, 'index.json'),
    );
    await index.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    );
  }

  String slugify(String input) {
    final value = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return value.isEmpty
        ? 'post-${DateTime.now().millisecondsSinceEpoch}'
        : value;
  }

  String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith("'") && value.endsWith("'")) ||
            (value.startsWith('"') && value.endsWith('"')))) {
      return value.substring(1, value.length - 1).replaceAll("''", "'");
    }
    return value;
  }
}
