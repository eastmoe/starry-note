import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class WordPressMediaDownloadException implements Exception {
  const WordPressMediaDownloadException({
    required this.url,
    required this.statusCode,
  });

  final Uri url;
  final int statusCode;

  @override
  String toString() => '下载媒体失败 ($statusCode)：$url';
}

class DownloadedWordPressMedia {
  const DownloadedWordPressMedia({
    required this.file,
    required this.sha256,
    required this.extension,
    required this.contentType,
  });

  final File file;
  final String sha256;
  final String extension;
  final String? contentType;
}

class WordPressMediaDownloader {
  WordPressMediaDownloader({
    required String sourceHost,
    String sourceIp = '',
    bool skipSslVerification = false,
    HttpClient? client,
  })  : sourceHost = _normalizeHost(sourceHost),
        _client = client ?? HttpClient() {
    _client.findProxy = (_) => 'DIRECT';
    if (sourceIp.trim().isNotEmpty) {
      final address = sourceIp.trim();
      _client.connectionFactory = (uri, proxyHost, proxyPort) {
        if (!_isAllowedHost(uri.host)) {
          throw const SocketException('重定向到了未允许的主机');
        }
        return Socket.startConnect(address, uri.port);
      };
    }
    if (skipSslVerification) {
      _client.badCertificateCallback =
          (certificate, host, port) => _isAllowedHost(host);
    }
  }

  final String sourceHost;
  final HttpClient _client;

  Future<DownloadedWordPressMedia> download(
    Uri source,
    Directory temporaryDirectory,
  ) async {
    if (!_isAllowedHost(source.host)) {
      throw Exception('拒绝下载未允许的媒体主机：${source.host}');
    }
    var current = source;
    for (var redirects = 0; redirects <= 5; redirects++) {
      final request = await _client.getUrl(current);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final response = await request.close();
      if (_isRedirect(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null) throw Exception('媒体重定向缺少 Location：$current');
        current = current.resolve(location);
        if (!_isAllowedHost(current.host)) {
          throw Exception('媒体重定向到了未允许的主机：${current.host}');
        }
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw WordPressMediaDownloadException(
          url: current,
          statusCode: response.statusCode,
        );
      }
      final extension = _extension(current);
      final file = File(
        p.join(temporaryDirectory.path, '${const Uuid().v4()}$extension'),
      );
      final sink = file.openWrite();
      try {
        await sink.addStream(response);
      } finally {
        await sink.close();
      }
      final digest = await sha256.bind(file.openRead()).first;
      return DownloadedWordPressMedia(
        file: file,
        sha256: digest.toString(),
        extension: extension,
        contentType: response.headers.contentType?.mimeType,
      );
    }
    throw Exception('媒体重定向次数过多：$source');
  }

  void close() => _client.close(force: false);

  bool _isAllowedHost(String host) {
    final normalized = _normalizeHost(host);
    return normalized == sourceHost ||
        normalized == 'www.$sourceHost' ||
        sourceHost == 'www.$normalized';
  }

  static String _normalizeHost(String value) => value.trim().toLowerCase();

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  static String _extension(Uri uri) {
    final extension = p.extension(uri.path).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : '.bin';
  }
}
