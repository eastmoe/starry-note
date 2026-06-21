import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_settings.dart';
import '../models/comment.dart';

class SupabaseService {
  SupabaseService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<BlogComment>> listComments(AppSettings settings) async {
    final response = await _client.get(
      _uri(settings, '/rest/v1/comments', {
        'select': 'id,slug,nickname,email,content,created_at',
        'order': 'created_at.desc',
      }),
      headers: _headers(settings),
    );
    _check(response);
    return (jsonDecode(response.body) as List)
        .map((item) => BlogComment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteComment(AppSettings settings, String id) async {
    final response = await _client.delete(
      _uri(settings, '/rest/v1/comments', {'id': 'eq.$id'}),
      headers: _headers(settings),
    );
    _check(response);
  }

  Future<int> importComments(
    AppSettings settings,
    List<Map<String, dynamic>> comments,
  ) async {
    if (comments.isEmpty) return 0;
    final slugs = comments.map((item) => '${item['slug']}').toSet().toList();
    final existingResponse = await _client.get(
      _uri(settings, '/rest/v1/comments', {
        'select': 'slug,nickname,email,content,created_at',
        'slug': 'in.(${slugs.map(_postgrestValue).join(',')})',
      }),
      headers: _headers(settings),
    );
    _check(existingResponse);
    final existing = (jsonDecode(existingResponse.body) as List)
        .map((item) => _commentSignature(item as Map<String, dynamic>))
        .toSet();
    final pending = comments
        .where((item) => !existing.contains(_commentSignature(item)))
        .toList();
    var imported = 0;
    for (var offset = 0; offset < pending.length; offset += 100) {
      final end = (offset + 100).clamp(0, pending.length);
      final response = await _client.post(
        _uri(settings, '/rest/v1/comments', const {}),
        headers: {
          ..._headers(settings),
          'prefer': 'return=minimal',
        },
        body: jsonEncode(pending.sublist(offset, end)),
      );
      _check(response);
      imported += end - offset;
    }
    return imported;
  }

  Uri _uri(AppSettings settings, String path, Map<String, String> query) {
    if (settings.supabaseUrl.isEmpty || settings.supabaseKey.isEmpty) {
      throw Exception('请先填写 Supabase URL 与管理 API Key。');
    }
    final base = Uri.parse(settings.supabaseUrl);
    return base.replace(
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}$path',
      queryParameters: query,
    );
  }

  Map<String, String> _headers(AppSettings settings) => {
        'apikey': settings.supabaseKey,
        'authorization': 'Bearer ${settings.supabaseKey}',
        'content-type': 'application/json',
      };

  String _postgrestValue(String value) =>
      '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  String _commentSignature(Map<String, dynamic> value) => [
        value['slug'] ?? '',
        value['nickname'] ?? '',
        value['email'] ?? '',
        value['content'] ?? '',
        DateTime.tryParse('${value['created_at']}')
                ?.toUtc()
                .toIso8601String() ??
            '${value['created_at'] ?? ''}',
      ].join('\u001f');

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Supabase 请求失败 (${response.statusCode})：${response.body}',
      );
    }
  }
}
