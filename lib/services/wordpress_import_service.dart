import 'dart:convert';
import 'dart:io';

import 'package:pinyin/pinyin.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/app_settings.dart';
import '../models/article.dart';
import '../models/wordpress_import.dart';
import 'article_service.dart';
import 'html_markdown_converter.dart';
import 'r2_service.dart';
import 'supabase_service.dart';
import 'wordpress_media_downloader.dart';

typedef WordPressImportProgressCallback = void Function(
  WordPressImportProgress progress,
);

class WordPressImportService {
  WordPressImportService({
    ArticleService? articleService,
    R2Service? r2Service,
    SupabaseService? supabaseService,
    HtmlMarkdownConverter? converter,
  })  : articleService = articleService ?? ArticleService(),
        r2Service = r2Service ?? R2Service(),
        supabaseService = supabaseService ?? SupabaseService(),
        converter = converter ?? const HtmlMarkdownConverter();

  final ArticleService articleService;
  final R2Service r2Service;
  final SupabaseService supabaseService;
  final HtmlMarkdownConverter converter;

  Future<WordPressImportPreview> inspect(File file) async {
    final archive = await _read(file);
    final sourceHost = Uri.tryParse(archive.sourceUrl)?.host ?? '';
    final accepted = archive.items.where(_isImportable).toList();
    final media = _collectMediaUrls(archive, sourceHost);
    final warnings = <String>[];
    if (accepted.any((item) => item.status == 'private')) {
      warnings.add('私密内容没有可迁移密码，正式导入前必须设置统一密码。');
    }
    if (accepted.any((item) => _topLevelCategoryCount(item, archive) > 1)) {
      warnings.add('部分文章属于多个一级分类，将按 WordPress 中的排列顺序选择主分类。');
    }
    if (accepted.any((item) => item.content.contains('[audio'))) {
      warnings.add('音频短代码将转换为安全的 audio 元素。');
    }
    return WordPressImportPreview(
      siteTitle: archive.siteTitle,
      sourceUrl: archive.sourceUrl,
      sourceHost: sourceHost,
      posts: accepted.where((item) => item.type == 'post').length,
      pages: accepted.where((item) => item.type == 'page').length,
      privateItems: accepted.where((item) => item.status == 'private').length,
      attachments: archive.attachmentsById.length,
      referencedMedia: media.length,
      comments: accepted
          .expand((item) => item.comments)
          .where((comment) => comment.approved && comment.type == 'comment')
          .length,
      skippedItems: archive.items
          .where((item) => !_isImportable(item) && item.type != 'attachment')
          .length,
      warnings: warnings,
    );
  }

