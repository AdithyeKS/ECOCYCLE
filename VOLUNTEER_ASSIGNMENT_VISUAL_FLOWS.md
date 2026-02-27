# Volunteer Assignment System - Visual Flow Diagrams

## 🎯 Overall System Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    ECOCYCLE VOLUNTEER SYSTEM                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────┐         ┌──────────────────────┐      │
│  │  VOLUNTEER SIDE      │         │   ADMIN SIDE         │      │
│  │  (Dashboard)         │         │   (Dashboard)        │      │
│  │                      │         │                      │      │
│  │ ┌─────────────────┐  │         │ ┌─────────────────┐  │      │
│  │ │ Schedules Tab   │  │         │ │ Pending Items   │  │      │
│  │ │                 │  │         │ │ E-Waste/Plastic │  │      │
│  │ │ [Calendar]      │  │         │ │ Cloth/etc       │  │      │
│  │ │  Click dates➜   │  │         │ │                 │  │      │
│  │ │  Mark available │  │         │ │ [Assign Vol]    │  │      │
│  │ │  Green highlight│  │         │ │                 │  │      │
│  │ └─────────────────┘  │         │ └─────────────────┘  │      │
│  │                      │         │                      │      │
│  │ ┌─────────────────┐  │         │ ┌─────────────────┐  │      │
│  │ │ Assignments Tab │  │         │ │ Volunteer List  │  │      │
│  │ │                 │  │         │ │ Dialog          │  │      │
│  │ │ Shows tasks:    │  │         │ │                 │  │      │
│  │ │ [Accept]        │  │         │ │ [Select vol]    │  │      │
│  │ │ [Decline]       │  │         │ │ [Select date]   │  │      │
│  │ │ [Collect]       │  │         │ │ [Summary box]   │  │      │
│  │ │ [Deliver]       │  │         │ │ [Assign button] │  │      │
│  │ └─────────────────┘  │         │ └─────────────────┘  │      │
│  │                      │         │                      │      │
│  └──────────────────────┘         └──────────────────────┘      │
│              │                              │                   │
│              │ (Availability dates)         │ (Select +        │
│              │ (Accept/Decline)             │  Assign)         │
│              │                              │                   │
│              └──────────────────┬───────────┘                   │
│                                 │                               │
│                    ┌────────────▼────────────┐                 │
│                    │  SUPABASE DATABASE     │                 │
│                    │                        │                 │
│                    │ volunteer_schedules    │                 │
│                    │ volunteer_assignments  │                 │
│                    │ ewaste_items (updated) │                 │
│                    │ ngos (queried)         │                 │
│                    └────────────┬───────────┘                 │
│                                 │                               │
│                    ┌────────────▼────────────┐                 │
│                    │   NGO AUTO-ASSIGNMENT   │                 │
│                    │                        │                 │
│                    │ Match location:        │                 │
│                    │ "Sector 5, Delhi" →    │                 │
│                    │ Sector 5 Center ✓      │                 │
│                    └────────────────────────┘                 │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## 📅 Volunteer Availability Calendar

### Calendar Cell Interaction

```
User sees calendar with dates:
┌─ February 2026 ──────────┐
│ Mo Tu We Th Fr Sa Su     │
│        1  2  3  4  5     │
│  6  7  8  9 10 11 12     │
│ 13 14 15 16 17 18 19     │
│ 20 21 22 23 24 25 26     │
│ 27 28                    │
└──────────────────────────┘

User CLICKS on Feb 8:
           ↓
GestureDetector.onTap triggers
           ↓
_showAvailabilityDialog() called
           ↓
Dialog appears with options:
┌─ Manage Schedule: Feb 8 ──┐
│ Would you like to mark    │
│ yourself as available?    │
│                           │
│ [✓ I am Available] (GREEN)│
│ [✗ Remove Schedule] (RED) │
│ [Cancel]                  │
└───────────────────────────┘

User clicks "I am Available":
           ↓
setAvailability() called
           ↓
Database saved:
- volunteer_id: user-id
- date: 2026-02-08
- is_available: true
           ↓
Calendar updates:
Date shows GREEN highlight
✓ Success message
```

## 👤 Admin Volunteer Selection

### Dialog Structure

