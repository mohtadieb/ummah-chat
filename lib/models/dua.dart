class Dua {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final bool isAnonymous;
  final bool isPrivate;
  final DateTime createdAt;
  final int ameenCount;
  final bool userHasAmeened;

  Dua({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.isAnonymous,
    required this.isPrivate,
    required this.createdAt,
    required this.ameenCount,
    required this.userHasAmeened,
  });

  /// Build from Supabase row with nested `ameens: dua_ameens(user_id)`
  factory Dua.fromMap(Map<String, dynamic> map, String currentUserId) {
    final ameensRaw = (map['ameens'] as List<dynamic>? ?? const []);

    // Extract user_ids regardless of shape
    final ameenerIds = ameensRaw.map((item) {
      if (item is Map && item['user_id'] != null) {
        return item['user_id'].toString();
      }
      return item.toString();
    }).toList();

    final hasAmeened = ameenerIds.contains(currentUserId);

    // Prefer explicit user_name column; fallback just in case
    final String userName = (map['user_name'] as String?) ??
        (map['username'] as String?) ??
        (map['name'] as String?) ??
        'User';

    return Dua(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      userName: userName,
      text: map['text']?.toString() ?? '',
      isAnonymous: (map['is_anonymous'] as bool?) ?? false,
      isPrivate: (map['is_private'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'].toString()),
      ameenCount: (map['ameen_count'] as int?) ?? ameenerIds.length,
      userHasAmeened: hasAmeened,
    );
  }

  Dua copyWith({
    String? id,
    String? userId,
    String? userName,
    String? text,
    bool? isAnonymous,
    bool? isPrivate,
    DateTime? createdAt,
    int? ameenCount,
    bool? userHasAmeened,
  }) {
    return Dua(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      text: text ?? this.text,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      ameenCount: ameenCount ?? this.ameenCount,
      userHasAmeened: userHasAmeened ?? this.userHasAmeened,
    );
  }
}
