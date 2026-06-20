import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models/app_settings.dart';
import 'models/article.dart';
import 'models/comment.dart';
import 'services/article_service.dart';
import 'services/asset_service.dart';
import 'services/backup_service.dart';
import 'services/config_service.dart';
import 'services/git_service.dart';
import 'services/r2_service.dart';
import 'services/settings_service.dart';
import 'services/supabase_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    SettingsService? settingsService,
    GitService? gitService,
    ArticleService? articleService,
    R2Service? r2Service,
    SupabaseService? supabaseService,
    ConfigService? configService,
    AssetService? assetService,
    BackupService? backupService,
  })  : settingsService = settingsService ?? const SettingsService(),
        gitService = gitService ?? GitService(),
        articleService = articleService ?? ArticleService(),
        r2Service = r2Service ?? R2Service(),
        supabaseService = supabaseService ?? SupabaseService(),
        configService = configService ?? ConfigService(),
        assetService = assetService ?? AssetService(),
        backupService = backupService ?? BackupService();

  final SettingsService settingsService;
  final GitService gitService;
  final ArticleService articleService;
  final R2Service r2Service;
  final SupabaseService supabaseService;
  final ConfigService configService;
  final AssetService assetService;
  final BackupService backupService;

  AppSettings settings = const AppSettings();
  List<Article> articles = [];
  bool busy = false;
  bool initialized = false;
  String? error;
  String? backupStatus;
  Timer? _backupTimer;

  bool get hasRepository =>
      settings.repositoryPath.isNotEmpty &&
      Directory(settings.repositoryPath).existsSync();

  Future<void> initialize() async {
    settings = await settingsService.load();
    if (hasRepository) await refreshArticles();
    initialized = true;
    _scheduleBackup();
    notifyListeners();
    unawaited(_runScheduledBackupIfDue());
  }

  Future<void> updateSettings(AppSettings value) async {
    settings = value;
    await settingsService.save(value);
    _scheduleBackup();
    notifyListeners();
  }

  Future<void> completeOnboarding() => updateSettings(
        settings.copyWith(onboardingCompleted: true),
      );

  Future<String> testGit() async {
    return testGitSettings(settings);
  }

  Future<String> testGitSettings(AppSettings value) async {
    if (!await gitService.isAvailable) throw Exception('未找到 Git 命令。');
    if (value.repositoryPath.isEmpty ||
        !Directory(value.repositoryPath).existsSync()) {
      return value.gitUrl.isEmpty
          ? 'Git 已安装；填写仓库地址或选择本地工作区后可继续检测。'
          : 'Git 已安装 · 仓库地址格式正常，连接时将执行克隆。';
    }
    final branch = await gitService.currentBranch(value.repositoryPath);
    final changes = await gitService.status(value.repositoryPath);
    return 'Git 正常 · 分支 ${branch.isEmpty ? '(detached)' : branch} · '
        '${changes.isEmpty ? '工作区干净' : '存在未提交改动'}';
  }

  Future<String> testR2() => r2Service.testConnection(settings);

  Future<String> testR2Settings(AppSettings value) =>
      r2Service.testConnection(value);

  Future<String> testBlog() async {
    return testBlogSettings(settings);
  }

  Future<String> testBlogSettings(AppSettings value) async {
    if (value.repositoryPath.isEmpty ||
        !Directory(value.repositoryPath).existsSync()) {
      throw Exception('请先选择已有的本地博客仓库。');
    }
    await _validateRepository(value.repositoryPath);
    final count = (await articleService.loadAll(value.repositoryPath)).length;
    return 'Starry Blog 结构正常 · 已识别 $count 篇文章';
  }

  Future<void> connectRepository(AppSettings value) async {
    await run(() async {
      settings = value;
      var path = value.repositoryPath;
      if (path.isEmpty || !Directory(path).existsSync()) {
        if (value.gitUrl.isEmpty) throw Exception('请填写 Git URL 或有效的本地仓库路径。');
        if (!await gitService.isAvailable) {
          throw Exception('当前设备找不到 Git。请安装 Git，或填写一个已经检出的本地仓库目录。');
        }
        final documents = await getApplicationDocumentsDirectory();
        final parent = Directory(
          '${documents.path}${Platform.pathSeparator}StarryNote',
        );
        await parent.create(recursive: true);
        path = await gitService.clone(value, parent.path);
        settings = value.copyWith(repositoryPath: path);
      } else if (await gitService.isAvailable) {
        await gitService.configureIdentity(path, value);
      }
      await _validateRepository(path);
      await settingsService.save(settings);
      await refreshArticles();
    });
  }

  Future<void> refreshArticles() async {
    if (!hasRepository) return;
    articles = await articleService.loadAll(settings.repositoryPath);
    notifyListeners();
  }

  Future<String?> saveArticle(Article article) async {
    String? commit;
    await run(() async {
      if (article.title.trim().isEmpty) throw Exception('文章标题不能为空。');
      if (article.slug.trim().isEmpty) {
        article.slug = articleService.slugify(article.title);
      }
      await articleService.save(settings.repositoryPath, article);
      if (await gitService.isAvailable) {
        commit = await gitService.saveCommit(
          settings.repositoryPath,
          message: 'article: ${article.title}',
        );
      }
      await refreshArticles();
    });
    return commit;
  }

  Future<void> deleteArticle(Article article) async {
    await run(() async {
      await articleService.delete(settings.repositoryPath, article);
      if (await gitService.isAvailable) {
        await gitService.saveCommit(
          settings.repositoryPath,
          message: 'article: remove ${article.title}',
        );
      }
      await refreshArticles();
    });
  }

  Future<void> push() => run(() => gitService.push(settings));

  Future<void> undoLastCommit() => run(() async {
        await gitService.undoLastCommit(settings.repositoryPath);
        await refreshArticles();
      });

  Future<List<BlogComment>> comments() =>
      supabaseService.listComments(settings);
  Future<void> deleteComment(String id) =>
      run(() => supabaseService.deleteComment(settings, id));

  Future<List<SupabaseTableInfo>> backupTables() =>
      backupService.listTables(settings);

  Future<BackupResult> backupDatabase({
    String? outputPath,
    List<String>? tables,
  }) async {
    late BackupResult result;
    await run(() async {
      final path =
          outputPath ?? backupService.automaticPath(settings.backupDirectory);
      result = await backupService.export(
        settings: settings,
        outputPath: path,
        tables: tables ?? settings.backupTables,
      );
      settings =
          settings.copyWith(lastBackupAt: DateTime.now().toIso8601String());
      await settingsService.save(settings);
      backupStatus =
          '已备份 ${result.tableCount} 个表、${result.rowCount} 行到 ${result.path}';
    });
    return result;
  }

  Future<T?> run<T>(Future<T> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      return await action();
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _validateRepository(String path) async {
    final config = File(
      '$path${Platform.pathSeparator}public${Platform.pathSeparator}config.js',
    );
    final articles = Directory(
      '$path${Platform.pathSeparator}public${Platform.pathSeparator}articles',
    );
    if (!await config.exists() || !await articles.exists()) {
      throw Exception(
        '该目录不是 Starry Blog：缺少 public/config.js 或 public/articles。',
      );
    }
  }

  void _scheduleBackup() {
    _backupTimer?.cancel();
    if (!settings.autoBackupEnabled || settings.backupDirectory.isEmpty) return;
    _backupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_runScheduledBackupIfDue()),
    );
  }

  Future<void> _runScheduledBackupIfDue() async {
    if (busy ||
        !settings.autoBackupEnabled ||
        settings.backupDirectory.isEmpty) {
      return;
    }
    final last = DateTime.tryParse(settings.lastBackupAt);
    final interval =
        Duration(hours: settings.backupIntervalHours.clamp(1, 8760));
    if (last != null && DateTime.now().difference(last) < interval) return;
    try {
      await backupDatabase();
    } catch (exception) {
      backupStatus =
          '自动备份失败：${exception.toString().replaceFirst('Exception: ', '')}';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    super.dispose();
  }
}
