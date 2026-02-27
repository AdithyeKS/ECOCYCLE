import 'package:ecocycle/models/cloth_item.dart';
import 'package:flutter/foundation.dart';

void main() {
  final item1 = ClothItem(
    userId: 'user1',
    type: 'Apparel',
    quantity: 1,
    condition: 'Good',
    location: 'Test Location',
    createdAt: DateTime.now(),
  );

  final item2 = ClothItem(
    userId: 'user1',
    type: 'Linen',
    quantity: 5,
    condition: 'Fair',
    location: 'Test Location',
    createdAt: DateTime.now(),
  );

  debugPrint('Item 1 Description: ${item1.description}');
  debugPrint('Item 2 Description: ${item2.description}');

  if (item1.description == '1 item - Good condition' &&
      item2.description == '5 items - Fair condition') {
    debugPrint('SUCCESS: Description updated correctly.');
  } else {
    debugPrint('FAILURE: Description update failed.');
  }
}
