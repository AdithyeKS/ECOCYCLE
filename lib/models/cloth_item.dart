class ClothItem {
  final int? id;
  final String userId;
  final String type; // e.g., Apparel, Linen, Accessories
  final int
      quantity; // Number of items or weight in kg (simple integer for now)
  final String condition; // e.g., Good, Fair, Poor (user's input)
  final String location;
  final String status; // Pending, Collected, Donated
  final DateTime createdAt;
  final String? imageUrl; // NEW
  final int? damagePercent; // NEW (AI estimate)
  final String deliveryStatus;
  final String? assignedAgentId; // Assigned volunteer/agent
  final String? assignedNgoId; // Assigned NGO center
  final DateTime? pickupScheduledAt; // Scheduled pickup date/time
  final double? latitude; // Added latitude
  final double? longitude; // Added longitude

  final String? otpCode; // NEW: Verification code

  // Getter for compatibility with other item types
  String get itemName => type;
  String get description => quantity == 1
      ? '$quantity item - $condition condition'
      : '$quantity items - $condition condition';

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
    this.deliveryStatus = 'pending',
    this.assignedAgentId,
    this.assignedNgoId,
    this.pickupScheduledAt,
    this.latitude,
    this.longitude,
    this.otpCode,
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
        deliveryStatus: json['delivery_status'] ?? 'pending',
        assignedAgentId: json['assigned_agent_id'] as String?,
        assignedNgoId: json['assigned_ngo_id'] as String?,
        pickupScheduledAt: json['pickup_scheduled_for'] != null
            ? DateTime.parse(json['pickup_scheduled_for'] as String)
            : null,
        latitude: json['latitude'] != null
            ? (json['latitude'] as num).toDouble()
            : null,
        longitude: json['longitude'] != null
            ? (json['longitude'] as num).toDouble()
            : null,
        otpCode: json['otp_code'] as String?,
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
        'delivery_status': deliveryStatus,
        'assigned_agent_id': assignedAgentId,
        'assigned_ngo_id': assignedNgoId,
        'pickup_scheduled_for': pickupScheduledAt?.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'otp_code': otpCode,
      };
}
