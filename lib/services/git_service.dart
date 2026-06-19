import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/app_settings.dart';

class GitException implements Exception {
  GitException(this.message);
  final String message;
  @override
  String toString() => message;
}

class GitService {
  Future<bool> get isAvailable async {
    try {
      final result = await Process.run('git', ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  Future<String> clone(AppSettings settings, String parentDirectory) async {
    final name = _repositoryName(settings.gitUrl);
    final target = p.join(parentDirectory, name);
    if (await Directory(target).exists()) return target;
    await _run(['clone', _authenticatedUrl(settings), target]);
    await configureIdentity(target, settings);
    return target;
  }

  Future<void> configureIdentity(
    String repositoryPath,
    AppSettings settings,
  ) async {
    if (settings.gitAuthorName.isNotEmpty) {
      await _run([
        'config',
        'user.name',
        settings.gitAuthorName,
      ], cwd: repositoryPath);
    }
    if (settings.gitAuthorEmail.isNotEmpty) {
      await _run([
        'config',
        'user.email',
        settings.gitAuthorEmail,
      ], cwd: repositoryPath);
    }
  }

  Future<String> status(String repositoryPath) async =>
      (await _run(['status', '--short'], cwd: repositoryPath)).trim();

  Future<String> currentBranch(String repositoryPath) async =>
      (await _run(['branch', '--show-current'], cwd: repositoryPath)).trim();

  Future<String?> saveCommit(
    String repositoryPath, {
    required String message,
  }) async {
    await _run(['add', '--all'], cwd: repositoryPath);
    if ((await status(repositoryPath)).isEmpty) return null;
    await _run(['commit', '-m', message], cwd: repositoryPath);
    return (await _run([
      'rev-parse',
      '--short',
      'HEAD',
    ], cwd: repositoryPath)).trim();
  }

  Future<void> push(AppSettings settings) async {
    final branch = await currentBranch(settings.repositoryPath);
    final remote = settings.gitToken.isEmpty
        ? 'origin'
        : _authenticatedUrl(settings);
    await _run(['push', remote, branch], cwd: settings.repositoryPath);
  }

  Future<void> undoLastCommit(String repositoryPath) async {
    await _run(['reset', '--soft', 'HEAD~1'], cwd: repositoryPath);
  }

  Future<String> _run(List<String> arguments, {String? cwd}) async {
    ProcessResult result;
    try {
      result = await Process.run('git', arguments, workingDirectory: cwd);
    } on ProcessException catch (error) {
      throw GitException('无法启动 Git：${error.message}');
    }
    if (result.exitCode != 0) {
      final error = '${result.stderr}'.trim();
      throw GitException(error.isEmpty ? 'Git 操作失败' : error);
    }
    return '${result.stdout}';
  }

  String _authenticatedUrl(AppSettings settings) {
    final uri = Uri.tryParse(settings.gitUrl);
    if (uri == null || uri.scheme != 'https' || settings.gitToken.isEmpty) {
      return settings.gitUrl;
    }
    return uri
        .replace(
          userInfo:
              '${Uri.encodeComponent(settings.gitUsername.isEmpty ? 'oauth2' : settings.gitUsername)}:${Uri.encodeComponent(settings.gitToken)}',
        )
        .toString();
  }

  String _repositoryName(String url) {
    final clean = url.replaceAll(RegExp(r'[/\\]+$'), '');
    final last = clean.split(RegExp(r'[/\\:]')).last;
    return last.replaceFirst(RegExp(r'\.git$'), '');
  }
}
