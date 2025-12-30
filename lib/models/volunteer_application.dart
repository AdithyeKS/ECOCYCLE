class VolunteerApplication {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final DateTime availableDate;
  final String motivation; // Replaced experience with social work motivation
  final bool agreedToPolicy; // Security and User Safety policy agreement
  final String status; // pending, approved, rejected
  final DateTime createdAt;

  VolunteerApplication({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.availableDate,
    required this.motivation,
    required this.agreedToPolicy,
    this.status = 'pending',
    required this.createdAt,
  });

  factory VolunteerApplication.fromJson(Map<String, dynamic> json) =>
      VolunteerApplication(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        address: json['address'] as String,
        availableDate: DateTime.parse(json['available_date'] as String),
        motivation: json['motivation'] as String,
        agreedToPolicy: json['agreed_to_policy'] as bool? ?? false,
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'available_date': availableDate.toIso8601String(),
        'motivation': motivation,
        'agreed_to_policy': agreedToPolicy,
        'status': status,
      };
}
