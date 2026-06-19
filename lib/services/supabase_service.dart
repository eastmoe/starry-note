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

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Supabase 请求失败 (${response.statusCode})：${response.body}',
      );
    }
  }
}
