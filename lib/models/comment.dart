class BlogComment {
  const BlogComment({
    required this.id,
    required this.slug,
    required this.nickname,
    required this.content,
    required this.createdAt,
    this.email,
  });

  final String id;
  final String slug;
  final String nickname;
  final String content;
  final DateTime createdAt;
  final String? email;

  factory BlogComment.fromJson(Map<String, dynamic> json) => BlogComment(
        id: '${json['id']}',
        slug: '${json['slug'] ?? ''}',
        nickname: '${json['nickname'] ?? '匿名访客'}',
        content: '${json['content'] ?? ''}',
        createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
        email: json['email'] as String?,
      );
}
