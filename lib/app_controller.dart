import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models/app_settings.dart';
import 'models/article.dart';
import 'models/comment.dart';
import 'services/article_service.dart';
import 'services/asset_service.dart';
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
  })  : settingsService = settingsService ?? const SettingsService(),
        gitService = gitService ?? GitService(),
        articleService = articleService ?? ArticleService(),
        r2Service = r2Service ?? R2Service(),
        supabaseService = supabaseService ?? SupabaseService(),
        configService = configService ?? ConfigService(),
        assetService = assetService ?? AssetService();

  final SettingsService settingsService;
  final GitService gitService;
  final ArticleService articleService;
  final R2Service r2Service;
  final SupabaseService supabaseService;
  final ConfigService configService;
  final AssetService assetService;

  AppSettings settings = const AppSettings();
  List<Article> articles = [];
  bool busy = false;
  bool initialized = false;
  String? error;

  bool get hasRepository =>
      settings.repositoryPath.isNotEmpty &&
      Directory(settings.repositoryPath).existsSync();

  Future<void> initialize() async {
    settings = await settingsService.load();
    if (hasRepository) await refreshArticles();
    initialized = true;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings value) async {
    settings = value;
    await settingsService.save(value);
    notifyListeners();
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
}