  Future<WordPressImportResult> execute({
    required String repositoryPath,
    required AppSettings settings,
    required WordPressImportOptions options,
    WordPressImportProgressCallback? onProgress,
  }) async {
    final archive = await _read(File(options.xmlPath));
    final items = archive.items.where(_isImportable).toList();
    final sourceHost = (options.sourceHost.isEmpty
            ? Uri.tryParse(archive.sourceUrl)?.host
            : options.sourceHost)
        ?.trim()
        .toLowerCase();
    if (options.migrateMedia && (sourceHost == null || sourceHost.isEmpty)) {
      throw Exception('无法从导出文件识别源主机，请手动填写媒体源主机名。');
    }

    final slugAssignment = _assignSlugs(repositoryPath, items);
    final slugs = slugAssignment.$1;
    final existingIds = slugAssignment.$2;
    final pendingItems =
        items.where((item) => !existingIds.contains(item.id)).toList();
    final privateCount =
        pendingItems.where((item) => item.status == 'private').length;
    if (privateCount > 0 && options.privatePassword.isEmpty) {
      throw Exception('导出文件包含尚未导入的私密内容，请先设置统一访问密码。');
    }
    final internalLinks = <String, String>{};
    for (final item in items) {
      final target = '/post/${slugs[item.id]}';
      if (item.link.isNotEmpty) internalLinks[item.link] = target;
      if (archive.sourceUrl.isNotEmpty && item.postName.isNotEmpty) {
        internalLinks[
                '${archive.sourceUrl.replaceAll(RegExp(r'/+$'), '')}/${item.postName}/'] =
            target;
      }
    }

    final mediaUrls = options.migrateMedia
        ? _collectMediaUrls(archive, sourceHost!)
        : <String>{};
    final mediaResult = options.migrateMedia
        ? await _migrateMedia(
            repositoryPath: repositoryPath,
            settings: settings,
            options: options.copyWith(sourceHost: sourceHost),
            urls: mediaUrls,
            onProgress: onProgress,
          )
        : const _MediaMigrationResult({}, 0, 0, 0);

    final articlesDirectory = articleService.articlesDirectory(repositoryPath);
    await articlesDirectory.create(recursive: true);
    final staging =
        await Directory.systemTemp.createTemp('starry-wordpress-articles-');
    final promoted = <File>[];
    final total = pendingItems.length + (options.importComments ? 1 : 0);
    var completed = 0;
    final commentRows = <Map<String, dynamic>>[];
    var commentsImported = 0;
    try {
      for (final item in items) {
        if (existingIds.contains(item.id)) {
          if (options.importComments && item.type == 'post') {
            commentRows.addAll(
              _commentsFor(item, slugs[item.id]!, mediaResult.urls),
            );
          }
          continue;
        }
        var content = _replaceUrls(item.content, mediaResult.urls);
        content = _replaceUrls(content, internalLinks);
        final markdown = converter.convert(content);
        final classification = item.type == 'page'
            ? (
                options.pageCategory.trim().isEmpty
                    ? '页面'
                    : options.pageCategory.trim(),
                <String>[]
              )
            : _classify(item, archive);
        final coverSource = archive.attachmentsById[item.thumbnailId] ?? '';
        final cover = mediaResult.urls[coverSource] ?? coverSource;
        final article = Article(
          slug: slugs[item.id]!,
          title: item.title,
          date: item.date,
          category: classification.$1,
          author: item.author,
          cover: cover,
          excerpt: item.excerpt.isNotEmpty ? item.excerpt : _excerpt(markdown),
          tags: classification.$2,
          body: markdown,
          page: item.type == 'page',
          isPrivate: item.status == 'private',
          password: item.status == 'private' ? options.privatePassword : '',
          noindex: item.status == 'private',
          source: 'wordpress',
          sourceId: item.id,
          sourceUrl: item.link,
        );
        final staged = File(p.join(staging.path, '${article.slug}.md'));
        await staged.writeAsString(article.toMarkdown());
        if (options.importComments && item.type == 'post') {
          commentRows
              .addAll(_commentsFor(item, article.slug, mediaResult.urls));
        }
        completed++;
        onProgress?.call(WordPressImportProgress(
          completed,
          total,
          '转换 ${article.title}',
        ));
      }
      for (final entity in staging.listSync().whereType<File>()) {
        final target =
            File(p.join(articlesDirectory.path, p.basename(entity.path)));
        if (await target.exists()) throw Exception('导入目标已存在：${target.path}');
        await entity.copy(target.path);
        promoted.add(target);
      }
      await articleService.rebuildIndex(repositoryPath);
      if (options.importComments && commentRows.isNotEmpty) {
        commentsImported =
            await supabaseService.importComments(settings, commentRows);
        completed++;
        onProgress?.call(WordPressImportProgress(completed, total, '评论迁移完成'));
      }
    } catch (_) {
      for (final file in promoted.reversed) {
        if (await file.exists()) await file.delete();
      }
      await articleService.rebuildIndex(repositoryPath);
      rethrow;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
    return WordPressImportResult(
      articles: pendingItems.where((item) => item.type == 'post').length,
      pages: pendingItems.where((item) => item.type == 'page').length,
      privateItems: privateCount,
      mediaUploaded: mediaResult.uploaded,
      mediaReused: mediaResult.reused,
      mediaMissing: mediaResult.missing,
      commentsImported: commentsImported,
      commentsSkipped: commentRows.length - commentsImported,
      skippedItems: existingIds.length +
          archive.items
              .where(
                  (item) => !_isImportable(item) && item.type != 'attachment')
              .length,
    );
  }

  String buildSlug(DateTime date, String title, String postId) {
    final datePart = '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    var converted = PinyinHelper.getPinyinE(
      title,
      separator: '-',
      defPinyin: '-',
      format: PinyinFormat.WITHOUT_TONE,
    ).toLowerCase();
    converted = converted
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (converted.length > 80) {
      converted = converted.substring(0, 80).replaceFirst(RegExp(r'-+$'), '');
    }
    return converted.isEmpty
        ? '$datePart-post-$postId'
        : '$datePart-$converted';
  }

