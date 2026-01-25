class UserNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'assignment', 'reminder', 'achievement', 'system'
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  UserNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) =>
      UserNotification(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        type: json['type'] as String,
        data: json['data'] as Map<String, dynamic>?,
        isRead: json['is_read'] as bool? ?? false,
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data,
        'is_read': isRead,
        'read_at': readAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
