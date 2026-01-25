class PlasticItem {
  final String id;
  final String userId;
  final String plasticType; // e.g., PET, HDPE, PVC
  final String itemName;
  final String description;
  final String location;
  final String? imageUrl;
  final String status;
  final int points;
  final DateTime createdAt;

  PlasticItem({
    required this.id,
    required this.userId,
    required this.plasticType,
    required this.itemName,
    required this.description,
    required this.location,
    this.imageUrl,
    this.status = 'pending',
    this.points = 0,
    required this.createdAt,
  });

  factory PlasticItem.fromJson(Map<String, dynamic> json) => PlasticItem(
    id: json['id'],
    userId: json['user_id'],
    plasticType: json['plastic_type'],
    itemName: json['item_name'],
    description: json['description'],
    location: json['location'],
    imageUrl: json['image_url'],
    status: json['status'],
    points: json['points'] ?? 0,
    createdAt: DateTime.parse(json['created_at']),
  );
}