```
┌─ Schedule Volunteer by Available Dates ─────────────────┐
│                                                         │
│ ┌─ VOLUNTEERS LIST (Scrollable) ──────────────────┐   │
│ │                                                  │   │
│ │ [Card 1 - Not Selected]                         │   │
│ │ ┌──────────────────────────────────────────────┐│   │
│ │ │ 👤 Raj Kumar (Gray background)               ││   │
│ │ │    Phone: 9876543210                         ││   │
│ │ │ Available on:                                ││   │
│ │ │ [Feb 08] [Feb 10] [Feb 15]                  ││   │
│ │ └──────────────────────────────────────────────┘│   │
│ │                                                  │   │
│ │ [Card 2 - Currently Selected] ← CLICK THIS     │   │
│ │ ┌──────────────────────────────────────────────┐│   │
│ │ │ 👤 Priya Singh (BLUE background, highlighted)││   │
│ │ │    Phone: 9876543211                         ││   │
│ │ │ Available on:                                ││   │
│ │ │ [Feb 09] [Feb 14✓] [...]                    ││   │
│ │ └──────────────────────────────────────────────┘│   │
│ │                                                  │   │
│ │ [Card 3 - Not Selected]                         │   │
│ │ ┌──────────────────────────────────────────────┐│   │
│ │ │ 👤 Anuj Patel (Gray background)              ││   │
│ │ │    Phone: 9876543212                         ││   │
│ │ │ Available on:                                ││   │
│ │ │ [Feb 12] [Feb 20]                           ││   │
│ │ └──────────────────────────────────────────────┘│   │
│ │                                                  │   │
│ │ (... more volunteers if available)              │   │
│ └──────────────────────────────────────────────────┘   │
│                                                         │
│ ┌─ SELECTION SUMMARY (Appears when BOTH selected) ──┐ │
│ │ 👤 Priya Singh                                   │ │
│ │ 📅 Thursday, Feb 14, 2026                        │ │
│ └────────────────────────────────────────────────────┘ │
│                                                         │
│ [Cancel]               [✓ Assign Volunteer] ← GREEN    │
│                              (Only shows when both     │
│                               volunteer + date chosen) │
└─────────────────────────────────────────────────────────┘
```

## 🎯 Assignment Flow - Step by Step

### Complete User Journey

```
STEP 1: ADMIN CLICKS "ASSIGN VOLUNTEER"
┌──────────────────────────────┐
│ Pending Item                 │
│ 📦 Laptop for Recycling      │
│ 📍 Sector 5, Delhi           │
│ [Assign Volunteer] ◄─ CLICK  │
└──────────────────────────────┘
           │
           ▼ (Dialog opens with loading state)

STEP 2: DIALOG SHOWS VOLUNTEERS
┌─ VOLUNTEER LIST ──────────────┐
│ [Fetching volunteers...]      │
│ (Loading spinner)             │
│ Later:                        │
│ ✓ Raj Kumar                   │
│ ✓ Priya Singh                 │
│ ✓ Anuj Patel                  │
└───────────────────────────────┘

STEP 3: ADMIN SELECTS VOLUNTEER
┌─ VOLUNTEER LIST ──────────────┐
│ ✓ Raj Kumar (unselected)      │
│ ✓ PRIYA SINGH (SELECTED!)     │ ◄─ Card highlights blue
│   Avatar: Blue circle         │
│   Available on:               │
│   [Feb 09] [Feb 14] [...]     │
│ ✓ Anuj Patel (unselected)     │
└───────────────────────────────┘
           │
           ▼ (No summary yet)

STEP 4: ADMIN CLICKS A DATE
┌─ VOLUNTEER LIST ──────────────┐
│ ✓ PRIYA SINGH (SELECTED)      │
│   Available on:               │
│   [Feb 09] [Feb 14✓] [...]    │ ◄─ Date turns GREEN
└───────────────────────────────┘

STEP 4b: SELECTION SUMMARY APPEARS
┌─ Selected: ─────────────────────┐
│ 👤 Priya Singh                  │
│ 📅 Thursday, Feb 14, 2026       │ ◄─ Shows confirmation
└─────────────────────────────────┘

STEP 5: ADMIN CLICKS ASSIGN BUTTON
┌──────────────────────────────────────┐
│ [Cancel] [✓ Assign Volunteer]        │
│                                       │ ◄─ Button enabled
│                                       │    and visible
└──────────────────────────────────────┘
           │
           ▼ (Processing...)

STEP 6: BACKEND PROCESSING
System finds closest NGO:
User location: "Sector 5, Delhi"
Available NGOs:
├─ "Sector 5 Eco Center, Delhi" ← MATCH SCORE: 2 ✓ SELECTED
├─ "Sector 10 Center, Delhi"    ← MATCH SCORE: 1
└─ "Delhi Center"               ← MATCH SCORE: 0

Creates assignment:
├─ volunteer_id: priya-singh-123
├─ item_id: laptop-2026-001
├─ scheduled_date: 2026-02-14
├─ status: pending
└─ assigned_ngo: sector-5-center

Updates item:
├─ delivery_status: assigned
├─ assigned_agent_id: priya-singh-123
├─ assigned_ngo_id: sector-5-center
└─ pickup_scheduled_at: 2026-02-14 09:00:00

STEP 7: SUCCESS MESSAGE APPEARS
┌─ Green Notification ───────────┐
│ ✓ Assignment Successful!       │
│                                │
│ Volunteer: Priya Singh         │
│ Date: Feb 14, 2026             │
│ Assigned NGO: Sector 5 Center  │
│                                │
│ (Disappears after 4 seconds)   │
└────────────────────────────────┘

STEP 8: ITEM STATUS UPDATED IN DASHBOARD
Pending Item → NOW SHOWS AS ASSIGNED
┌──────────────────────────────┐
│ Assigned Item                │
│ 📦 Laptop for Recycling      │
│ 📍 Sector 5, Delhi           │
│ ✓ Assigned to: Priya Singh   │
│ 📅 Date: Feb 14, 2026        │
│ 🏢 NGO: Sector 5 Center      │
└──────────────────────────────┘

STEP 9: VOLUNTEER SEES ASSIGNMENT
Volunteer Dashboard → Assignments Tab
┌──────────────────────────────┐
│ New Assignment!              │
│ 📦 Laptop for Recycling      │
│ 📍 Sector 5, Delhi           │
│ 📅 Feb 14, 2026              │
│ 🏢 NGO: Sector 5 Center      │
│                              │
│ [Accept] [Decline]           │
└──────────────────────────────┘
```

