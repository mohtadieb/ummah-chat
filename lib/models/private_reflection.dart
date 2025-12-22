class PrivateReflection {
  final String id;
  final String userId;
  final String? postId;
  final String text;
  final DateTime createdAt;

  PrivateReflection({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.postId,
  });

  factory PrivateReflection.fromMap(Map<String, dynamic> map) {
    return PrivateReflection(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      postId: map['post_id'] as String?,
      text: map['text'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
