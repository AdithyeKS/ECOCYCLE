# Admin Dashboard - Quick Start Guide

## How to Access the Admin Dashboard

1. **Login with Admin Credentials**
   - Go to the login screen
   - Enter your admin email and password
   - You'll be routed to the Admin Dashboard

2. **Dashboard Tabs**
   - **Dispatch Tab**: Manage e-waste item dispatch and assignment
   - **Volunteer Tab**: Review and approve/reject volunteer applications
   - **Logistics Tab**: Assign volunteers to items with date scheduling
   - **Users Tab**: Manage user roles, view profiles, and delete accounts

## Key Features

### 📊 Dashboard Header Statistics

- Shows 9 key performance metrics in real-time
- Scroll horizontally to see all metrics
- Each metric has a color, icon, and label

### 🚚 Dispatch Tab

**What it does**: Manage e-waste items from submission to delivery

**Features**:

- View all e-waste items with images
- See contributor name and location
- Filter by search query
- View status breakdown (Pending/Assigned/Collected/Delivered)
- Assign items to pickup agents
- Assign items to NGOs
- Update status as items move through workflow

**How to use**:

1. Search for items or contributors using the search bar
2. Expand an item to see full details
3. For Pending items: Select an agent and NGO, click "Confirm Dispatch"
4. For Assigned items: Click "Confirm Collection" when collected
5. For Collected items: Confirm delivery to NGO

### 👥 Volunteer Tab

**What it does**: Manage volunteer applications

**Features**:

- See statistics of pending, approved, and rejected applications
- View complete volunteer application details
- See policy agreement status
- View motivation text
- Approve or reject applications with one click

**How to use**:

1. Scroll through pending applications
2. Review applicant details and motivation
3. Click "Approve" to add as volunteer agent
4. Click "Reject" to decline application

### 📅 Logistics Tab

**What it does**: Schedule and assign volunteers to items

**Features**:

- Select a date for assignment
- View pending items awaiting assignment
- See available volunteers for the selected date
- Assign volunteers to items

**How to use**:

1. Use the date picker to select an assignment date (or click "Today")
2. Select a pending item from the list
3. View available volunteers
4. Click "Assign" to assign a volunteer to the item

### 👤 Users Tab

**What it does**: Manage all users in the system

**Features**:

- View statistics (Admins/Agents/Volunteers/Users)
- Search for specific users
- View detailed user information
- Change user roles
- Delete user accounts
- See EcoPoints earned by each user

**How to use**:

1. Use search bar to find users
2. Expand a user card to see full details
3. Use dropdown to change their role
4. Click "Delete Account" to remove a user (with confirmation)

## 🎨 UI Features

### Dark/Light Mode

- Click the moon/sun icon in the top-right to toggle dark mode
- Settings are applied immediately

### Search Functionality

- Available in Dispatch and Users tabs
- Searches across names, items, and locations
- Updates results as you type

### Role-Based Colors

- 🔴 Red = Admin
- 🔵 Blue = Agent
- 🟢 Green = Volunteer
- ⚪ Gray = Regular User

### Status Colors

- 🟠 Orange = Pending
- 🔵 Blue = Assigned
- 🔷 Cyan = Collected
- 🟢 Green = Delivered

## 🔍 Debugging Data Issues

If data isn't loading:

1. **Check Console Logs**:
   - Open Developer Tools (F12 or Ctrl+Shift+I)
   - Go to Console tab
   - Look for messages starting with 📊, ✓, or ✗
   - These show what data is loading and any errors

2. **Common Issues**:
   - **No data showing**: Check internet connection
   - **Partial data**: Some services might be slow, wait a moment
   - **Error messages**: Read the specific error in the SnackBar

3. **Log Message Examples**:
   ```
   📊 [AdminDashboard] Starting data fetch...
   ✓ E-waste items loaded: 24
   ✓ User profiles loaded: 156
   ✗ Error fetching volunteer schedules: Network timeout
   ```

## 📋 Common Tasks

### Assign an Item for Pickup

1. Go to **Dispatch Tab**
2. Find the item in Pending status
3. Expand it
4. Select a volunteer from "Select Volunteer"
5. Select an NGO from "Select NGO Target"
6. Click "Confirm Dispatch"

### Approve a Volunteer Application

1. Go to **Volunteer Tab**
2. Find the application in the list
3. Review the details and motivation
4. Click "Approve" button
5. User will be added as a volunteer agent

### Create a Schedule for Volunteers

1. Go to **Logistics Tab**
2. Select a date using the date picker
3. See available volunteers for that date
4. Select a pending item
5. Click "Assign" next to volunteer
6. Task will be created and scheduled

### Change a User's Role

1. Go to **Users Tab**
2. Search for the user
3. Expand their card
4. Click the role dropdown
5. Select new role
6. Role updates immediately

### Delete a User Account

1. Go to **Users Tab**
2. Find the user
3. Expand their card
4. Click "Delete Account" button
5. Confirm the deletion
6. User and all their data will be permanently removed

## ⚡ Performance Tips

- The dashboard loads all data when you enter
- To refresh data, navigate to another tab and back
- Search updates instantly as you type
- Data is cached in memory while dashboard is open

## 🐛 Report Issues

When reporting issues, include:

1. What you were trying to do
2. What error message you saw (if any)
3. Console logs (if available)
4. Your browser and device info
5. Screenshot if possible

---

**Need Help?** Check the ADMIN_PAGE_IMPROVEMENTS.md file for technical details.
