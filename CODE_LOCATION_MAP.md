# 🗺️ ADMIN DASHBOARD - CODE LOCATION MAP

## Where Everything Is Located

---

## 📂 File Structure

```
lib/
├── screens/
│   └── admin_dashboard.dart ⭐ MAIN FILE
│       ├── Dispatch Tab (Enhanced)
│       ├── Volunteer Tab (Fixed)
│       ├── User Management Tab (NEW)
│       ├── Search Bar
│       └── Helper Methods
│
├── services/
│   └── profile_service.dart ✅ (Already Fixed)
│       └── decideOnApplication() - Volunteer Approval
│
└── models/
    ├── ewaste_item.dart
    ├── volunteer_application.dart
    └── ... (other models)

📁 Root/
├── SUPABASE_ADMIN_COMPLETE_SETUP.sql ⭐ (Deploy this)
├── ADMIN_DASHBOARD_SETUP_GUIDE.md (Full guide)
├── ADMIN_QUICK_START.md (Quick reference)
└── ADMIN_IMPLEMENTATION_FINAL.md (This file)
```

---

## 🧩 Code Locations - admin_dashboard.dart

### 1. Imports & Class Definition

```dart
// Lines 1-40: Imports and StatefulWidget setup
import 'package:flutter/material.dart';
import '../models/ewaste_item.dart';
import '../services/profile_service.dart';
// ... other imports

class AdminDashboard extends StatefulWidget {
  // ...
}

class _AdminDashboardState extends State<AdminDashboard> {
  // State variables
}
```

### 2. State Variables

```dart
// Lines 30-50: All state variables
List<EwasteItem> ewasteItems = [];
List<Map<String, dynamic>> allProfiles = [];
List<VolunteerApplication> volunteerApps = [];
Map<String, String> userNames = {};
String _searchQuery = '';
bool _isDarkMode = true;
```

### 3. Data Fetching

```dart
// Lines 70-125: fetchAllData() method
Future<void> fetchAllData() async {
  final results = await Future.wait([
    _ewasteService.fetchAll(),          // 0: e-waste items
    _ewasteService.fetchNgos(),         // 1: NGOs
    _ewasteService.fetchPickupAgents(), // 2: agents
    _profileService.fetchAllProfiles(), // 3: profiles/users
    _profileService.fetchAllApplications(), // 4: volunteer apps
    _scheduleService.fetchAllSchedules(),   // 5: schedules
  ], eagerError: false);
  // ... Process and set state
}
```

### 4. Main Build Method

```dart
// Lines 155-210: build() method
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(...),
    body: isLoading
        ? CircularProgressIndicator()
        : RefreshIndicator(
            onRefresh: fetchAllData,
            child: Column(
              children: [
                // SEARCH BAR (Lines 167-195)
                Container(
                  padding: EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users, items, emails...',
                      // ...
                    ),
                  ),
                ),
                // TAB CONTENT
                Expanded(child: _buildTabContent(cardColor)),
              ],
            ),
          ),
    bottomNavigationBar: BottomNavigationBar(...),
  );
}
```

### 5. Tab Content Router

```dart
// Lines 232-245: _buildTabContent() method
Widget _buildTabContent(Color cardColor) {
  switch (_selectedTab) {
    case AdminTab.dispatch:
      return _buildDispatchTab(cardColor);        // ⭐ DISPATCH TAB
    case AdminTab.volunteer:
      return _buildGatekeeperTab(cardColor);      // ⭐ VOLUNTEER TAB
    case AdminTab.logistics:
      return _buildLogisticsTab(cardColor);
    case AdminTab.users:
      return _buildUsersTab(cardColor);           // ⭐ USER MANAGEMENT
    case AdminTab.settings:
      return _buildSettingsTab(cardColor);
  }
}
```

### 6. DISPATCH TAB - Enhanced UI ⭐

