class PickupRequest {
  final String id;
  final String? agentId;
  final String name;
  final String phone;
  final String? email;
  final String? vehicleNumber;
  final bool isActive;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  PickupRequest({
    required this.id,
    this.agentId,
    required this.name,
    required this.phone,
    this.email,
    this.vehicleNumber,
    this.isActive = true,
    this.currentLatitude,
    this.currentLongitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PickupRequest.fromJson(Map<String, dynamic> json) => PickupRequest(
        id: json['id'] as String,
        agentId: json['agent_id'] as String?,
        name: json['name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        vehicleNumber: json['vehicle_number'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        currentLatitude: json['current_latitude'] as double?,
        currentLongitude: json['current_longitude'] as double?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'agent_id': agentId,
        'name': name,
        'phone': phone,
        'email': email,
        'vehicle_number': vehicleNumber,
        'is_active': isActive,
        'current_latitude': currentLatitude,
        'current_longitude': currentLongitude,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
