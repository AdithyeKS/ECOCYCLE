class PlasticItem {
  final String id;
  final String userId;
  final String plasticType; // e.g., PET, HDPE, PVC
  final String itemName;
  final String description;
  final String location;
  final String? imageUrl;
  final String status;
  final int points;
  final DateTime createdAt;
  final String deliveryStatus;
  final String? assignedAgentId; // Assigned volunteer/agent
  final String? assignedNgoId; // Assigned NGO center
  final DateTime? pickupScheduledAt; // Scheduled pickup date/time
  final int quantity; // Added quantity field
  final double? latitude; // Added latitude
  final double? longitude; // Added longitude

  final String? otpCode;

  PlasticItem({
    required this.id,
    required this.userId,
    required this.plasticType,
    required this.itemName,
    required this.description,
    required this.location,
    this.imageUrl,
    this.status = 'pending',
    this.points = 0,
    required this.createdAt,
    this.deliveryStatus = 'pending',
    this.assignedAgentId,
    this.assignedNgoId,
    this.pickupScheduledAt,
    this.quantity = 1, // Default to 1
    this.latitude,
    this.longitude,
    this.otpCode,
  });

  factory PlasticItem.fromJson(Map<String, dynamic> json) => PlasticItem(
        id: json['id'],
        userId: json['user_id'],
        plasticType: json['plastic_type'],
        itemName: json['item_name'],
        description: json['description'],
        location: json['location'],
        imageUrl: json['image_url'],
        status: json['status'],
        points: json['points'] ?? 0,
        createdAt: DateTime.parse(json['created_at']),
        deliveryStatus: json['delivery_status'] ?? 'pending',
        assignedAgentId: json['assigned_agent_id'] as String?,
        assignedNgoId: json['assigned_ngo_id'] as String?,
        pickupScheduledAt: json['pickup_scheduled_for'] != null
            ? DateTime.parse(json['pickup_scheduled_for'] as String)
            : null,
        quantity: json['quantity'] != null ? json['quantity'] as int : 1,
        latitude: json['latitude'] != null
            ? (json['latitude'] as num).toDouble()
            : null,
        longitude: json['longitude'] != null
            ? (json['longitude'] as num).toDouble()
            : null,
        otpCode: json['otp_code'] as String?,
      );
}