## 🔄 NGO Auto-Assignment Logic

### Location Matching Algorithm

```
USER LOCATION:
"Sector 5, Delhi, India"
        ↓
SPLIT BY COMMA:
["Sector 5", " Delhi", " India"]
        ↓
SEARCH ALL NGOS:

NGO 1: "Sector 5 Eco Center, Delhi"
Split: ["Sector 5 Eco Center", " Delhi"]
Matches: "Sector 5" ✓, " Delhi" ✓
SCORE: 2 ⭐⭐

NGO 2: "Sector 10 Center, Delhi"
Split: ["Sector 10 Center", " Delhi"]
Matches: " Delhi" ✓
SCORE: 1 ⭐

NGO 3: "Mumbai Center"
Split: ["Mumbai Center"]
Matches: None
SCORE: 0

NGO 4: "Delhi Recycling Hub"
Split: ["Delhi Recycling Hub"]
Matches: None (different format)
SCORE: 0
        ↓
WINNER: NGO 1 (Score 2)
"Sector 5 Eco Center, Delhi"
        ↓
ASSIGNED TO ITEM ✓
```

### Alternative Scenario - No Exact Match

```
USER LOCATION:
"Raj Nagar, Ghaziabad"
        ↓
SEARCH ALL NGOS:

NGO 1: "Raj Nagar Recycling Hub"
Matches: "Raj Nagar" ✓
SCORE: 1

NGO 2: "Delhi Center"
Matches: None
SCORE: 0

NGO 3: "Ghaziabad Center"
Matches: "Ghaziabad" ✓ (but not in user location)
SCORE: 1 (tie)
        ↓
WINNER: First with highest score
"Raj Nagar Recycling Hub"
        ↓
ASSIGNED ✓
```

### Fallback - No Matches Found

```
USER LOCATION:
"Unknown/Empty"
        ↓
NO MATCHES FOUND
(All scores = 0)
        ↓
FALLBACK RULE:
Use first available NGO
        ↓
ASSIGNED: NGO 1 from list ✓
(with warning logged)
```

## 📊 Data Flow Diagram

