# Quick Reference - Waste Item Scheduling System

## Three Waste Types Supported

### 1. E-waste Items

- **Database**: `ewaste_items` table
- **Model**: `EwasteItem`
- **Service**: `EwasteService`
- **ID Type**: UUID
- **Fields**: itemName, description, plasticType, etc.

### 2. Plastic Items

- **Database**: `plastic_items` table
- **Model**: `PlasticItem` ✅ UPDATED
- **Service**: `PlasticService` ✅ UPDATED
- **ID Type**: UUID
- **Fields**: plasticType, itemName, description, etc.
- **New Fields**: assignedAgentId, assignedNgoId, pickupScheduledAt

### 3. Cloth Items

- **Database**: `cloth_donations` table
- **Model**: `ClothItem` ✅ UPDATED
- **Service**: `ClothService` ✅ UPDATED
- **ID Type**: INT (SERIAL)
- **Fields**: type, quantity, condition, etc.
- **New Fields**: assignedAgentId, assignedNgoId, pickupScheduledAt

## Required Service Methods

Every waste item service must implement these four methods:

```dart
Future<void> assignPickupAgent(String itemId, String agentId)
Future<void> updateStatus(String itemId, String newStatus)
Future<void> schedulePickup(String itemId, DateTime pickupDate)
Future<void> assignNgo(String itemId, String ngoId)
```

✅ **Compliance Status**:

- EwasteService: All 4 implemented ✅
- PlasticService: All 4 implemented ✅
- ClothService: All 4 implemented ✅

## Adding a New Waste Type

To add support for a new waste type (e.g., E-ink displays):

### Step 1: Create Model

```dart
// lib/models/edisplay_item.dart
class EdisplayItem {
  final String id;
  final String userId;
  final String type;
  final String location;
  final DateTime createdAt;
  final String? assignedAgentId;    // REQUIRED
  final String? assignedNgoId;      // REQUIRED
  final DateTime? pickupScheduledAt; // REQUIRED

  factory EdisplayItem.fromJson(Map<String, dynamic> json) => EdisplayItem(
    // Map database columns to fields
    assignedAgentId: json['assigned_agent_id'],
    assignedNgoId: json['assigned_ngo_id'],
    pickupScheduledAt: json['pickup_scheduled_for'] != null
        ? DateTime.parse(json['pickup_scheduled_for'])
        : null,
    // ... other fields
  );
}
```

### Step 2: Create Service

```dart
// lib/services/edisplay_service.dart
class EdisplayService {
  final supabase = AppSupabase.client;

  Future<List<EdisplayItem>> fetchAll() async {
    // Fetch from database
  }

  Future<void> assignPickupAgent(String itemId, String agentId) async {
    await supabase.from('edisplay_items').update({
      'assigned_agent_id': agentId,
      'delivery_status': 'assigned',
    }).eq('id', itemId);
  }

  Future<void> updateStatus(String itemId, String newStatus) async {
    await supabase.from('edisplay_items').update({
      'status': newStatus,
    }).eq('id', itemId);
  }

  Future<void> schedulePickup(String itemId, DateTime pickupDate) async {
    await supabase.from('edisplay_items').update({
      'pickup_scheduled_for': pickupDate.toIso8601String(),
      'delivery_status': 'scheduled',
    }).eq('id', itemId);
  }

  Future<void> assignNgo(String itemId, String ngoId) async {
    await supabase.from('edisplay_items').update({
      'assigned_ngo_id': ngoId,
    }).eq('id', itemId);
  }
}
```

### Step 3: Update Admin Dashboard

```dart
// lib/screens/admin_dashboard.dart

// Initialize service
final _edisplayService = EdisplayService();

// Add to data fetch
final edisplayItems = await _edisplayService.fetchAll();

// Add to pending requests
for (final item in edisplayItems.where(...)) {
  pendingItems.add({
    'type': 'edisplay',
    'item': item,
    'service': _edisplayService,
  });
}
```

