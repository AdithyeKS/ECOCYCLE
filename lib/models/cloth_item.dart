class ClothItem {
  final int? id;
  final String userId;
  final String type; // e.g., Apparel, Linen, Accessories
  final int quantity; // Number of items or weight in kg (simple integer for now)
  final String condition; // e.g., Good, Fair, Poor (user's input)
  final String location;
  final String status; // Pending, Collected, Donated
  final DateTime createdAt;
  final String? imageUrl; // NEW
  final int? damagePercent; // NEW (AI estimate)

  ClothItem({
    this.id,
    required this.userId,
    required this.type,
    required this.quantity,
    required this.condition,
    required this.location,
    this.status = 'Pending',
    required this.createdAt,
    this.imageUrl,
    this.damagePercent,
  });

  factory ClothItem.fromJson(Map<String, dynamic> json) => ClothItem(
        id: json['id'] as int?,
        userId: json['user_id'] as String,
        type: json['type'] as String,
        quantity: json['quantity'] as int,
        condition: json['condition'] as String,
        location: json['location'] as String,
        status: json['status'] as String? ?? 'Pending',
        createdAt: DateTime.parse(json['created_at'] as String),
        imageUrl: json['image_url'] as String?, // NEW
        damagePercent: json['damage_percent'] as int?, // NEW
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'type': type,
        'quantity': quantity,
        'condition': condition,
        'location': location,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'image_url': imageUrl, // NEW
        'damage_percent': damagePercent, // NEW
      };
}