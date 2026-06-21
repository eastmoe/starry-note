import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:starry_note/models/app_settings.dart';
import 'package:starry_note/models/wordpress_import.dart';
import 'package:starry_note/services/html_markdown_converter.dart';
import 'package:starry_note/services/supabase_service.dart';
import 'package:starry_note/services/wordpress_import_service.dart';

void main() {
  final realExport = Platform.environment['WORDPRESS_WXR'] ?? '';

  test(
    'inspects a supplied real WordPress export',
    () async {
      final service = WordPressImportService();
      final preview = await service.inspect(File(realExport));
      expect(preview.posts, 79);
      expect(preview.pages, 3);
      expect(preview.privateItems, 5);
      expect(preview.attachments, 578);
      expect(preview.comments, 44);
      expect(preview.referencedMedia, greaterThan(400));
      expect(preview.skippedItems, 15);
      final root = await Directory.systemTemp.createTemp('starry-real-wxr-');
      addTearDown(() => root.delete(recursive: true));
      await Directory(
        '${root.path}${Platform.pathSeparator}public${Platform.pathSeparator}articles',
      ).create(recursive: true);
      final result = await service.execute(
        repositoryPath: root.path,
        settings: const AppSettings(),
        options: WordPressImportOptions(
          xmlPath: realExport,
          migrateMedia: false,
          importComments: false,
          privatePassword: 'test-only',
        ),
      );
      expect(result.articles, 79);
      expect(result.pages, 3);
      expect(result.privateItems, 5);
      final markdownFiles = Directory(
        '${root.path}${Platform.pathSeparator}public${Platform.pathSeparator}articles',
      ).listSync().whereType<File>().where((file) => file.path.endsWith('.md'));
      expect(markdownFiles, hasLength(82));
    },
    skip: realExport.isEmpty
        ? 'Set WORDPRESS_WXR to exercise a real export.'
        : false,
  );

  test('converts safe HTML and WordPress audio to Markdown', () {
    const converter = HtmlMarkdownConverter();
    final markdown = converter.convert('''
<h2>标题</h2><p>一段 <strong>粗体</strong> 和 <a href="https://example.com/a b">链接</a>。</p>
<table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table>
[audio mp3="https://east.moe/a.mp3"][/audio]
<script>alert(1)</script>
''');
    expect(markdown, contains('## 标题'));
    expect(markdown, contains('**粗体**'));
    expect(markdown, contains('[链接](https://example.com/a%20b)'));
    expect(markdown, contains('| A | B |'));
    expect(markdown, contains('<audio controls src="https://east.moe/a.mp3">'));
    expect(markdown, isNot(contains('alert')));
  });

  test(
      'previews and imports WXR with classifications, private pages and flat replies',
      () async {
    final root = await Directory.systemTemp.createTemp('starry-wxr-test-');
    addTearDown(() => root.delete(recursive: true));
    final articles = Directory(
      '${root.path}${Platform.pathSeparator}public${Platform.pathSeparator}articles',
    );
    await articles.create(recursive: true);
    final xml = File('${root.path}${Platform.pathSeparator}export.xml');
    await xml.writeAsString(_fixture);

    var storedComments = <Map<String, dynamic>>[];
    final supabase = SupabaseService(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(storedComments)),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final rows =
            (jsonDecode(request.body) as List).cast<Map<String, dynamic>>();
        storedComments = [...storedComments, ...rows];
        return http.Response('', 201);
      }),
    );
    final service = WordPressImportService(supabaseService: supabase);
    final preview = await service.inspect(xml);
    expect(preview.posts, 1);
    expect(preview.pages, 1);
    expect(preview.privateItems, 1);
    expect(preview.attachments, 1);
    expect(preview.referencedMedia, 1);
    expect(preview.comments, 2);
    expect(preview.skippedItems, 1);

    final result = await service.execute(
      repositoryPath: root.path,
      settings: const AppSettings(
        supabaseUrl: 'https://project.supabase.co',
        supabaseKey: 'service-role',
      ),
      options: WordPressImportOptions(
        xmlPath: xml.path,
        migrateMedia: false,
        privatePassword: 'secret',
      ),
    );
    expect(result.articles, 1);
    expect(result.pages, 1);
    expect(result.privateItems, 1);
    expect(result.commentsImported, 2);

    final postSlug = service.buildSlug(DateTime(2020, 1, 2, 3, 4), '测试文章', '1');
    final pageSlug = service.buildSlug(DateTime(2020, 2, 3), '关于页面', '2');
    final post =
        await File('${articles.path}${Platform.pathSeparator}$postSlug.md')
            .readAsString();
    final page =
        await File('${articles.path}${Platform.pathSeparator}$pageSlug.md')
            .readAsString();
    expect(post, contains('category: 技术'));
    expect(post, contains('tags: [数码]'));
    expect(post, contains('sourceId: 1'));
    expect(post, contains('## 小标题'));
    expect(post, contains('](/post/$pageSlug)'));
    expect(post, isNot(contains('<script>')));
    expect(page, contains('category: 页面'));
    expect(page, contains('tags: []'));
    expect(page, contains('page: true'));
    expect(page, contains('private: true'));
    expect(page, contains('password: secret'));
    expect(storedComments.last['content'], contains('回复 **Alice**'));
    expect(storedComments.last['content'], contains('> 第一条'));

    final second = await service.execute(
      repositoryPath: root.path,
      settings: const AppSettings(
        supabaseUrl: 'https://project.supabase.co',
        supabaseKey: 'service-role',
      ),
      options: WordPressImportOptions(
        xmlPath: xml.path,
        migrateMedia: false,
        privatePassword: '',
      ),
    );
    expect(second.articles, 0);
    expect(second.pages, 0);
    expect(second.commentsImported, 0);
    expect(
        articles
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.md')),
        hasLength(2));
  });

  test('can retain the original URL and continue when media returns 404',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    final base = 'http://${server.address.address}:${server.port}';
    final root = await Directory.systemTemp.createTemp('starry-wxr-404-');
    addTearDown(() => root.delete(recursive: true));
    final articles = Directory(
      '${root.path}${Platform.pathSeparator}public${Platform.pathSeparator}articles',
    );
    await articles.create(recursive: true);
    final xml = File('${root.path}${Platform.pathSeparator}export.xml');
    await xml.writeAsString(_fixture.replaceAll('https://east.moe', base));
    final service = WordPressImportService();

    final result = await service.execute(
      repositoryPath: root.path,
      settings: const AppSettings(),
      options: WordPressImportOptions(
        xmlPath: xml.path,
        sourceHost: server.address.address,
        migrateMedia: true,
        ignoreMissingMedia: true,
        importComments: false,
        privatePassword: 'secret',
      ),
    );
    expect(result.mediaMissing, 1);
    expect(result.mediaUploaded, 0);
    final imported = articles.listSync().whereType<File>().firstWhere(
          (file) => file.readAsStringSync().contains('sourceId: 1'),
        );
    expect(
      await imported.readAsString(),
      contains('$base/wp-content/uploads/pic.jpg'),
    );

    expect(
      () => service.execute(
        repositoryPath: root.path,
        settings: const AppSettings(),
        options: WordPressImportOptions(
          xmlPath: xml.path,
          sourceHost: server.address.address,
          migrateMedia: true,
          ignoreMissingMedia: false,
          importComments: false,
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });
}

const _fixture = '''<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0"
 xmlns:excerpt="http://wordpress.org/export/1.2/excerpt/"
 xmlns:content="http://purl.org/rss/1.0/modules/content/"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:wp="http://wordpress.org/export/1.2/">
<channel>
 <title>测试站</title><link>https://east.moe</link>
 <wp:category><wp:category_nicename>tech</wp:category_nicename><wp:category_parent></wp:category_parent><wp:cat_name>技术</wp:cat_name></wp:category>
 <wp:category><wp:category_nicename>digital</wp:category_nicename><wp:category_parent>tech</wp:category_parent><wp:cat_name>数码</wp:cat_name></wp:category>
 <item><title>图片</title><link>https://east.moe/media</link>
  <wp:post_id>10</wp:post_id><wp:post_type>attachment</wp:post_type><wp:status>inherit</wp:status>
  <wp:attachment_url>https://east.moe/wp-content/uploads/pic.jpg</wp:attachment_url>
 </item>
 <item><title>测试文章</title><link>https://east.moe/test/</link><dc:creator>星月</dc:creator>
  <content:encoded><![CDATA[<h2>小标题</h2><p>正文 <img src="https://east.moe/wp-content/uploads/pic.jpg"> <a href="https://east.moe/about/">关于</a></p><script>bad()</script>]]></content:encoded>
  <excerpt:encoded></excerpt:encoded><wp:post_id>1</wp:post_id><wp:post_date>2020-01-02 03:04:05</wp:post_date><wp:post_name>test</wp:post_name><wp:status>publish</wp:status><wp:post_type>post</wp:post_type>
  <category domain="category" nicename="digital">数码</category>
  <wp:postmeta><wp:meta_key>_thumbnail_id</wp:meta_key><wp:meta_value>10</wp:meta_value></wp:postmeta>
  <wp:comment><wp:comment_id>100</wp:comment_id><wp:comment_author>Alice</wp:comment_author><wp:comment_author_email>a@example.com</wp:comment_author_email><wp:comment_date_gmt>2020-01-03 00:00:00</wp:comment_date_gmt><wp:comment_content>第一条</wp:comment_content><wp:comment_approved>1</wp:comment_approved><wp:comment_type>comment</wp:comment_type><wp:comment_parent>0</wp:comment_parent></wp:comment>
  <wp:comment><wp:comment_id>101</wp:comment_id><wp:comment_author>Bob</wp:comment_author><wp:comment_author_email>b@example.com</wp:comment_author_email><wp:comment_date_gmt>2020-01-04 00:00:00</wp:comment_date_gmt><wp:comment_content>第二条</wp:comment_content><wp:comment_approved>1</wp:comment_approved><wp:comment_type>comment</wp:comment_type><wp:comment_parent>100</wp:comment_parent></wp:comment>
 </item>
 <item><title>关于页面</title><link>https://east.moe/about/</link><dc:creator>星月</dc:creator><content:encoded><![CDATA[<p>页面正文</p>]]></content:encoded><excerpt:encoded></excerpt:encoded><wp:post_id>2</wp:post_id><wp:post_date>2020-02-03 00:00:00</wp:post_date><wp:post_name>about</wp:post_name><wp:status>private</wp:status><wp:post_type>page</wp:post_type></item>
 <item><title>菜单</title><wp:post_id>3</wp:post_id><wp:status>publish</wp:status><wp:post_type>nav_menu_item</wp:post_type></item>
</channel></rss>''';
