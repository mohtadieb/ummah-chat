// lib/helper/post_share.dart

class PostShare {
  static const String prefix = 'POST_SHARE:';

  static bool isPostShareMessage(String msg) {
    final t = msg.trim();
    return t.startsWith(prefix) && t.length > prefix.length;
  }

  static String buildMessage(String postId) => '$prefix$postId';

  static String? extractPostId(String msg) {
    final t = msg.trim();
    if (!t.startsWith(prefix)) return null;
    final id = t.substring(prefix.length).trim();
    return id.isEmpty ? null : id;
  }
}