  (Map<String, String>, Set<String>) _assignSlugs(
    String repositoryPath,
    List<_WpItem> items,
  ) {
    final used = <String>{};
    final existingBySourceId = <String, String>{};
    final root = articleService.articlesDirectory(repositoryPath);
    if (root.existsSync()) {
      for (final file in root
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.md'))) {
        final slug = p.basenameWithoutExtension(file.path);
        used.add(slug.toLowerCase());
        final article = articleService.parse(file.readAsStringSync());
        if (article.source == 'wordpress' && article.sourceId.isNotEmpty) {
          existingBySourceId[article.sourceId] = slug;
        }
      }
    }
    final result = <String, String>{};
    for (final item in items) {
      final existing = existingBySourceId[item.id];
      if (existing != null) {
        result[item.id] = existing;
        continue;
      }
      var slug = buildSlug(item.date, item.title, item.id);
      if (used.contains(slug.toLowerCase())) slug = '$slug-${item.id}';
      while (used.contains(slug.toLowerCase())) {
        slug = '$slug-imported';
      }
      used.add(slug.toLowerCase());
      result[item.id] = slug;
    }
    return (result, existingBySourceId.keys.toSet());
  }

  Future<_MediaMigrationResult> _migrateMedia({
    required String repositoryPath,
    required AppSettings settings,
    required WordPressImportOptions options,
    required Set<String> urls,
    WordPressImportProgressCallback? onProgress,
  }) async {
    if (urls.isEmpty) return const _MediaMigrationResult({}, 0, 0, 0);
    final manifest = await _MediaManifest.load(repositoryPath);
    final downloader = WordPressMediaDownloader(
      sourceHost: options.sourceHost,
      sourceIp: options.sourceIp,
      skipSslVerification: options.skipSslVerification,
    );
    final temp =
        await Directory.systemTemp.createTemp('starry-wordpress-import-');
    var uploaded = 0;
    var reused = 0;
    var missing = 0;
    var completed = 0;
    try {
      for (final url in urls) {
        final known = manifest.urls[url];
        if (known != null && known.isNotEmpty) {
          reused++;
          completed++;
          onProgress?.call(
              WordPressImportProgress(completed, urls.length, '复用媒体 $url'));
          continue;
        }
        final source = Uri.tryParse(url);
        if (source == null) throw Exception('无效媒体 URL：$url');
        onProgress?.call(
            WordPressImportProgress(completed, urls.length, '下载媒体 $url'));
        late DownloadedWordPressMedia downloaded;
        try {
          downloaded = await downloader.download(source, temp);
        } on WordPressMediaDownloadException catch (error) {
          if (error.statusCode != 404 || !options.ignoreMissingMedia) rethrow;
          missing++;
          completed++;
          onProgress?.call(
            WordPressImportProgress(
              completed,
              urls.length,
              '媒体不存在，已保留原 URL：$url',
            ),
          );
          continue;
        }
        var publicUrl = manifest.hashes[downloaded.sha256];
        if (publicUrl == null) {
          final key = 'wordpress/${downloaded.sha256.substring(0, 2)}/'
              '${downloaded.sha256}${downloaded.extension}';
          if (await r2Service.objectExists(settings, key)) {
            publicUrl =
                '${settings.r2PublicBaseUrl.replaceAll(RegExp(r'/+$'), '')}/$key';
            reused++;
          } else {
            publicUrl = await r2Service.uploadFile(
              settings,
              downloaded.file,
              key: key,
              payloadHash: downloaded.sha256,
              contentType: downloaded.contentType,
            );
            uploaded++;
          }
          manifest.hashes[downloaded.sha256] = publicUrl;
        } else {
          reused++;
        }
        manifest.urls[url] = publicUrl;
        await manifest.save(repositoryPath);
        completed++;
        onProgress?.call(
            WordPressImportProgress(completed, urls.length, '媒体迁移完成 $url'));
      }
    } finally {
      downloader.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    }
    return _MediaMigrationResult(
      Map.unmodifiable(manifest.urls),
      uploaded,
      reused,
      missing,
    );
  }

