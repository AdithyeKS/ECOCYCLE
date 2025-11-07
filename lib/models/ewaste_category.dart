class EwasteCategory {
  final String id;
  final String name;
  final String icon;
  final List<String> examples;

  const EwasteCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.examples,
  });
}

final List<EwasteCategory> ewasteCategories = [
  EwasteCategory(
    id: 'tv',
    name: 'TVs & Monitors',
    icon: '📺',
    examples: [
      'LCD/LED TVs',
      'CRT Monitors',
      'Computer Monitors',
      'Digital Photo Frames'
    ],
  ),
  EwasteCategory(
    id: 'mobile',
    name: 'Mobile Devices',
    icon: '📱',
    examples: ['Smartphones', 'Tablets', 'Feature Phones', 'Smart Watches'],
  ),
  EwasteCategory(
    id: 'computer',
    name: 'Computers',
    icon: '💻',
    examples: ['Laptops', 'Desktops', 'All-in-One PCs', 'Servers'],
  ),
  EwasteCategory(
    id: 'appliances',
    name: 'Home Appliances',
    icon: '🏠',
    examples: [
      'Washing Machines',
      'Refrigerators',
      'Air Conditioners',
      'Microwaves'
    ],
  ),
  EwasteCategory(
    id: 'peripherals',
    name: 'Computer Peripherals',
    icon: '🖱️',
    examples: ['Keyboards', 'Mice', 'Printers', 'Scanners'],
  ),
  EwasteCategory(
    id: 'entertainment',
    name: 'Entertainment',
    icon: '🎮',
    examples: [
      'Gaming Consoles',
      'DVD/Blu-ray Players',
      'Audio Systems',
      'Speakers'
    ],
  ),
  EwasteCategory(
    id: 'batteries',
    name: 'Batteries',
    icon: '🔋',
    examples: [
      'Laptop Batteries',
      'Phone Batteries',
      'UPS Batteries',
      'Power Banks'
    ],
  ),
  EwasteCategory(
    id: 'other',
    name: 'Other Electronics',
    icon: '⚡',
    examples: ['Cables', 'Chargers', 'Electronic Toys', 'Small Appliances'],
  ),
];
