class Post {
  final String id;
  final String authorId;
  final String type;
  final String body;
  final List<String> hashtags;
  final List<String> images;
  final DateTime createdAt;
  final Map<String, dynamic>? author;

  const Post({
    required this.id,
    required this.authorId,
    required this.type,
    required this.body,
    required this.hashtags,
    this.images = const [],
    required this.createdAt,
    this.author,
  });

  factory Post.fromMap(Map<String, dynamic> m, Map<String, dynamic>? author) {
    return Post(
      id: m['id'] as String,
      authorId: m['author_id'] as String,
      type: m['type'] as String,
      body: m['body'] as String,
      hashtags: List<String>.from(m['hashtags'] as List? ?? const []),
      images: List<String>.from(m['images'] as List? ?? const []),
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      author: author,
    );
  }
}