  Set<String> _collectMediaUrls(_WordPressArchive archive, String sourceHost) {
    if (sourceHost.isEmpty) return <String>{};
    final urls = <String>{};
    for (final item in archive.items.where(_isImportable)) {
      for (final match
          in RegExp(r'''https?://[^\s"'<>\]]+''', caseSensitive: false)
              .allMatches(item.content)) {
        final value = match
            .group(0)!
            .replaceAll('&amp;', '&')
            .replaceAll(RegExp(r'[),.;]+$'), '');
        final uri = Uri.tryParse(value);
        if (uri != null &&
            _sameHost(uri.host, sourceHost) &&
            uri.path.contains('/wp-content/uploads/')) {
          urls.add(value);
        }
      }
      final featured = archive.attachmentsById[item.thumbnailId];
      if (featured != null && featured.isNotEmpty) urls.add(featured);
    }
    return urls;
  }

  (String, List<String>) _classify(_WpItem item, _WordPressArchive archive) {
    if (item.categories.isEmpty) return ('未分类', <String>[]);
    final roots = <String>[];
    final childTags = <String>[];
    for (final slug in item.categories) {
      final term = archive.terms[slug];
      if (term == null) continue;
      var root = term;
      final visited = <String>{slug};
      while (root.parent.isNotEmpty && !visited.contains(root.parent)) {
        visited.add(root.parent);
        final parent = archive.terms[root.parent];
        if (parent == null) break;
        if (root.name.isNotEmpty) childTags.add(root.name);
        root = parent;
      }
      if (root.name.isNotEmpty) roots.add(root.name);
    }
    final category = roots.isEmpty ? '未分类' : roots.first;
    final tags = childTags.where((tag) => tag != category).toSet().toList();
    return (category, tags);
  }

  int _topLevelCategoryCount(_WpItem item, _WordPressArchive archive) =>
      item.categories
          .map((slug) {
            var current = archive.terms[slug];
            final visited = <String>{};
            while (current != null &&
                current.parent.isNotEmpty &&
                visited.add(current.slug)) {
              current = archive.terms[current.parent] ?? current;
              if (visited.contains(current.slug)) break;
            }
            return current?.slug ?? '';
          })
          .where((value) => value.isNotEmpty)
          .toSet()
          .length;

  List<Map<String, dynamic>> _commentsFor(
    _WpItem item,
    String slug,
    Map<String, String> media,
  ) {
    final accepted = item.comments
        .where((comment) => comment.approved && comment.type == 'comment')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final byId = {for (final comment in accepted) comment.id: comment};
    final converted = <String, String>{};
    final rows = <Map<String, dynamic>>[];
    for (final comment in accepted) {
      var body = converter.convert(_replaceUrls(comment.content, media));
      final parent = byId[comment.parentId];
      if (parent != null) {
        final parentBody =
            converted[parent.id] ?? converter.convert(parent.content);
        final quote = parentBody
            .split('\n')
            .map((line) => '> ${line.trimRight()}')
            .join('\n');
        body = '回复 **${_escapeMarkdown(parent.author)}**：\n\n$quote\n\n$body';
      }
      if (body.length > 2000) {
        body = '${body.substring(0, 1999)}…';
      }
      converted[comment.id] = body;
      rows.add({
        'slug': slug,
        'nickname': comment.author.length > 32
            ? comment.author.substring(0, 32)
            : comment.author,
        'email': comment.email.isEmpty ? null : comment.email,
        'content': body,
        'created_at': comment.date.toUtc().toIso8601String(),
      });
    }
    return rows;
  }

