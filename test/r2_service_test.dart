import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:starry_note/models/app_settings.dart';
import 'package:starry_note/services/r2_service.dart';

const _settings = AppSettings(
  r2AccountId: 'account-id',
  r2AccessKeyId: 'access-key',
  r2SecretAccessKey: 'secret-key',
  r2Bucket: 'images',
  r2PublicBaseUrl: 'https://assets.example.com/',
);

void main() {
  test('uploads bytes to the configured R2 bucket with SigV4 headers',
      () async {
    late http.Request captured;
    final service = R2Service(
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      }),
    );

    final url = await service.uploadBytes(
      _settings,
      Uint8List.fromList(utf8.encode('image')),
      filename: 'photo.png',
    );

    expect(captured.method, 'PUT');
    expect(captured.url.host, 'account-id.r2.cloudflarestorage.com');
    expect(captured.url.path, startsWith('/images/uploads/'));
    expect(captured.url.path, endsWith('.png'));
    expect(captured.headers['authorization'], startsWith('AWS4-HMAC-SHA256 '));
    expect(captured.headers['x-amz-content-sha256'], isNotEmpty);
    expect(url, startsWith('https://assets.example.com/uploads/'));
  });

  test('turns the R2 AccessDenied XML into actionable guidance', () async {
    final service = R2Service(
      client: MockClient(
        (_) async => http.Response(
          '<?xml version="1.0"?><Error><Code>AccessDenied</Code>'
          '<Message>Access Denied</Message><RequestId>abc123</RequestId></Error>',
          403,
        ),
      ),
    );

    expect(
      () => service.uploadBytes(_settings, Uint8List(1)),
      throwsA(
        isA<Exception>()
            .having((error) => error.toString(), 'message', contains('R2 拒绝访问'))
            .having((error) => error.toString(), 'message',
                contains('不是 Cloudflare API Token'))
            .having((error) => error.toString(), 'message', contains('abc123'))
            .having((error) => error.toString(), 'message',
                isNot(contains('<?xml'))),
      ),
    );
  });
}