```dart
// Lines 430-590: _buildDispatchTab() method
Widget _buildDispatchTab(Color cardColor) {
  // ✨ Features:
  // - Shows item image, username, product name
  // - 🏢 Assign to NGO button
  // - 👤 Assign to Agent button
  // - 📊 Change Status button
  // - Search filtering

  return ListView.builder(
    itemBuilder: (context, index) {
      final item = filteredItems[index];
      final userName = userNames[item.userId];

      return Card(
        child: Column(
          children: [
            // Item image + username + product name
            Row(
              children: [
                // Image
                ClipRRect(
                  child: Image.network(item.imageUrl),
                ),
                // Username + Product
                Column(
                  children: [
                    Text('👤 $userName'),
                    Text(item.itemName),
                  ],
                ),
              ],
            ),
            // Action buttons
            Row(
              children: [
                ElevatedButton.icon(
                  label: Text('NGO'),
                  onPressed: () => _showNgoSelectionDialog(),
                ),
                ElevatedButton.icon(
                  label: Text('Agent'),
                  onPressed: () => _showAgentSelectionDialog(),
                ),
                ElevatedButton.icon(
                  label: Text('Status'),
                  onPressed: () => _showStatusChangeDialog(item),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

// Helper: _buildStatusBadge() - Lines ~505
Widget _buildStatusBadge(String status) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _getStatusColor(status).withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(status.toUpperCase()),
  );
}

// Helper: _showStatusChangeDialog() - Lines ~570
void _showStatusChangeDialog(EwasteItem item) {
  // Opens dialog to change status
}

// Helper: _buildEmptyState() - Lines ~540
Widget _buildEmptyState(String message, IconData icon) {
  // Shows "No data" state
}
```

### 7. VOLUNTEER TAB - Fixed ⭐

```dart
// Lines 810-910: _buildGatekeeperTab() method
Widget _buildGatekeeperTab(Color cardColor) {
  // ✨ Features:
  // - Shows pending applications
  // - ✅ Approve button (FIXED - now works!)
  // - ❌ Reject button
  // - Status badges

  return ListView.builder(
    itemBuilder: (context, index) {
      final app = sortedApps[index];

      return Card(
        child: Column(
          children: [
            // Application info
            Row(
              children: [
                CircleAvatar(),
                Column(
                  children: [
                    Text(app.fullName),
                    Text(DateFormat('MMM d, yyyy').format(app.availableDate)),
                  ],
                ),
              ],
            ),
            // Motivation
            Text('Motivation:'),
            Text(app.motivation),
            // Contact info
            Text('Email: ${app.email}'),
            Text('Phone: ${app.phone}'),
            // Action buttons (if pending)
            if (app.status == 'pending')
              Row(
                children: [
                  OutlinedButton(
                    label: Text('Reject'),
                    onPressed: () => _handleAppDecision(app, false),
                  ),
                  FilledButton(
                    label: Text('Approve'), // ⭐ FIXED - NOW WORKS
                    onPressed: () => _handleAppDecision(app, true),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
```

### 8. USER MANAGEMENT TAB - NEW ⭐

