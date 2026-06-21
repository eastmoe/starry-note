class WordPressImportOptions {
  const WordPressImportOptions({
    required this.xmlPath,
    this.sourceHost = '',
    this.sourceIp = '',
    this.skipSslVerification = false,
    this.migrateMedia = true,
    this.ignoreMissingMedia = false,
    this.importComments = true,
    this.privatePassword = '',
    this.pageCategory = '页面',
  });

  final String xmlPath;
  final String sourceHost;
  final String sourceIp;
  final bool skipSslVerification;
  final bool migrateMedia;
  final bool ignoreMissingMedia;
  final bool importComments;
  final String privatePassword;
  final String pageCategory;

  WordPressImportOptions copyWith({
    String? xmlPath,
    String? sourceHost,
    String? sourceIp,
    bool? skipSslVerification,
    bool? migrateMedia,
    bool? ignoreMissingMedia,
    bool? importComments,
    String? privatePassword,
    String? pageCategory,
  }) =>
      WordPressImportOptions(
        xmlPath: xmlPath ?? this.xmlPath,
        sourceHost: sourceHost ?? this.sourceHost,
        sourceIp: sourceIp ?? this.sourceIp,
        skipSslVerification: skipSslVerification ?? this.skipSslVerification,
        migrateMedia: migrateMedia ?? this.migrateMedia,
        ignoreMissingMedia: ignoreMissingMedia ?? this.ignoreMissingMedia,
        importComments: importComments ?? this.importComments,
        privatePassword: privatePassword ?? this.privatePassword,
        pageCategory: pageCategory ?? this.pageCategory,
      );
}

class WordPressImportPreview {
  const WordPressImportPreview({
    required this.siteTitle,
    required this.sourceUrl,
    required this.sourceHost,
    required this.posts,
    required this.pages,
    required this.privateItems,
    required this.attachments,
    required this.referencedMedia,
    required this.comments,
    required this.skippedItems,
    required this.warnings,
  });

  final String siteTitle;
  final String sourceUrl;
  final String sourceHost;
  final int posts;
  final int pages;
  final int privateItems;
  final int attachments;
  final int referencedMedia;
  final int comments;
  final int skippedItems;
  final List<String> warnings;

  int get articleCount => posts + pages;
}

class WordPressImportProgress {
  const WordPressImportProgress(this.completed, this.total, this.message);
  final int completed;
  final int total;
  final String message;

  double? get fraction => total <= 0 ? null : completed / total;
}

class WordPressImportResult {
  const WordPressImportResult({
    required this.articles,
    required this.pages,
    required this.privateItems,
    required this.mediaUploaded,
    required this.mediaReused,
    required this.mediaMissing,
    required this.commentsImported,
    required this.commentsSkipped,
    required this.skippedItems,
  });

  final int articles;
  final int pages;
  final int privateItems;
  final int mediaUploaded;
  final int mediaReused;
  final int mediaMissing;
  final int commentsImported;
  final int commentsSkipped;
  final int skippedItems;
}
