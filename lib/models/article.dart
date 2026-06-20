class Article {
  Article({
    required this.slug,
    required this.title,
    required this.date,
    required this.category,
    required this.author,
    required this.cover,
    required this.excerpt,
    required this.tags,
    required this.body,
    this.page = false,
    this.description = '',
    this.canonical = '',
    this.noindex = false,
    this.filePath,
  });

  String slug;
  String title;
  DateTime date;
  String category;
  String author;
  String cover;
  String excerpt;
  List<String> tags;
  String body;
  bool page;
  String description;
  String canonical;
  bool noindex;
  String? filePath;

  String get formattedDate =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String toMarkdown() => '''---
title: ${_yaml(title)}
date: $formattedDate
category: ${_yaml(category)}
author: ${_yaml(author)}
cover: ${_yaml(cover)}
excerpt: ${_yaml(excerpt)}
description: ${_yaml(description)}
canonical: ${_yaml(canonical)}
noindex: $noindex
tags: [${tags.map(_yaml).join(', ')}]
page: $page
---

${body.trimLeft()}
''';

  static String _yaml(String value) {
    if (value.isEmpty) return "''";
    if (RegExp(r'''[:#\[\]{},&*!|>'"%@`]|^\s|\s$''').hasMatch(value)) {
      return "'${value.replaceAll("'", "''")}'";
    }
    return value;
  }
}
