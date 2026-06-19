class AppSettings {
  const AppSettings({
    this.gitUrl = '',
    this.repositoryPath = '',
    this.gitAuthorName = '',
    this.gitAuthorEmail = '',
    this.gitUsername = '',
    this.gitToken = '',
    this.supabaseUrl = '',
    this.supabaseKey = '',
    this.r2AccountId = '',
    this.r2AccessKeyId = '',
    this.r2SecretAccessKey = '',
    this.r2Bucket = '',
    this.r2PublicBaseUrl = '',
  });

  final String gitUrl;
  final String repositoryPath;
  final String gitAuthorName;
  final String gitAuthorEmail;
  final String gitUsername;
  final String gitToken;
  final String supabaseUrl;
  final String supabaseKey;
  final String r2AccountId;
  final String r2AccessKeyId;
  final String r2SecretAccessKey;
  final String r2Bucket;
  final String r2PublicBaseUrl;

  AppSettings copyWith({
    String? gitUrl,
    String? repositoryPath,
    String? gitAuthorName,
    String? gitAuthorEmail,
    String? gitUsername,
    String? gitToken,
    String? supabaseUrl,
    String? supabaseKey,
    String? r2AccountId,
    String? r2AccessKeyId,
    String? r2SecretAccessKey,
    String? r2Bucket,
    String? r2PublicBaseUrl,
  }) =>
      AppSettings(
        gitUrl: gitUrl ?? this.gitUrl,
        repositoryPath: repositoryPath ?? this.repositoryPath,
        gitAuthorName: gitAuthorName ?? this.gitAuthorName,
        gitAuthorEmail: gitAuthorEmail ?? this.gitAuthorEmail,
        gitUsername: gitUsername ?? this.gitUsername,
        gitToken: gitToken ?? this.gitToken,
        supabaseUrl: supabaseUrl ?? this.supabaseUrl,
        supabaseKey: supabaseKey ?? this.supabaseKey,
        r2AccountId: r2AccountId ?? this.r2AccountId,
        r2AccessKeyId: r2AccessKeyId ?? this.r2AccessKeyId,
        r2SecretAccessKey: r2SecretAccessKey ?? this.r2SecretAccessKey,
        r2Bucket: r2Bucket ?? this.r2Bucket,
        r2PublicBaseUrl: r2PublicBaseUrl ?? this.r2PublicBaseUrl,
      );

  Map<String, String> toMap() => {
        'gitUrl': gitUrl,
        'repositoryPath': repositoryPath,
        'gitAuthorName': gitAuthorName,
        'gitAuthorEmail': gitAuthorEmail,
        'gitUsername': gitUsername,
        'gitToken': gitToken,
        'supabaseUrl': supabaseUrl,
        'supabaseKey': supabaseKey,
        'r2AccountId': r2AccountId,
        'r2AccessKeyId': r2AccessKeyId,
        'r2SecretAccessKey': r2SecretAccessKey,
        'r2Bucket': r2Bucket,
        'r2PublicBaseUrl': r2PublicBaseUrl,
      };

  factory AppSettings.fromMap(Map<String, String> map) => AppSettings(
        gitUrl: map['gitUrl'] ?? '',
        repositoryPath: map['repositoryPath'] ?? '',
        gitAuthorName: map['gitAuthorName'] ?? '',
        gitAuthorEmail: map['gitAuthorEmail'] ?? '',
        gitUsername: map['gitUsername'] ?? '',
        gitToken: map['gitToken'] ?? '',
        supabaseUrl: map['supabaseUrl'] ?? '',
        supabaseKey: map['supabaseKey'] ?? '',
        r2AccountId: map['r2AccountId'] ?? '',
        r2AccessKeyId: map['r2AccessKeyId'] ?? '',
        r2SecretAccessKey: map['r2SecretAccessKey'] ?? '',
        r2Bucket: map['r2Bucket'] ?? '',
        r2PublicBaseUrl: map['r2PublicBaseUrl'] ?? '',
      );
}