```dart
// Lines 1080-1350: _buildUsersTab() method
Widget _buildUsersTab(Color cardColor) {
  // ✨ Features:
  // - Shows all users with roles
  // - 🔄 Change Role button (user/volunteer only)
  // - 🗑️ Delete button
  // - 🔒 Admin protection
  // - Search filtering

  return ListView.builder(
    itemBuilder: (context, index) {
      final profile = filteredProfiles[index];
      final isAdmin = profile['user_role'] == 'admin';

      return Card(
        decoration: BoxDecoration(
          gradient: isAdmin
            ? [Colors.red[50], Colors.red[100]]
            : [Colors.white, Colors.grey[50]],
        ),
        child: Column(
          children: [
            // User info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isAdmin ? Colors.red : Colors.blue,
                  child: Text(profile['full_name'][0]),
                ),
                Column(
                  children: [
                    Text(profile['full_name']),
                    Text(profile['email']),
                  ],
                ),
              ],
            ),
            // Action buttons
            if (!isAdmin)
              Row(
                children: [
                  ElevatedButton.icon(
                    label: Text('Role'),
                    onPressed: () => _showRoleChangeDialog(userId, role),
                  ),
                  ElevatedButton.icon(
                    label: Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _confirmDeleteUser(userId, fullName),
                  ),
                ],
              )
            else
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.red[400]),
                    Text('Admin accounts cannot be modified'),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

// Helper: _confirmDeleteUser() - Lines ~1175
Future<void> _confirmDeleteUser(String userId, String userName) async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('⚠️ Delete User'),
      content: Column(
        children: [
          Text('Are you sure you want to delete $userName?'),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red[300]),
            ),
            child: Text('⚠️ This action CANNOT be undone.'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            await _deleteUser(userId, userName);
          },
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Delete User'),
        ),
      ],
    ),
  );
}

// Helper: _deleteUser() - Lines ~1220
Future<void> _deleteUser(String userId, String userName) async {
  // Delete from profiles table
  await AppSupabase.client.from('profiles').delete().eq('id', userId);

  // Delete auth account
  await AppSupabase.client.auth.admin.deleteUser(userId);

  // Refresh data
  await fetchAllData();
}

// Helper: _showRoleChangeDialog() - Lines ~1280
Future<void> _showRoleChangeDialog(String userId, String currentRole) async {
  // Only shows: user, volunteer (NOT admin/agent)
  final allowedRoles = ['user', 'volunteer'];

  showDialog(
    builder: (context) => AlertDialog(
      title: Text('Change User Role'),
      content: Column(
        children: allowedRoles
          .map((role) => RadioListTile<String>(
            title: Text(role.toUpperCase()),
            value: role,
            groupValue: selectedRole,
            onChanged: (value) => selectedRole = value,
          ))
          .toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await _profileService.updateUserRole(userId, selectedRole);
            await fetchAllData();
            Navigator.pop(context);
          },
          child: Text('Update'),
        ),
      ],
    ),
  );
}
```

### 9. Dialog & Selection Methods

```dart
// Lines ~615-680: _showAgentSelectionDialog()
Future<String?> _showAgentSelectionDialog() async {
  // Dialog showing list of pickup agents
  // User selects one, returns agent.id
}

// Lines ~685-750: _showNgoSelectionDialog()
Future<String?> _showNgoSelectionDialog() async {
  // Dialog showing list of NGOs
  // User selects one, returns ngo.id
}
```

### 10. Action Methods

```dart
// Lines ~125-145: _updateStatus() method
Future<void> _updateStatus(String itemId, String newStatus, String agentId) async {
  // Updates delivery status
  // Refreshes data
}

// Lines ~145-160: _assignTask() method
Future<void> _assignTask(String itemId, String? agentId, String? ngoId) async {
  // Assigns item to agent or NGO
  // Refreshes data
}

// Lines ~160-170: _handleAppDecision() method
Future<void> _handleAppDecision(VolunteerApplication app, bool approve) async {
  // Calls ProfileService.decideOnApplication()
  // Shows success/error message
  // Refreshes data
}
```

### 11. Utility Methods

```dart
// Lines ~600-610: _getStatusColor() method
Color _getStatusColor(String status) {
  // Returns color for status badge
  // pending: orange, assigned: blue, collected: green, delivered: purple
}

// Lines ~750-760: _getRoleColor() method
Color _getRoleColor(String role) {
  // Returns color for role badge
  // admin: red, agent: blue, volunteer: green, user: grey
}

// Lines ~1350-1400: _showUserDetailsDialog() method
void _showUserDetailsDialog(Map<String, dynamic> profile) {
  // Shows user information in dialog
}

// Lines ~1400-1420: _detailRow() widget
Widget _detailRow(String label, String value) {
  // Helper to display label: value pairs
}

// Lines ~1425-1440: _showSuccess() method
void _showSuccess(String msg) {
  // Shows green SnackBar with message
}

// Lines ~1440-1450: _showError() method
void _showError(String msg) {
  // Shows red SnackBar with error
}

// Lines ~1450-1470: _logout() method
Future<void> _logout() async {
  // Signs out user
  // Navigates to login screen
}

// Lines ~250-320: _buildModernHeader() method
Widget _buildModernHeader() {
  // Shows dashboard statistics
  // Pending items, assigned, collected, delivered, etc.
}

// Lines ~320-365: _buildStatCard() method
Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  // Individual stat card widget
}
```

---

## 📍 profile_service.dart - decideOnApplication()

