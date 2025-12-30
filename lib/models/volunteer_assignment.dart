class VolunteerAssignment {
  final String id;
  final String volunteerId;
  final String taskId;
  final String taskType;
  final DateTime? assignedAt;
  final DateTime? scheduledDate;
  final String status;
  final String? notes;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  VolunteerAssignment({
    required this.id,
    required this.volunteerId,
    required this.taskId,
    required this.taskType,
    this.assignedAt,
    this.scheduledDate,
    required this.status,
    this.notes,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VolunteerAssignment.fromJson(Map<String, dynamic> json) {
    return VolunteerAssignment(
      id: json['id'] as String,
      volunteerId: json['volunteer_id'] as String,
      taskId: json['task_id'] as String,
      taskType: json['task_type'] as String,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'volunteer_id': volunteerId,
      'task_id': taskId,
      'task_type': taskType,
      'assigned_at': assignedAt?.toIso8601String(),
      'scheduled_date': scheduledDate?.toIso8601String(),
      'status': status,
      'notes': notes,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
