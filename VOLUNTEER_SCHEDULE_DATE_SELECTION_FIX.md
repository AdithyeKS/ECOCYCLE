# Volunteer Schedule Date Selection Fix

## Problem Description

The volunteer dashboard's "Set Your Availability" calendar was not clickable. Users couldn't select dates (e.g., February 8th) to mark their availability because the calendar cells were not responding to tap gestures.

## Root Cause

The custom calendar cell builder in [volunteer_dashboard.dart](lib/screens/volunteer_dashboard.dart) was returning a `Container` widget without any gesture detection. While the `TableCalendar` widget has built-in tap handling via the `onDaySelected` callback, the custom cell builders override the default appearance and were not wrapping the content in a clickable widget (like `GestureDetector` or `InkWell`).

## Solution Implemented

### Fixed Code Location

**File:** [lib/screens/volunteer_dashboard.dart](lib/screens/volunteer_dashboard.dart) - `_calendarCellBuilder()` method (lines 1156-1201)

### What Was Changed

Wrapped the calendar cell `Container` with a `GestureDetector` that:

1. **Handles tap events**: `onTap` callback triggers when a date is clicked
2. **Shows the availability dialog**: Calls `_showAvailabilityDialog()` to let the volunteer mark themselves as available
3. **Respects disabled dates**: Prevents taps on past dates and disabled dates
4. **Updates UI state**: Updates `_selectedDay` and `_focusedDay` to show visual feedback

### Code Modification

```dart
// Before: Plain Container (NOT TAPPABLE)
return Container(
  margin: const EdgeInsets.all(4),
  decoration: BoxDecoration(...),
  child: Center(child: Text('${day.day}')),
);

// After: GestureDetector + Container (TAPPABLE)
return GestureDetector(
  onTap: isDisabled ? null : () {
    final normalizedSelection = _normalizeDate(day);
    if (normalizedSelection.isBefore(today)) return;

    setState(() {
      _selectedDay = normalizedSelection;
      _focusedDay = day;
    });
    _showAvailabilityDialog(normalizedSelection);
  },
  child: Container(
    // ... decoration and child remain the same
  ),
);
```

## User Flow After Fix

### Step 1: Volunteer Opens Schedule Tab

- Volunteer navigates to the "Schedules" tab in the dashboard
- A calendar widget is displayed with "Set Your Availability" heading

### Step 2: Volunteer Selects a Date (NOW WORKS!)

- Volunteer **clicks/taps on February 8th** (or any future date)
- The date cell is now clickable thanks to the `GestureDetector`
- Visual feedback shows the selected date with a blue border

### Step 3: Dialog Opens

- The `_showAvailabilityDialog()` shows two buttons:
  - **"I am Available"** (Green button) - Marks the date as available
  - **"Remove Schedule"** (Red button, if applicable) - Removes the availability

### Step 4: Availability Saved

- Clicking "I am Available" calls `_setAvailability()` which:
  - Sends the date to the database via `volunteer_schedule_service.setAvailability()`
  - Updates the `volunteer_schedules` table
  - Refreshes the calendar to show the green highlight on that date

### Step 5: Admin Views Available Volunteers

- When admin views "Schedule Volunteer by Available Dates" in admin dashboard
- The admin can see which volunteers are available on which dates
- Admin selects a volunteer and date pair

### Step 6: Admin Assigns Volunteer (Auto NGO Selection)

- Admin clicks the **"Assign Volunteer"** button
- The system automatically:
  1. **Finds the closest NGO**: Using `_findClosestNgoByLocation()` which matches the pickup location with NGO addresses
  2. **Creates the assignment**: Records volunteer assignment in `volunteer_assignments` table
  3. **Updates status**: Changes item status to "assigned"
  4. **Schedules the pickup**: Records the pickup datetime
  5. **Assigns NGO**: Links the closest NGO center to the pickup task
- A success message shows: `"Assigned [Volunteer Name] for [Date]. Closest NGO: [NGO Name]"`

## Technical Details

### NGO Auto-Assignment Algorithm

The `_findClosestNgoByLocation()` function in [admin_dashboard.dart](lib/screens/admin_dashboard.dart) (line 755):

1. **Takes the user's location** from the waste item
2. **Splits both location strings** by commas (location hierarchy: e.g., "Street, District, City")
3. **Counts matching parts** between user location and each NGO address
4. **Selects NGO** with the highest match count
5. **Fallback**: If no matches, assigns the first available NGO

### Database Schema

The assignment flow involves these tables:

- **volunteer_schedules** - Stores volunteer availability dates
- **volunteer_assignments** - Records which volunteer is assigned to which item and date
- **ewaste_items** (or similar) - Stores the pickup item with location and NGO assignment
- **ngos** - Stores NGO center details including addresses

## Testing Steps

### Test Case 1: Date Selection

1. Open volunteer dashboard
2. Go to "Schedules" tab
3. **Click on any future date** (e.g., Feb 8, 2026)
4. ✅ Verify: Dialog appears asking about availability

### Test Case 2: Mark as Available

1. Complete Test Case 1
2. Click **"I am Available"** button
3. ✅ Verify: Dialog closes and date shows green highlight in calendar

### Test Case 3: Admin Auto-NGO Assignment

1. Create an e-waste item with location "Sector 5, Delhi, India"
2. Set up an NGO with address containing "Delhi" or "Sector 5"
3. Click "Assign Volunteer" after selecting a volunteer and date
4. ✅ Verify: Success message shows correct NGO name
5. ✅ Verify: Database shows NGO linked to the item

## Files Modified

- [lib/screens/volunteer_dashboard.dart](lib/screens/volunteer_dashboard.dart) - Added `GestureDetector` to `_calendarCellBuilder()`

## Related Functions

- `_showAvailabilityDialog()` - Shows the availability confirmation dialog
- `_setAvailability()` - Saves availability to database
- `_findClosestNgoByLocation()` - Auto-selects closest NGO
- `_showVolunteerSelectionDialog()` - Shows available volunteers for admin to select

## Potential Future Enhancements

1. **GPS-based location matching** - Instead of string matching for NGO location
2. **Distance calculation** - Use actual coordinates if available
3. **Volunteer preference** - Let volunteers prefer certain NGO centers
4. **Multiple assignment** - Allow assigning multiple volunteers for high-priority items
5. **Notification system** - Notify volunteer and NGO when assignment is made