  String _excerpt(String markdown) {
    final value = markdown
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'[#>*_~`|\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value.length <= 160 ? value : '${value.substring(0, 159)}…';
  }

  String _replaceUrls(String source, Map<String, String> replacements) {
    var value = source;
    final keys = replacements.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      value = value.replaceAll(key, replacements[key]!);
      value =
          value.replaceAll(key.replaceAll('&', '&amp;'), replacements[key]!);
    }
    return value;
  }

  Future<_WordPressArchive> _read(File file) async {
    if (!await file.exists()) {
      throw Exception('找不到 WordPress 导出文件：${file.path}');
    }
    final document = XmlDocument.parse(await file.readAsString());
    final channel = document.findAllElements('channel').first;
    final siteTitle = _plainText(channel, 'title');
    final sourceUrl = _plainText(channel, 'link');
    final terms = <String, _WpTerm>{};
    for (final node
        in channel.findElements('category', namespaceUri: _wpNamespace)) {
      final slug = _text(node, 'category_nicename', _wpNamespace);
      if (slug.isEmpty) continue;
      terms[slug] = _WpTerm(
        slug,
        _text(node, 'cat_name', _wpNamespace),
        _text(node, 'category_parent', _wpNamespace),
      );
    }
    final items = <_WpItem>[];
    final attachments = <String, String>{};
    for (final node in channel.findElements('item')) {
      final type = _text(node, 'post_type', _wpNamespace);
      final id = _text(node, 'post_id', _wpNamespace);
      final meta = <String, String>{};
      for (final postMeta
          in node.findElements('postmeta', namespaceUri: _wpNamespace)) {
        meta[_text(postMeta, 'meta_key', _wpNamespace)] =
            _text(postMeta, 'meta_value', _wpNamespace);
      }
      if (type == 'attachment') {
        attachments[id] = _text(node, 'attachment_url', _wpNamespace);
      }
      final categories = node
          .findElements('category')
          .where((category) => category.getAttribute('domain') == 'category')
          .map((category) =>
              category.getAttribute('nicename') ?? category.innerText)
          .where((value) => value.isNotEmpty)
          .toList();
      final comments = <_WpComment>[];
      for (final comment
          in node.findElements('comment', namespaceUri: _wpNamespace)) {
        final gmt = _text(comment, 'comment_date_gmt', _wpNamespace);
        final local = _text(comment, 'comment_date', _wpNamespace);
        comments.add(_WpComment(
          id: _text(comment, 'comment_id', _wpNamespace),
          parentId: _text(comment, 'comment_parent', _wpNamespace),
          author: _text(comment, 'comment_author', _wpNamespace),
          email: _text(comment, 'comment_author_email', _wpNamespace),
          content: _text(comment, 'comment_content', _wpNamespace),
          date: _parseDate(gmt.isEmpty ? local : '${gmt}Z'),
          approved: _text(comment, 'comment_approved', _wpNamespace) == '1',
          type: _text(comment, 'comment_type', _wpNamespace),
        ));
      }
      items.add(_WpItem(
        id: id,
        type: type,
        status: _text(node, 'status', _wpNamespace),
        title: _plainText(node, 'title'),
        postName: _text(node, 'post_name', _wpNamespace),
        link: _plainText(node, 'link'),
        author: _text(node, 'creator', _dcNamespace),
        date: _parseDate(_text(node, 'post_date', _wpNamespace)),
        content: _text(node, 'encoded', _contentNamespace),
        excerpt: _text(node, 'encoded', _excerptNamespace),
        categories: categories,
        thumbnailId: meta['_thumbnail_id'] ?? '',
        comments: comments,
      ));
    }
    return _WordPressArchive(
      siteTitle: siteTitle,
      sourceUrl: sourceUrl,
      items: items,
      terms: terms,
      attachmentsById: attachments,
    );
  }

  bool _isImportable(_WpItem item) =>
      (item.type == 'post' || item.type == 'page') &&
      (item.status == 'publish' || item.status == 'private');

  static DateTime _parseDate(String value) =>
      DateTime.tryParse(value) ?? DateTime(1970);

  static bool _sameHost(String left, String right) {
    String normalize(String value) =>
        value.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    return normalize(left) == normalize(right);
  }

  static String _escapeMarkdown(String value) =>
      value.replaceAll(RegExp(r'([\\`*_{}\[\]()#+.!|>\-])'), r'\$1');

  static String _text(XmlElement parent, String localName, String namespace) =>
      parent
          .findElements(localName, namespaceUri: namespace)
          .firstOrNull
          ?.innerText
          .trim() ??
      '';

  static String _plainText(XmlElement parent, String localName) =>
      parent.findElements(localName).firstOrNull?.innerText.trim() ?? '';
}

