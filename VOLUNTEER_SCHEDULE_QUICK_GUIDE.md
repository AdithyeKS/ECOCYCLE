# Volunteer Schedule - Quick Start Guide

## What Was Fixed? ✅

The calendar date selection in the volunteer dashboard's "Schedules" tab is now fully clickable. You can now select dates like February 8th to manage your availability.

## How to Use Your Availability Calendar

### 1. **Open the Dashboard**

- Log in as a volunteer
- Navigate to the **"Schedules"** tab

### 2. **Click a Date** (This now works!)

- Click on any **future date** in the calendar (e.g., Feb 8, 2026)
- You'll see a dialog asking about your availability for that date

### 3. **Mark as Available**

- Click **"I am Available"** button (green)
- The date will turn green on the calendar
- The system saves your availability to the database

### 4. **Remove Availability** (Optional)

- For dates you've already marked available
- Click the date again
- Click **"Remove Schedule"** button (red)
- The green highlight is removed

## Admin Assignment Workflow

When an admin assigns you a task:

### Step 1: Admin Selects Item

- Admin clicks "Assign Volunteer" on a pickup item

### Step 2: Admin Selects You + Date

- Admin sees your name with your available dates
- Admin clicks on your available dates (e.g., Feb 8)
- Your card shows "Selected" status

### Step 3: Admin Clicks "Assign Volunteer"

- ✅ **Automatic NGO Assignment**: The system finds the closest NGO center based on the pickup location
- System creates the assignment
- Success message shows which NGO was assigned

## Key Features

| Feature                 | What it does                                                  |
| ----------------------- | ------------------------------------------------------------- |
| **Calendar View**       | See all your available dates at a glance (green = available)  |
| **Date Selection**      | Click any future date to toggle availability                  |
| **Auto NGO Assignment** | When admin assigns you, nearest NGO is automatically selected |
| **Confirmation Dialog** | Always confirms your availability change before saving        |

## Calendar Color Meanings

- 🟢 **Green** - You marked yourself as available
- ⚪ **Light Gray** - You didn't mark this date as available
- 🔵 **Blue Border** - Currently selected date
- 🟢 **Green Border** - Today's date

## Troubleshooting

### "I can't click the dates!"

- ✅ This is now fixed! Try clicking any future date
- Make sure you're clicking directly on the date number
- You cannot select past dates (yesterday or earlier)

### "My availability isn't showing up for Admin"

- Click the date and confirm "I am Available"
- Wait for the dialog to close
- The green highlight should appear
- Admin will see your availability in the next 14 days

### "The wrong NGO was assigned"

- Each waste item has a location (e.g., "Sector 5, Delhi")
- The system matches this with NGO addresses
- Most specific match wins (e.g., "Sector 5" in both = match)
- If no match, first available NGO is assigned

## Calendar Rules

✅ **Can do:**

- Select any date from today onwards
- Select up to 90 days in the future
- Mark multiple dates as available
- Remove availability from marked dates

❌ **Cannot do:**

- Select past dates (yesterday or earlier)
- The system will skip them automatically

## Need Help?

If dates still aren't clickable:

1. Close and reopen the app
2. Log out and log back in
3. Check that you're in the "Schedules" tab (not "Assignments" or "Overview")
4. Try clicking directly on the date number

---

**Last Updated:** February 2026  
**Related Documentation:** [VOLUNTEER_SCHEDULE_DATE_SELECTION_FIX.md](VOLUNTEER_SCHEDULE_DATE_SELECTION_FIX.md)
