class EwasteItem {
  final int id;
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

  EwasteItem({
    required this.id,
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
  });

  factory EwasteItem.fromJson(Map<String, dynamic> json) => EwasteItem(
        id: json['id'] as int,
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
      );
}