```
┌────────────────────────────────────────────────────┐
│            VOLUNTEER ASSIGNMENT DATA FLOW          │
└────────────────────────────────────────────────────┘

STEP 1: VOLUNTEER MARKS AVAILABILITY
┌──────────────────────────┐
│ volunteer_dashboard.dart │
│ _setAvailability()       │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────────────────────┐
│ volunteer_schedule_service.dart          │
│ setAvailability(volunteerId, date, true) │
└───────────┬──────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────┐
│ Supabase: volunteer_schedules TABLE      │
│ INSERT/UPDATE:                           │
│ ├─ volunteer_id                          │
│ ├─ date                                  │
│ ├─ is_available: true                    │
│ └─ created_at/updated_at                 │
└──────────────────────────────────────────┘

STEP 2: ADMIN VIEWS AVAILABLE VOLUNTEERS
┌──────────────────────────────┐
│ admin_dashboard.dart         │
│ _showVolunteerSelectionDialog│
│ (itemData, date)             │
└───────────┬──────────────────┘
            │
            ▼
┌──────────────────────────────────────┐
│ Query Supabase:                      │
│ SELECT volunteer_id, date            │
│ FROM volunteer_schedules             │
│ WHERE is_available = true            │
│ AND date >= NOW                      │
│ AND date <= NOW + 14 days            │
└───────────┬──────────────────────────┘
            │
            ▼
┌──────────────────────────────────┐
│ Build volunteer_with_dates list: │
│ {                                │
│   volunteer: PickupAgent,       │
│   availableDates: [Date1,...]   │
│ }                                │
└──────────────────────────────────┘

STEP 3: ADMIN ASSIGNS VOLUNTEER
┌──────────────────────────────┐
│ AlertDialog.actions:         │
│ ElevatedButton("Assign")     │
│ onPressed: () async { ... }  │
└───────────┬──────────────────┘
            │
            ▼ (Get selected values)
┌──────────────────────────────┐
│ selectedVolunteerId (String) │
│ selectedScheduleDate (Date)  │
│ item.location (String)       │
└───────────┬──────────────────┘
            │
            ▼
┌──────────────────────────────────────┐
│ _findClosestNgoByLocation()          │
│ Inputs: item.location                │
│ Algorithm: Match location strings    │
│ Output: closestNgo: Ngo object      │
└───────────┬──────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────┐
│ Create Assignment in Database:           │
│ volunteer_assignments.insert({           │
│   volunteer_id: selectedVolunteerId,     │
│   item_id: item.id,                     │
│   task_type: type,                      │
│   scheduled_date: selectedScheduleDate, │
│   status: pending,                      │
│   assigned_ngo: closestNgo.id           │
│ })                                       │
└───────────┬──────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────┐
│ Update Item Status:                      │
│ ewaste_items.update({                    │
│   delivery_status: assigned,             │
│   assigned_agent_id: volunteerId,        │
│   assigned_ngo_id: closestNgo.id,       │
│   pickup_scheduled_at: pickupDateTime    │
│ })                                       │
└───────────┬──────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────┐
│ Show Success Message:                    │
│ SnackBar with:                          │
│ ├─ "Assignment Successful!"             │
│ ├─ Volunteer.name                       │
│ ├─ Scheduled date (formatted)           │
│ └─ closestNgo.name                      │
└──────────────────────────────────────────┘

STEP 4: VOLUNTEER SEES ASSIGNMENT
┌──────────────────────────────┐
│ volunteer_dashboard.dart     │
│ _buildAssignmentsTab()       │
│ fetchVolunteerAssignments()  │
└───────────┬──────────────────┘
            │
            ▼
┌──────────────────────────────────────┐
│ Query Supabase:                      │
│ SELECT * FROM volunteer_assignments  │
│ WHERE volunteer_id = currentUser     │
│ AND status IN (pending, assigned)    │
└───────────┬──────────────────────────┘
            │
            ▼
┌──────────────────────────────────────┐
│ Display in Assignments Tab:          │
│ ├─ Item details (from ewaste_items)  │
│ ├─ Scheduled date                    │
│ ├─ Assigned NGO                      │
│ └─ Action buttons:                   │
│    [Accept] [Decline]                │
└──────────────────────────────────────┘
```

## ✨ Success Indicators

### Volunteer Successfully Marked Availability

```
✓ Date turns GREEN in calendar
✓ "Success" message appears
✓ Database has volunteer_schedules entry
```

### Admin Successfully Assigned Volunteer

```
✓ Dialog closes
✓ Green success notification appears (4 sec)
✓ Shows: Volunteer name + Date + NGO name
✓ Item status in dashboard changes to "assigned"
✓ Database has volunteer_assignments entry
```

### Volunteer Receives Assignment

```
✓ "Assignments" tab shows new item
✓ Can see assigned date
✓ Can see assigned NGO center
✓ Can accept or decline
```

---

**Complete system flows and verified working! ✅**
