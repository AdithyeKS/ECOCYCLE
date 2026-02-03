class Ngo {
  final String id;
  final String name;
  final String? description;
  final String district;
  final String address;
  final List<String>? wasteTypes;
  final String? contactInfo;
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
    required this.district,
    required this.address,
    this.wasteTypes,
    this.contactInfo,
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
        district: json['district'] as String? ?? 'Unknown',
        address: json['address'] as String,
        wasteTypes: (json['waste_types'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        contactInfo: json['contact_info'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        isGovernmentApproved: json['is_government_approved'] as bool? ?? true,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  // NEW: Placeholder for safe lookup in the dashboard
  factory Ngo.placeholder() => Ngo(
        id: '0',
        name: 'N/A (Unassigned)',
        district: 'N/A',
        address: 'N/A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'district': district,
        'address': address,
        'waste_types': wasteTypes,
        'contact_info': contactInfo,
        'phone': phone,
        'email': email,
        'is_government_approved': isGovernmentApproved,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
