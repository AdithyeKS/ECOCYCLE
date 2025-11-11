class Ngo {
  final String id;
  final String name;
  final String? description;
  final String address;
  final String? phone;
  final String? email;
  final bool isGovernmentApproved;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ngo({
    required this.id,
    required this.name,
    this.description,
    required this.address,
    this.phone,
    this.email,
    this.isGovernmentApproved = true,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ngo.fromJson(Map<String, dynamic> json) => Ngo(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        address: json['address'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        isGovernmentApproved: json['is_government_approved'] as bool? ?? true,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'address': address,
        'phone': phone,
        'email': email,
        'is_government_approved': isGovernmentApproved,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
