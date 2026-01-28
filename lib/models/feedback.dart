class FeedbackItem {
  final String id;
  final String? userId;
  final String? userEmail;
  final String subject;
  final String message;
  final String category;
  final String status;
  final String? adminResponse;
  final DateTime? respondedAt;
  final String? respondedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeedbackItem({
    required this.id,
    this.userId,
    this.userEmail,
    required this.subject,
    required this.message,
    required this.category,
    required this.status,
    this.adminResponse,
    this.respondedAt,
    this.respondedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String?,
      subject: json['subject'] as String,
      message: json['message'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      adminResponse: json['admin_response'] as String?,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      respondedBy: json['responded_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_email': userEmail,
      'subject': subject,
      'message': message,
      'category': category,
      'status': status,
      'admin_response': adminResponse,
      'responded_at': respondedAt?.toIso8601String(),
      'responded_by': respondedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
