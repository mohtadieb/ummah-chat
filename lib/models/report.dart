class Report {
  final String id;
  final String reportedBy;      // user who reported
  final String? messageId;      // nullable if message deleted
  final String? messageOwnerId; // nullable (ON DELETE SET NULL)
  final DateTime createdAt;

  Report({
    required this.id,
    required this.reportedBy,
    this.messageId,
    this.messageOwnerId,
    required this.createdAt,
  });

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id']?.toString() ?? '',
      reportedBy: map['reported_by']?.toString() ?? '',
      messageId: map['message_id']?.toString(),
      messageOwnerId: map['message_owner_id']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
          DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'reported_by': reportedBy,
      'message_id': messageId,
      'message_owner_id': messageOwnerId,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  Report copyWith({
    String? id,
    String? reportedBy,
    String? messageId,
    String? messageOwnerId,
    DateTime? createdAt,
  }) {
    return Report(
      id: id ?? this.id,
      reportedBy: reportedBy ?? this.reportedBy,
      messageId: messageId ?? this.messageId,
      messageOwnerId: messageOwnerId ?? this.messageOwnerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
