import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starry_note/models/article.dart';
import 'package:starry_note/services/article_service.dart';

void main() {
  test('parses Starry frontmatter', () {
    final article = ArticleService().parse('''---
title: '一篇文章'
date: 2026-06-19
category: tech
author: Starry
cover: ''
excerpt: 测试摘要
description: 搜索摘要
canonical: https://example.com/article
noindex: true
tags: [Flutter, 随笔]
page: true
---

# 正文
''');
    expect(article.title, '一篇文章');
    expect(article.formattedDate, '2026-06-19');
    expect(article.tags, ['Flutter', '随笔']);
    expect(article.page, isTrue);
    expect(article.description, '搜索摘要');
    expect(article.canonical, 'https://example.com/article');
    expect(article.noindex, isTrue);
    expect(article.body, contains('# 正文'));
  });

  test('save rebuilds index in blog format', () async {
    final root = await Directory.systemTemp.createTemp('starry-note-test');
    addTearDown(() => root.delete(recursive: true));
    final articles = Directory(
      '${root.path}${Platform.pathSeparator}public${Platform.pathSeparator}articles',
    );
    await articles.create(recursive: true);
    final service = ArticleService();
    await service.save(
      root.path,
      Article(
        slug: 'hello',
        title: 'Hello',
        date: DateTime(2026, 6, 19),
        category: 'tech',
        author: 'Starry',
        cover: '',
        excerpt: 'Hi',
        tags: ['Flutter'],
        body: '# Hello',
        page: true,
      ),
    );
    final index = await File(
      '${articles.path}${Platform.pathSeparator}index.json',
    ).readAsString();
    expect(index, contains('"slug": "hello"'));
    expect(index, contains('"date": "2026-06-19"'));
    expect(index, contains('"page": true'));
    final markdown = await File(
      '${articles.path}${Platform.pathSeparator}hello.md',
    ).readAsString();
    expect(markdown, contains('page: true'));
  });
}
