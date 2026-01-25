class UserReward {
  final String id;
  final String userId;
  final int points;
  final double totalWasteKg;
  final int totalPickups;
  final String level;
  final DateTime updatedAt;

  UserReward({
    required this.id,
    required this.userId,
    this.points = 0,
    this.totalWasteKg = 0,
    this.totalPickups = 0,
    this.level = 'beginner',
    required this.updatedAt,
  });

  factory UserReward.fromJson(Map<String, dynamic> json) => UserReward(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        points: json['points'] as int? ?? 0,
        totalWasteKg: (json['total_waste_kg'] as num?)?.toDouble() ?? 0,
        totalPickups: json['total_pickups'] as int? ?? 0,
        level: json['level'] as String? ?? 'beginner',
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'points': points,
        'total_waste_kg': totalWasteKg,
        'total_pickups': totalPickups,
        'level': level,
        'updated_at': updatedAt.toIso8601String(),
      };
}
