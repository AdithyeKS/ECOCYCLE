class EwasteCategory {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final double pricePerKg;

  const EwasteCategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.pricePerKg = 0,
  });

  factory EwasteCategory.fromJson(Map<String, dynamic> json) => EwasteCategory(
        id: json['id'].toString(),
        name: json['name'] as String,
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        pricePerKg: (json['price_per_kg'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': int.parse(id),
        'name': name,
        'description': description,
        'icon': icon,
        'price_per_kg': pricePerKg,
      };
}

final List<EwasteCategory> ewasteCategories = [
  EwasteCategory(
    id: '1',
    name: 'TVs & Monitors',
    description:
        'Electronic devices for visual display including TVs, monitors, and digital frames.',
    icon: '📺',
    pricePerKg: 15.0,
  ),
  EwasteCategory(
    id: '2',
    name: 'Mobile Devices',
    description:
        'Portable communication and computing devices like phones, tablets, and watches.',
    icon: '📱',
    pricePerKg: 20.0,
  ),
  EwasteCategory(
    id: '3',
    name: 'Computers',
    description:
        'Desktop and laptop computers, servers, and all-in-one systems.',
    icon: '💻',
    pricePerKg: 25.0,
  ),
  EwasteCategory(
    id: '4',
    name: 'Home Appliances',
    description:
        'Large household electronic appliances like refrigerators and washing machines.',
    icon: '🏠',
    pricePerKg: 10.0,
  ),
  EwasteCategory(
    id: '5',
    name: 'Computer Peripherals',
    description:
        'Accessories for computers including keyboards, mice, printers, and scanners.',
    icon: '🖱️',
    pricePerKg: 12.0,
  ),
  EwasteCategory(
    id: '6',
    name: 'Entertainment',
    description: 'Gaming consoles, DVD players, audio systems, and speakers.',
    icon: '🎮',
    pricePerKg: 18.0,
  ),
  EwasteCategory(
    id: '7',
    name: 'Batteries',
    description:
        'Rechargeable batteries for laptops, phones, UPS, and power banks.',
    icon: '🔋',
    pricePerKg: 30.0,
  ),
  EwasteCategory(
    id: '8',
    name: 'Other Electronics',
    description:
        'Miscellaneous electronic items like cables, chargers, and small appliances.',
    icon: '⚡',
    pricePerKg: 8.0,
  ),
];