### Step 4: Database Schema

```sql
CREATE TABLE edisplay_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  type TEXT NOT NULL,
  location TEXT NOT NULL,
  assigned_agent_id UUID REFERENCES profiles(id),
  assigned_ngo_id UUID REFERENCES ngos(id),
  pickup_scheduled_for TIMESTAMP,
  delivery_status TEXT DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW(),
  ...
);
```

**That's it!** The admin dashboard code is generic enough to handle any number of waste types.

## Common Issues & Solutions

### Issue: Item doesn't appear in pending requests

**Solution**: Check `item.deliveryStatus == 'pending'` at line 570 in admin_dashboard.dart

### Issue: Schedule button doesn't work

**Solution**: Verify service has all four required methods

### Issue: Scheduled date not displaying in volunteer dashboard

**Solution**: Check `item.pickupScheduledAt` field is populated (check model fromJson)

### Issue: NGO not assigned automatically

**Solution**: Verify `_findClosestNgoByLocation()` method and NGO list is populated

### Issue: Volunteer not seeing task

**Solution**: Check volunteer ID matches `assignedAgentId` in database

## File Locations Quick Reference

```
lib/
├── models/
│   ├── ewaste_item.dart          ✅ Complete
│   ├── plastic_item.dart         ✅ Updated (3 fields added)
│   └── cloth_item.dart           ✅ Updated (3 fields added)
├── services/
│   ├── ewaste_service.dart       ✅ Complete
│   ├── plastic_service.dart      ✅ Updated (6 methods added)
│   └── cloth_service.dart        ✅ Updated (1 method added)
└── screens/
    └── admin_dashboard.dart       ✅ No changes needed (generic)
```

## Debugging Tips

### Check if service is being called

Add breakpoints in:

- `lib/services/plastic_service.dart` → `assignPickupAgent()`
- `lib/services/plastic_service.dart` → `schedulePickup()`
- `lib/services/cloth_service.dart` → `assignPickupAgent()`
- `lib/services/cloth_service.dart` → `schedulePickup()`

### Check if database is being updated

Query the database directly:

```sql
SELECT assigned_agent_id, assigned_ngo_id, pickup_scheduled_for
FROM plastic_items
WHERE id = 'your-item-id';

SELECT assigned_agent_id, assigned_ngo_id, pickup_scheduled_at
FROM cloth_donations
WHERE id = 'your-item-id';
```

### Check volunteer dashboard display

Search for "NGO Delivery Location" in:

- `lib/screens/volunteer_dashboard.dart` (around line 1570)

## Related Documentation

- [PLASTIC_CLOTH_SCHEDULING_FIX_COMPLETE.md](PLASTIC_CLOTH_SCHEDULING_FIX_COMPLETE.md) - Complete implementation guide
- [PLASTIC_CLOTH_SCHEDULING_VERIFICATION.md](PLASTIC_CLOTH_SCHEDULING_VERIFICATION.md) - Detailed verification
- Admin Dashboard Code: `lib/screens/admin_dashboard.dart` (5222 lines)
- Volunteer Dashboard Code: `lib/screens/volunteer_dashboard.dart`

## Maintenance Notes

When updating volunteer assignment logic:

1. Update `_showVolunteerSelectionDialog()` in admin_dashboard.dart
2. Change will apply to ALL three waste types automatically
3. No need to update individual services if using the same flow

When adding new item field:

1. Add field to all three models (maintain consistency)
2. Update database schema for all three tables
3. Update fromJson() methods in all models
4. Services automatically pick up changes via database queries

## Version History

- **v1.0**: E-waste items with volunteer scheduling
- **v1.1**: Added auto-NGO assignment for all types
- **v1.2**: ✅ Added plastic/cloth item scheduling support
  - PlasticItem: Added 3 fields
  - ClothItem: Added 3 fields
  - PlasticService: Added 6 methods
  - ClothService: Added 1 method
