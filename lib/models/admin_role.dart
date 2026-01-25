class AdminRole {
  final String id;
  final DateTime createdAt;

  AdminRole({
    required this.id,
    required this.createdAt,
  });

  factory AdminRole.fromJson(Map<String, dynamic> json) => AdminRole(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
      };
}
