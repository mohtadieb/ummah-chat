// lib/models/post_media.dart

class PostMedia {
  final String id;
  final String postId;
  final String type;       // 'image' or 'video'
  final String url;
  final int orderIndex;
  final DateTime createdAt;

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';

  PostMedia({
    required this.id,
    required this.postId,
    required this.type,
    required this.url,
    required this.orderIndex,
    required this.createdAt,
  });

  factory PostMedia.fromMap(Map<String, dynamic> map) {
    return PostMedia(
      id: map['id'].toString(),
      postId: map['post_id'].toString(),
      type: map['type'] ?? 'image',
      url: map['url'] ?? '',
      orderIndex: (map['order_index'] ?? 0) as int,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at']).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'type': type,
      'url': url,
      'order_index': orderIndex,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
