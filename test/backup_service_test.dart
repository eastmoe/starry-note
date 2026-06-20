import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:starry_note/models/app_settings.dart';
import 'package:starry_note/services/backup_service.dart';

void main() {
  test('discovers tables and exports escaped data SQL', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/rest/v1/')) {
        return http.Response('''{
          "paths": {"/comments": {"get": {}}},
          "definitions": {"comments": {"properties": {
            "id": {"type": "integer"}, "content": {"type": "string"},
            "meta": {"type": "object"}
          }}}
        }''', 200);
      }
      expect(request.url.path, endsWith('/rest/v1/comments'));
      return http.Response(
        '''[{"id":1,"content":"Starry's note","meta":{"ok":true}}]''',
        200,
      );
    });
    final directory = await Directory.systemTemp.createTemp('starry-backup');
    addTearDown(() => directory.delete(recursive: true));
    final output = '${directory.path}${Platform.pathSeparator}backup.sql';
    final service = BackupService(client: client);

    final result = await service.export(
      settings: const AppSettings(
        supabaseUrl: 'https://example.supabase.co',
        supabaseKey: 'service-role',
      ),
      outputPath: output,
    );

    expect(result.tableCount, 1);
    expect(result.rowCount, 1);
    final sql = await File(output).readAsString();
    expect(sql, contains('INSERT INTO public."comments"'));
    expect(sql, contains("'Starry''s note'"));
    expect(sql, contains("'{\"ok\":true}'::jsonb"));
    expect(sql, endsWith('COMMIT;\n'));
  });
}
