import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';

class R2Service {
  R2Service({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<String> uploadBytes(
    AppSettings settings,
    Uint8List bytes, {
    String? filename,
  }) async {
    _validate(settings);
    final extension = p.extension(filename ?? '').toLowerCase();
    final key =
        'uploads/${DateTime.now().toUtc().toIso8601String().substring(0, 10)}/${const Uuid().v4()}$extension';
    final endpoint = Uri.https(
      '${settings.r2AccountId}.r2.cloudflarestorage.com',
      '/${settings.r2Bucket}/$key',
    );
    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = amzDate.substring(0, 8);
    final payloadHash = sha256.convert(bytes).toString();
    final contentType =
        lookupMimeType(filename ?? '') ?? 'application/octet-stream';
    final canonicalHeaders =
        'content-type:$contentType\nhost:${endpoint.host}\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
    final canonicalRequest = [
      'PUT',
      '/${endpoint.pathSegments.map(Uri.encodeComponent).join('/')}',
      '',
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
    final scope = '$dateStamp/auto/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)),
    ].join('\n');
    final signingKey = _signingKey(settings.r2SecretAccessKey, dateStamp);
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign));
    final authorization =
        'AWS4-HMAC-SHA256 Credential=${settings.r2AccessKeyId}/$scope, SignedHeaders=$signedHeaders, Signature=$signature';
    final response = await _client.put(
      endpoint,
      headers: {
        'content-type': contentType,
        'x-amz-content-sha256': payloadHash,
        'x-amz-date': amzDate,
        'authorization': authorization,
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_uploadError(response));
    }
    return '${settings.r2PublicBaseUrl.replaceAll(RegExp(r'/+$'), '')}/$key';
  }

  List<int> _signingKey(String secret, String date) {
    final dateKey = Hmac(
      sha256,
      utf8.encode('AWS4$secret'),
    ).convert(utf8.encode(date)).bytes;
    final regionKey = Hmac(sha256, dateKey).convert(utf8.encode('auto')).bytes;
    final serviceKey = Hmac(sha256, regionKey).convert(utf8.encode('s3')).bytes;
    return Hmac(sha256, serviceKey).convert(utf8.encode('aws4_request')).bytes;
  }

  String _amzDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}T${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}${date.second.toString().padLeft(2, '0')}Z';

  String _uploadError(http.Response response) {
    final code = _xmlValue(response.body, 'Code');
    final requestId = _xmlValue(response.body, 'RequestId');
    final detail = switch (code) {
      'AccessDenied' =>
        'R2 拒绝访问。请确认填写的是 R2 对象存储 API 令牌生成的 Access Key ID 和 Secret Access Key（不是 Cloudflare API Token），且令牌对当前 Bucket 拥有“对象读和写”权限。',
      'InvalidAccessKeyId' =>
        'Access Key ID 无效。请从 Cloudflare R2 的“管理 R2 API 令牌”页面重新复制 S3 凭据。',
      'SignatureDoesNotMatch' => '请求签名无效。请检查 Secret Access Key，并确认电脑的日期和时间准确。',
      'NoSuchBucket' => '找不到配置的 Bucket，请检查 Account ID 和 Bucket 名称。',
      _ => _xmlValue(response.body, 'Message') ?? 'R2 返回了未知错误。',
    };
    final requestSuffix = requestId == null ? '' : '（Request ID: $requestId）';
    return 'R2 上传失败 (${response.statusCode})：$detail$requestSuffix';
  }

  String? _xmlValue(String xml, String tag) {
    final match = RegExp(
      '<$tag>([^<]*)</$tag>',
      caseSensitive: false,
    ).firstMatch(xml);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  void _validate(AppSettings settings) {
    if (settings.r2AccountId.isEmpty ||
        settings.r2AccessKeyId.isEmpty ||
        settings.r2SecretAccessKey.isEmpty ||
        settings.r2Bucket.isEmpty ||
        settings.r2PublicBaseUrl.isEmpty) {
      throw Exception('请先完整填写 Cloudflare R2 配置与公开访问域名。');
    }
  }
}
