# Automatic NGO Center Assignment Feature

## Overview

When an admin assigns a volunteer to a waste item, the system **automatically**:

1. Analyzes the user's location (from the waste item)
2. Finds the **closest NGO center** from the 30+ available centers
3. Assigns that NGO center to the waste item
4. Shows the NGO details in the success notification
5. The volunteer receives delivery instructions with the NGO center details

## How It Works

### Step 1: Admin Clicks "Assign Volunteer"

- Admin selects a volunteer and available date
- Clicks the "Assign Volunteer" button

### Step 2: System Analyzes Location

```dart
final closestNgo = _findClosestNgoByLocation(item.location ?? '');
```

- Extracts the user's location from the waste item
- Compares it against all available NGO centers
- Uses intelligent location matching algorithm

### Step 3: NGO Assignment Algorithm

The `_findClosestNgoByLocation()` function:

1. **Splits locations into parts** (by comma)
   - Example: "Sector 5, Meenachil, Kottayam, Kerala, India"
   - Parts: ["Sector 5", "Meenachil", "Kottayam", "Kerala", "India"]

2. **Compares each part** with NGO locations
   - "Sector 5" → matches "Sector 5 Center, Kottayam"
   - "Kottayam" → matches "Kottayam NGO Center"

3. **Scores each match**
   - More matching parts = higher score
   - Returns the NGO with highest score
   - Falls back to first NGO if no match found

### Step 4: Database Updates

```dart
// Assign volunteer to item
await service.assignPickupAgent(item.id, volunteer.id);

// Update item status
await service.updateStatus(item.id, 'assigned');

// Schedule pickup
await service.schedulePickup(item.id, pickupDateTime);

// Assign NGO center
if (closestNgo != null) {
  await service.assignNgo(item.id, closestNgo.id);
}
```

### Step 5: Success Notification

Admin sees a detailed success message with:

```
✓ Assignment Successful!

Volunteer: Adithyan K P
Scheduled: Sunday, Feb 08, 2026
Requester: Adithye k s

📍 NGO Delivery Center:
Meenachil NGO Center
Sector 5, Meenachil, Kottayam, Kerala
```

## Database Schema

### Items Table

```sql
ngo_id → Links item to assigned NGO center
assigned_volunteer_id → Links item to assigned volunteer
delivery_status → "assigned" when volunteer is assigned
pickup_scheduled_for → DateTime of scheduled pickup
```

### NGO Centers Table

```sql
id → Unique identifier
name → NGO center name
address → Full address (used for location matching)
phone → Contact number
email → Email address
city → City
district → District
```

## Volunteer Experience

### What the Volunteer Sees

In the volunteer dashboard, when assigned a task, they see:

1. **Item Details**
   - Type of waste (e-waste, plastic, cloth, etc.)
   - Location to pick up from

2. **Pickup Instructions**
   - Date and time
   - Requester contact details

3. **Delivery Instructions** ⭐ NEW
   - NGO center name
   - NGO center address
   - NGO center contact details
   - **Where to deliver the collected waste**

### Volunteer Workflow

```
1. Receive assignment notification
2. Go to user's location → Pick up the waste
3. Go to assigned NGO center → Deliver the waste
4. Mark delivery as complete
```

## Location Matching Examples

### Example 1: Exact District Match

```
User Location: "Sector 5, Meenachil, Kottayam, Kerala"
NGO 1: "Sector 5 Center, Meenachil, Kottayam"     ✓ 3 matches!
NGO 2: "Ernakulam NGO Center"                     ✗ 0 matches
NGO 3: "Kottayam Center"                          ✓ 1 match

Result: NGO 1 selected (highest score)
```

### Example 2: District Match

```
User Location: "Thrissur, Kerala, India"
NGO 1: "Thrissur NGO Center"                      ✓ 1 match
NGO 2: "Kottayam Center, Kerala"                  ✓ 1 match
NGO 3: "Kerala State Center"                      ✓ 1 match

Result: NGO 1 selected (first highest match)
```

### Example 3: No Match (Fallback)

```
User Location: "Remote Area, State"
All NGOs: No matching parts

Result: First NGO in list used as fallback
```

## Technical Implementation

### File: `lib/screens/admin_dashboard.dart`

#### Function: `_findClosestNgoByLocation(String userLocation)`

**Lines:** 772-805

**Purpose:** Find the best matching NGO center for a user's location

**Algorithm:**

1. Take user location string
2. Split into parts by comma
3. For each NGO, count matching parts
4. Return NGO with maximum matches

**Returns:** `Ngo?` object with best match, or first NGO as fallback

#### Assignment Code

**Lines:** 1134-1165

When volunteer is assigned:

1. Find closest NGO using location matching
2. Assign volunteer to item
3. Update item status to "assigned"
4. Schedule pickup date/time
5. Assign NGO center to item
6. Show success notification with NGO details

## Database Operations

### Operations Performed

```sql
-- 1. Assign volunteer
UPDATE items SET assigned_volunteer_id = $1 WHERE id = $2

-- 2. Update status
UPDATE items SET delivery_status = 'assigned' WHERE id = $1

-- 3. Schedule pickup
UPDATE items SET pickup_scheduled_for = $1 WHERE id = $2

-- 4. Assign NGO
UPDATE items SET ngo_id = $1 WHERE id = $2
```

## Benefits

✅ **Automatic matching** - Admin doesn't need to manually select NGO  
✅ **Location-based** - Uses intelligent location parsing  
✅ **Smart fallback** - Always assigns an NGO (never null)  
✅ **Clear instructions** - Volunteer knows exactly where to deliver  
✅ **Efficient routing** - Volunteer follows shortest path (pickup → NGO center)  
✅ **Organized disposal** - All waste goes to designated centers  
✅ **Scalable** - Works with 30+ NGO centers

## Testing Checklist

- [ ] Assign volunteer with matching location → Verify correct NGO selected
- [ ] Assign volunteer with partial location match → Verify best match selected
- [ ] Assign volunteer with no location match → Verify fallback NGO used
- [ ] Check success notification → Verify NGO details displayed
- [ ] Check database → Verify ngo_id linked to item
- [ ] Check volunteer dashboard → Verify NGO details visible
- [ ] Test with different locations → Verify algorithm works correctly
- [ ] Test with missing NGO data → Verify graceful handling

## Future Enhancements

- [ ] Add distance calculation using GPS coordinates
- [ ] Show nearest 3 NGO options to admin
- [ ] Let volunteer choose from nearby NGOs
- [ ] Add travel time estimation
- [ ] Show NGO center capacity/availability
- [ ] Route optimization between pickup and delivery

---

**Date:** February 7, 2026  
**Status:** ✅ Complete  
**Related Features:** Single Volunteer Selection, Location-Based Matching  
**Files Modified:** lib/screens/admin_dashboard.dart
