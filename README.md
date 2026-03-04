# Tally Calendar

A minimal Android app for daily tally tracking with a colour-coded heatmap calendar view.

Built with Flutter. Data is stored locally on the device — no account, no cloud, no tracking.

---

## Features

| Feature | Details |
|---|---|
| 📅 **Heatmap calendar** | Each day is colour-coded green → yellow → red based on its tally relative to the highest day in the displayed month |
| ➕➖ **Increment / decrement** | One-tap ± buttons on the day detail screen |
| 🔢 **Direct entry** | Type any non-negative integer directly into the tally field |
| 💬 **Comments** | Free-text note per day (no length limit) |
| 📤 **CSV export** | Exports all entries as `date,tally,comment` via the OS share sheet |
| 🕕 **"Logical today"** | The app treats the day as not having rolled over until 06:00, so night-owls still see yesterday highlighted |
| 💾 **Local SQLite storage** | All data lives in a single `tally_calendar.db` file on the device |

---

## Install

Download the latest APK from the [Releases](https://github.com/Clark-Bott/tally-calendar/releases) page and sideload it:

1. Transfer the `.apk` file to your Android device.
2. Open the file in a file manager.
3. If prompted, enable *Install from unknown sources* for your file manager app.
4. Follow the on-screen prompts.

> **Minimum Android version:** Android 6.0 (API 23)

---

## Usage

### Calendar view

The app opens on the current month with today's cell outlined in teal.

- **Navigate months** — tap `‹` / `›` in the header.
- **Open a day** — tap any cell.
- **Export data** — tap the ⬇ icon in the top-right corner.

### Heatmap colours

Colours are computed relative to the **highest tally in the current month**, not an absolute scale:

| Colour | Meaning |
|---|---|
| Grey | No entry (tally == 0, no comment) |
| Green | Low tally (≤ 50 % of month max) |
| Yellow | Mid tally (~50 % of month max) |
| Red | High tally (≈ 100 % of month max) |

A legend strip at the bottom of the screen shows the full scale.

### Day detail screen

Tap any cell to open that day's editing screen.

- **`−` button** — decrement by 1 (floor: 0).
- **`+` button** — increment by 1.
- **Number field** — type a value and tap **Set** (or submit via keyboard) to jump to a specific number.
- **Comment field** — multi-line free text.
- **Save** — commits changes to the database and returns to the calendar. Also accessible from the AppBar.
- **Back (OS button)** — discards unsaved changes.

> If you save a day with tally = 0 and no comment, the entry is deleted from the database. The day appears grey on the calendar.

### "Logical today" behaviour

The app uses a 06:00 cutoff for the day boundary. If the current time is before 06:00, the *previous* calendar day is highlighted as today. This affects only the teal border highlight; you can always navigate to any day freely.

### CSV export

Tap the ⬇ icon to export all data. The OS share sheet opens, letting you save the file, send it to another app, or share it.

**CSV format:**
```
date,tally,comment
2024-03-01,3,"went for a run"
2024-03-03,1,
2024-03-15,7,"best day this month"
```

- One row per day (only days with a non-zero tally or a comment are exported).
- Rows are sorted by date ascending.
- Columns: `date` (ISO-8601), `tally` (integer), `comment` (string, may be empty).

---

## Data & Privacy

All data is stored in SQLite on your device at the standard Android app data path:

```
/data/data/com.example.tally_calendar/databases/tally_calendar.db
```

Nothing is transmitted externally. Uninstalling the app deletes all data (standard Android behaviour); back up via CSV export before uninstalling.

---

## Project structure

```
tally-calendar/
├── lib/
│   ├── main.dart             # Entry point, app root widget
│   ├── models.dart           # DayEntry data class
│   ├── database_helper.dart  # SQLite CRUD via sqflite
│   ├── calendar_screen.dart  # Main screen: heatmap grid + navigation
│   └── day_detail_screen.dart# Edit screen: tally +/-, comment, save
├── android/                  # Android-specific build files
├── pubspec.yaml              # Flutter dependencies
└── DEVELOPMENT.md            # Build instructions & architecture notes
```

---

## Contributing

Bug reports and pull requests are welcome. See [DEVELOPMENT.md](DEVELOPMENT.md) for setup instructions.
