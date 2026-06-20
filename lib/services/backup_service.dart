import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/app_settings.dart';

class SupabaseTableInfo {
  const SupabaseTableInfo({required this.name, required this.properties});
  final String name;
  final Map<String, dynamic> properties;
}

class BackupResult {
  const BackupResult({
    required this.path,
    required this.tableCount,
    required this.rowCount,
  });
  final String path;
  final int tableCount;
  final int rowCount;
}

class BackupService {
  BackupService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<SupabaseTableInfo>> listTables(AppSettings settings) async {
    final response = await _client.get(
      _uri(settings, '/rest/v1/'),
      headers: {
        ..._headers(settings),
        'accept': 'application/openapi+json',
      },
    );
    _check(response);
    final document = jsonDecode(response.body) as Map<String, dynamic>;
    final definitions =
        (document['definitions'] as Map?)?.cast<String, dynamic>() ?? const {};
    final paths =
        (document['paths'] as Map?)?.cast<String, dynamic>() ?? const {};
    final names = paths.entries
        .where((entry) =>
            entry.key.startsWith('/') &&
            !entry.key.substring(1).contains('/') &&
            entry.value is Map &&
            (entry.value as Map).containsKey('get'))
        .map((entry) => Uri.decodeComponent(entry.key.substring(1)))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return names
        .map(
          (name) => SupabaseTableInfo(
            name: name,
            properties: ((definitions[name] as Map?)?['properties'] as Map?)
                    ?.cast<String, dynamic>() ??
                const {},
          ),
        )
        .toList();
  }

  Future<BackupResult> export({
    required AppSettings settings,
    required String outputPath,
    List<String> tables = const [],
  }) async {
    final available = await listTables(settings);
    final selected = tables.isEmpty
        ? available
        : available.where((table) => tables.contains(table.name)).toList();
    if (selected.isEmpty) throw Exception('没有找到可备份的数据表。');

    final sink = StringBuffer()
      ..writeln('-- StarryNote Supabase data backup')
      ..writeln('-- Created at ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('-- Data-only backup: restore into an existing schema.')
      ..writeln('BEGIN;')
      ..writeln();
    var rowCount = 0;
    for (final table in selected) {
      final rows = await _readAllRows(settings, table.name);
      rowCount += rows.length;
      sink.writeln('-- ${table.name}: ${rows.length} rows');
      for (final row in rows) {
        if (row.isEmpty) continue;
        final columns = row.keys.map(_identifier).join(', ');
        final values = row.entries
            .map((entry) => _literal(entry.value, table.properties[entry.key]))
            .join(', ');
        sink.writeln(
          'INSERT INTO public.${_identifier(table.name)} ($columns) VALUES ($values);',
        );
      }
      sink.writeln();
    }
    sink.writeln('COMMIT;');

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(sink.toString(), flush: true);
    return BackupResult(
      path: file.path,
      tableCount: selected.length,
      rowCount: rowCount,
    );
  }

  String automaticPath(String directory) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return p.join(directory, 'supabase-$stamp.sql');
  }

  Future<List<Map<String, dynamic>>> _readAllRows(
    AppSettings settings,
    String table,
  ) async {
    const pageSize = 1000;
    final result = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += pageSize) {
      final response = await _client.get(
        _uri(settings, '/rest/v1/${Uri.encodeComponent(table)}', {
          'select': '*',
          'limit': '$pageSize',
          'offset': '$offset',
        }),
        headers: _headers(settings),
      );
      _check(response);
      final page = (jsonDecode(response.body) as List)
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();
      result.addAll(page);
      if (page.length < pageSize) return result;
    }
  }

  Uri _uri(
    AppSettings settings,
    String path, [
    Map<String, String>? query,
  ]) {
    if (settings.supabaseUrl.isEmpty || settings.supabaseKey.isEmpty) {
      throw Exception('请先在“连接”中填写 Supabase URL 与管理 API Key。');
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
        'Supabase 备份请求失败 (${response.statusCode})：${response.body}',
      );
    }
  }

  String _identifier(String value) => '"${value.replaceAll('"', '""')}"';

  String _literal(dynamic value, dynamic property) {
    if (value == null) return 'NULL';
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    if (value is num) return value.toString();
    if (value is Map || value is List) {
      return '${_stringLiteral(jsonEncode(value))}::jsonb';
    }
    final type = property is Map ? property['type'] : null;
    if (type == 'object') return '${_stringLiteral('$value')}::jsonb';
    return _stringLiteral('$value');
  }

  String _stringLiteral(String value) => "'${value.replaceAll("'", "''")}'";
}
