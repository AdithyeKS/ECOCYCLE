class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String importance; // 'high', 'normal', 'low'

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.importance = 'normal',
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        type: json['type'] as String? ?? 'general',
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        importance: json['importance'] as String? ?? 'normal',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
        'importance': importance,
      };
}
