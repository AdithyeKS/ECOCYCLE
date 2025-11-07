class EwasteItem {
  final int id;
  final String itemName;
  final String description;
  final String location;
  final String status;
  final String imageUrl;
  final String? assignedTo;
  final DateTime createdAt;

  EwasteItem({
    required this.id,
    required this.itemName,
    required this.description,
    required this.location,
    required this.status,
    required this.imageUrl,
    this.assignedTo,
    required this.createdAt,
  });

  factory EwasteItem.fromJson(Map<String, dynamic> json) => EwasteItem(
        id: json['id'] as int,
        itemName: json['item_name'] ?? '',
        description: json['description'] ?? '',
        location: json['location'] ?? '',
        status: json['status'] ?? 'Pending',
        imageUrl: json['image_url'] ?? '',
        assignedTo: json['assigned_to'],
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}
