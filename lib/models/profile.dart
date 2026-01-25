class Profile {
  final String id;
  final String? fullName;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? userRole;
  final String? supervisorId;
  final int totalPoints;
  final DateTime? volunteerRequestedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    this.fullName,
    this.email,
    this.phoneNumber,
    this.address,
    this.userRole,
    this.supervisorId,
    this.totalPoints = 0,
    this.volunteerRequestedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String?,
        address: json['address'] as String?,
        userRole: json['user_role'] as String?,
        supervisorId: json['supervisor_id'] as String?,
        totalPoints: json['total_points'] as int? ?? 0,
        volunteerRequestedAt: json['volunteer_requested_at'] != null
            ? DateTime.tryParse(json['volunteer_requested_at'])
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'address': address,
        'user_role': userRole,
        'supervisor_id': supervisorId,
        'total_points': totalPoints,
        'volunteer_requested_at': volunteerRequestedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