```dart
// Lines 173-220: decideOnApplication() method
Future<void> decideOnApplication(
    String appId, String userId, bool approve) async {
  final newStatus = approve ? 'approved' : 'rejected';
  final newRole = approve ? 'volunteer' : 'user';  // ⭐ KEY FIX

  // Update application status
  await supabase.from('volunteer_applications')
      .update({'status': newStatus}).eq('id', appId);

  // Update user role
  await supabase.from('profiles').update({
    'user_role': newRole,
    'volunteer_requested_at': null,
  }).eq('id', userId);

  // Create pickup_requests entry (non-blocking)
  if (approve) {
    try {
      await supabase.from('pickup_requests').insert({
        'agent_id': userId,      // ⭐ Correct field name
        'name': profile?['full_name'] ?? 'Volunteer',
        'phone': profile?['phone_number'] ?? 'N/A',
        'email': profile?['email'] ?? 'N/A',
        'is_active': true,
      });
    } catch (e) {
      print('Note: Could not create pickup_request: $e');
    }
  }
}
```

---

## 📊 Supabase Setup Files

### SUPABASE_ADMIN_COMPLETE_SETUP.sql

```sql
-- Lines 1-40: check_is_admin() function
CREATE FUNCTION check_is_admin() RETURNS BOOLEAN
  -- Returns TRUE if user is admin
  -- Used in all RLS policies

-- Lines 45-120: PROFILES table RLS policies
-- SELECT for all
-- UPDATE own + UPDATE admin
-- DELETE admin

-- Lines 125-165: VOLUNTEER_APPLICATIONS table RLS policies
-- SELECT admin + SELECT own
-- UPDATE admin
-- INSERT own

-- Lines 170-215: EWASTE_ITEMS table RLS policies
-- SELECT admin + SELECT own
-- INSERT auth
-- UPDATE admin + UPDATE own

-- Lines 220-255: PICKUP_REQUESTS table RLS policies
-- SELECT admin + SELECT own
-- INSERT admin
-- UPDATE admin + UPDATE own
-- DELETE admin

-- Lines 260-300: NGOs, AGENTS, SCHEDULES RLS policies
-- Similar pattern for each table
```

---

## 🎯 Quick Navigation

| Feature             | File                              | Method                  | Lines     |
| ------------------- | --------------------------------- | ----------------------- | --------- |
| **Dispatch Tab**    | admin_dashboard.dart              | `_buildDispatchTab()`   | 430-590   |
| **User Management** | admin_dashboard.dart              | `_buildUsersTab()`      | 1080-1350 |
| **Delete User**     | admin_dashboard.dart              | `_deleteUser()`         | 1220-1270 |
| **Volunteer Apps**  | admin_dashboard.dart              | `_buildGatekeeperTab()` | 810-910   |
| **Approval Logic**  | profile_service.dart              | `decideOnApplication()` | 173-220   |
| **Search Bar**      | admin_dashboard.dart              | `build()`               | 167-195   |
| **RLS Setup**       | SUPABASE_ADMIN_COMPLETE_SETUP.sql | All                     | 1-282     |

---

## 🔍 Finding Things Quickly

**"How do I find the delete user code?"**
→ Look in `_buildUsersTab()` method for the Delete button

**"Where is the volunteer approval happening?"**
→ `_handleAppDecision()` calls `ProfileService.decideOnApplication()`

**"How does role-based access work?"**
→ `check_is_admin()` function in SQL + RLS policies

**"Where's the search implementation?"**
→ In `build()` method, uses `_searchController` and `_searchQuery`

**"Which method shows the NGO dialog?"**
→ `_showNgoSelectionDialog()` returns selected NGO ID

**"How does dispatch assignment work?"**
→ `_assignTask()` method calls service layer

---

## ✅ Code Quality

- ✅ No syntax errors
- ✅ All methods properly typed
- ✅ All callbacks connected
- ✅ All imports present
- ✅ Proper error handling
- ✅ Clean code structure
- ✅ Well-commented critical sections
- ✅ No undefined references

---

**Last Updated:** Today
**Status:** ✅ COMPLETE & READY FOR DEPLOYMENT