const _wpNamespace = 'http://wordpress.org/export/1.2/';
const _contentNamespace = 'http://purl.org/rss/1.0/modules/content/';
const _excerptNamespace = 'http://wordpress.org/export/1.2/excerpt/';
const _dcNamespace = 'http://purl.org/dc/elements/1.1/';

class _WordPressArchive {
  const _WordPressArchive({
    required this.siteTitle,
    required this.sourceUrl,
    required this.items,
    required this.terms,
    required this.attachmentsById,
  });
  final String siteTitle;
  final String sourceUrl;
  final List<_WpItem> items;
  final Map<String, _WpTerm> terms;
  final Map<String, String> attachmentsById;
}

class _WpItem {
  const _WpItem({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.postName,
    required this.link,
    required this.author,
    required this.date,
    required this.content,
    required this.excerpt,
    required this.categories,
    required this.thumbnailId,
    required this.comments,
  });
  final String id;
  final String type;
  final String status;
  final String title;
  final String postName;
  final String link;
  final String author;
  final DateTime date;
  final String content;
  final String excerpt;
  final List<String> categories;
  final String thumbnailId;
  final List<_WpComment> comments;
}

class _WpComment {
  const _WpComment({
    required this.id,
    required this.parentId,
    required this.author,
    required this.email,
    required this.content,
    required this.date,
    required this.approved,
    required this.type,
  });
  final String id;
  final String parentId;
  final String author;
  final String email;
  final String content;
  final DateTime date;
  final bool approved;
  final String type;
}

class _WpTerm {
  const _WpTerm(this.slug, this.name, this.parent);
  final String slug;
  final String name;
  final String parent;
}

class _MediaMigrationResult {
  const _MediaMigrationResult(
    this.urls,
    this.uploaded,
    this.reused,
    this.missing,
  );
  final Map<String, String> urls;
  final int uploaded;
  final int reused;
  final int missing;
}

class _MediaManifest {
  _MediaManifest(this.urls, this.hashes);
  final Map<String, String> urls;
  final Map<String, String> hashes;

  static File _file(String repositoryPath) =>
      File(p.join(repositoryPath, '.starrynote', 'wordpress-media.json'));

  static Future<_MediaManifest> load(String repositoryPath) async {
    final file = _file(repositoryPath);
    if (!await file.exists()) return _MediaManifest({}, {});
    try {
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      Map<String, String> map(String key) => (data[key] as Map? ?? const {})
          .map((key, value) => MapEntry('$key', '$value'));
      return _MediaManifest(map('urls'), map('hashes'));
    } catch (_) {
      throw Exception('媒体导入清单损坏：${file.path}');
    }
  }

  Future<void> save(String repositoryPath) async {
    final file = _file(repositoryPath);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({
            'urls': urls,
            'hashes': hashes
          })}\n',
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
