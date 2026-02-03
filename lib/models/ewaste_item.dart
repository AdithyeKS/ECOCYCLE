class EwasteItem {
  final String id;
  final String userId; // Link to authenticated user
  final String categoryId;
  final String itemName;
  final String description;
  final String location;
  final String status;
  final String imageUrl;
  final String? assignedTo;
  final DateTime createdAt;
  final int? rewardPoints;
  final Map<String, dynamic>? metadata;

  // New fields for NGO and pickup system
  final String? assignedAgentId;
  final String? assignedNgoId;
  final String deliveryStatus;
  final List<Map<String, dynamic>>? trackingNotes;
  final DateTime? pickupScheduledAt;
  final DateTime? collectedAt;
  final DateTime? deliveredAt;

  EwasteItem({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.itemName,
    required this.description,
    required this.location,
    required this.status,
    required this.imageUrl,
    this.assignedTo,
    required this.createdAt,
    this.rewardPoints,
    this.metadata,
    this.assignedAgentId,
    this.assignedNgoId,
    this.deliveryStatus = 'pending',
    this.trackingNotes,
    this.pickupScheduledAt,
    this.collectedAt,
    this.deliveredAt,
  });

  factory EwasteItem.fromJson(Map<String, dynamic> json) => EwasteItem(
        id: json['id'] as String,
        userId: json['user_id'] ?? '',
        categoryId: json['category_id'] ?? '',
        itemName: json['item_name'] ?? '',
        description: json['description'] ?? '',
        location: json['location'] ?? '',
        status: json['status'] ?? 'Pending',
        imageUrl: json['image_url'] ?? '',
        assignedTo: json['assigned_to'],
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        rewardPoints: json['reward_points'] as int?,
        metadata: json['metadata'] as Map<String, dynamic>?,
        assignedAgentId: json['assigned_agent_id'] as String?,
        assignedNgoId: json['assigned_ngo_id'] as String?,
        deliveryStatus: json['delivery_status'] ?? 'pending',
        trackingNotes: json['tracking_notes'] != null
            ? List<Map<String, dynamic>>.from(json['tracking_notes'])
            : null,
        pickupScheduledAt: json['pickup_scheduled_at'] != null
            ? DateTime.tryParse(json['pickup_scheduled_at'])
            : null,
        collectedAt: json['collected_at'] != null
            ? DateTime.tryParse(json['collected_at'])
            : null,
        deliveredAt: json['delivered_at'] != null
            ? DateTime.tryParse(json['delivered_at'])
            : null,
      );

  // copyWith method to create a modified copy of the object
  EwasteItem copyWith({
    String? id,
    String? userId,
    String? categoryId,
    String? itemName,
    String? description,
    String? location,
    String? status,
    String? imageUrl,
    String? assignedTo,
    DateTime? createdAt,
    int? rewardPoints,
    Map<String, dynamic>? metadata,
    String? assignedAgentId,
    String? assignedNgoId,
    String? deliveryStatus,
    List<Map<String, dynamic>>? trackingNotes,
    DateTime? pickupScheduledAt,
    DateTime? collectedAt,
    DateTime? deliveredAt,
  }) {
    return EwasteItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      location: location ?? this.location,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      metadata: metadata ?? this.metadata,
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      assignedNgoId: assignedNgoId ?? this.assignedNgoId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      trackingNotes: trackingNotes ?? this.trackingNotes,
      pickupScheduledAt: pickupScheduledAt ?? this.pickupScheduledAt,
      collectedAt: collectedAt ?? this.collectedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }
}
