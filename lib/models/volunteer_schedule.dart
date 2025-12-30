class VolunteerSchedule {
  final String id;
  final String volunteerId;
  final DateTime date;
  final bool isAvailable;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VolunteerSchedule({
    required this.id,
    required this.volunteerId,
    required this.date,
    required this.isAvailable,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory VolunteerSchedule.fromJson(Map<String, dynamic> json) =>
      VolunteerSchedule(
        id: json['id'] as String,
        volunteerId: json['volunteer_id'] as String,
        date: DateTime.parse(json['date'] as String),
        isAvailable: json['is_available'] as bool,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'volunteer_id': volunteerId,
        'date': date.toIso8601String().split('T')[0], // Store as date only
        'is_available': isAvailable,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
