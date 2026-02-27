# Admin Quick Reference - Volunteer Assignment

## 🎯 Quick Steps

1. **Click "Assign Volunteer"** on any pending item
2. **Click a volunteer card** to select them (turns blue)
3. **Click a date** from their available dates
4. **See confirmation** in the blue "Selected:" box
5. **Click green "Assign Volunteer"** button
6. ✅ **Done!** Item assigned with closest NGO auto-selected

## 📍 Key Elements in Dialog

```
[Title] Schedule Volunteer by Available Dates

┌─ VOLUNTEER LIST ─────────────────────────┐
│ (Scrollable)                             │
│ 👤 Volunteer Name                        │
│    Available on: [Date1] [Date2]        │
│                                          │
│ 👤 Another Volunteer                     │
│    Available on: [Date3] [Date4]        │
└──────────────────────────────────────────┘

┌─ SELECTION SUMMARY ──────────────────────┐ ← Appears when you select
│ 👤 Raj Kumar                             │   both volunteer & date
│ 📅 Thursday, Feb 10, 2026                │
└──────────────────────────────────────────┘

[Cancel]  [✓ Assign Volunteer] ← Button here!
```

## ✨ What Gets Assigned

When you click the button:

| What          | How                                       |
| ------------- | ----------------------------------------- |
| **Volunteer** | Selected from the list                    |
| **Date**      | Selected from volunteer's available dates |
| **NGO**       | Closest match to user's location ✓ AUTO   |
| **Time**      | 9:00 AM on selected date                  |
| **Status**    | Changed to "assigned"                     |

## 🔍 NGO Selection Works Like This

```
User's Location: "Sector 5, Delhi"

Available NGOs:
1. "Sector 5 Eco Center, Delhi"     ✓ MATCH: Sector 5 + Delhi
2. "Sector 10 Center, Delhi"        ✓ MATCH: Delhi only
3. "Mumbai Center"                  ✗ NO MATCH

RESULT: Sector 5 Eco Center is assigned!
```

## ⚠️ Common Mistakes

❌ **"Button is grayed out!"**

- Need to select BOTH volunteer and date
- The blue selection box must show below the list

❌ **"I can't find the button!"**

- It's in the bottom right corner
- Only appears after you select volunteer + date

❌ **"Wrong NGO was assigned!"**

- Make sure item's location is entered correctly
- Make sure NGO addresses include the area/district
- The system does string matching on location parts

## 🎁 Success Indicators

You'll see a green notification showing:

```
✓ Assignment Successful!
Volunteer: [Name]
Date: [Full Date]
Assigned NGO: [NGO Name]
```

This means:

- ✅ Volunteer is assigned
- ✅ Pickup date is set
- ✅ NGO center is assigned
- ✅ Item status is "assigned"
- ✅ Volunteer will see in their dashboard

## 📋 Dialog Button States

| Condition               | Button | State                  |
| ----------------------- | ------ | ---------------------- |
| No selection            | Assign | ⚫ Disabled (grayed)   |
| Only volunteer selected | Assign | ⚫ Disabled (grayed)   |
| Only date selected      | Assign | ⚫ Disabled (grayed)   |
| Both selected           | Assign | 🟢 Enabled (clickable) |

## 🚀 Pro Tips

✅ **Scroll through volunteers** to see all available  
✅ **Check dates carefully** - shows "days from now"  
✅ **Read the selection box** - confirms your choice  
✅ **Look for success message** - confirms completion  
✅ **Update NGO addresses** - helps with location matching

## 🔧 How Location Matching Works

The system tries to match the user's location with NGO addresses:

```
Split by comma → Count matching parts → Highest count wins
"Sector 5, Delhi" → ["Sector 5", "Delhi"] → NGO score = 2
"Delhi Center" → ["Delhi"] → Score = 1
Winner: Sector 5 address!
```

## 📞 Troubleshooting

| Problem                   | Check                                    |
| ------------------------- | ---------------------------------------- |
| Button not visible        | Did you select volunteer + date?         |
| Selection box not showing | Try clicking volunteer first, then date  |
| Wrong NGO assigned        | Update NGO addresses to include location |
| Assignment failed         | Check internet, try again                |

---

**Pro Tip:** Always check the green "Selected:" box before clicking Assign!
