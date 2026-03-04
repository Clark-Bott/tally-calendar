/// Calendar home screen for Tally Calendar.
///
/// This file contains:
/// - [getLogicalToday] — timezone-aware "current day" helper (rolls back
///   before 06:00).
/// - [formatDate] — canonical ISO-8601 date formatter.
/// - [heatmapColor] — maps a tally value to a heatmap colour.
/// - [CalendarScreen] / [_CalendarScreenState] — the main screen widget.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'database_helper.dart';
import 'models.dart';
import 'day_detail_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns the "logical today" for the app.
///
/// The app treats the day as not having rolled over until **06:00**. This
/// means that at e.g. 01:30 on March 4th, this function returns March 3rd,
/// keeping the previous day active for late-night users.
///
/// ### Why 06:00?
/// Most people who are still awake before 6 am consider it "still last
/// night". The cutoff is hard-coded; no user preference exists yet.
///
/// ### Boundary conditions
/// - Exactly at midnight (00:00) → previous calendar day.
/// - At 05:59 → previous calendar day.
/// - At 06:00 → current calendar day.
/// - Any hour ≥ 6 → current calendar day.
///
/// [DateTime.now()] is used, so the result follows the device's local
/// timezone. There is no UTC conversion.
DateTime getLogicalToday() {
  final now = DateTime.now();
  if (now.hour < 6) {
    return DateTime(now.year, now.month, now.day - 1);
  }
  return DateTime(now.year, now.month, now.day);
}

/// Formats a [DateTime] as an ISO-8601 date string (`YYYY-MM-DD`).
///
/// This is the canonical format used as the primary key in SQLite and in
/// exported CSV files. Always zero-padded.
///
/// Example: `formatDate(DateTime(2024, 3, 5))` → `"2024-03-05"`
String formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Maps a [tally] value to a heatmap colour relative to [maxTally].
///
/// ### Colour scale
/// The scale is a two-stage linear interpolation:
///
/// | Range          | From colour        | To colour          |
/// |----------------|--------------------|--------------------|
/// | 0 – 50 % max   | Green (0,180,0)    | Yellow (255,220,0) |
/// | 50 – 100 % max | Yellow (255,220,0) | Red (220,0,0)      |
///
/// A tally of **0** (or [maxTally] == 0) always returns a neutral light grey
/// (`Colors.grey.shade200`) regardless of [maxTally], so empty days are
/// visually distinct from low-tally days.
///
/// The [maxTally] is the highest tally value **in the currently displayed
/// month**, not the all-time high. Colours are therefore relative to the
/// current month, not absolute.
///
/// [tally] is clamped to `[0, maxTally]` before computing the ratio, so
/// out-of-range values are safe to pass.
Color heatmapColor(int tally, int maxTally) {
  if (tally == 0) return Colors.grey.shade200;
  if (maxTally == 0) return Colors.grey.shade200;
  final t = (tally / maxTally).clamp(0.0, 1.0);
  if (t < 0.5) {
    // Green → Yellow
    final s = t / 0.5;
    return Color.fromRGBO(
      (0 + s * 255).round(),
      (180 + s * (220 - 180)).round(),
      0,
      1.0,
    );
  } else {
    // Yellow → Red
    final s = (t - 0.5) / 0.5;
    return Color.fromRGBO(
      (255 + s * (220 - 255)).round(),
      (220 + s * (0 - 220)).round(),
      0,
      1.0,
    );
  }
}

// ---------------------------------------------------------------------------
// CalendarScreen
// ---------------------------------------------------------------------------

/// The main (and only persistent) screen of the app.
///
/// Shows a monthly calendar grid where each day cell is colour-coded by its
/// tally value relative to the month's maximum. Tapping a cell opens
/// [DayDetailScreen] for editing.
///
/// ### State summary
/// | Field           | Meaning                                      |
/// |-----------------|----------------------------------------------|
/// | [_currentMonth] | First day of the month being displayed       |
/// | [_logicalToday] | Result of [getLogicalToday] at startup       |
/// | [_entries]      | DB rows for [_currentMonth]                  |
/// | [_maxTally]     | Highest tally in [_entries] (min 1)          |
///
/// ### Navigation
/// - `←` / `→` buttons in the header call [_prevMonth] / [_nextMonth].
/// - The CSV export icon (top-right) calls [_exportCSV].
/// - Tapping a day cell calls [_openDay].
///
/// [_loadEntries] is called after every navigation and after returning from
/// [DayDetailScreen] to keep the heatmap fresh.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// The first day of the month currently shown in the grid.
  late DateTime _currentMonth;

  /// The logical today computed at startup (see [getLogicalToday]).
  ///
  /// Computed once in [initState] and not refreshed during a session; reopen
  /// the app to pick up a date change (handled naturally by the OS lifecycle).
  late DateTime _logicalToday;

  /// DB entries for the displayed month, keyed by `YYYY-MM-DD`.
  Map<String, DayEntry> _entries = {};

  /// Maximum tally across all entries in the displayed month.
  ///
  /// Minimum value is 1 to avoid division-by-zero in [heatmapColor].
  int _maxTally = 1;

  @override
  void initState() {
    super.initState();
    _logicalToday = getLogicalToday();
    _currentMonth = DateTime(_logicalToday.year, _logicalToday.month, 1);
    _loadEntries();
  }

  // -------------------------------------------------------------------------
  // Data loading
  // -------------------------------------------------------------------------

  /// Fetches entries for [_currentMonth] from the database and rebuilds the
  /// widget with the new data.
  ///
  /// Also recomputes [_maxTally] so heatmap colours are relative to the
  /// current month's data. [_maxTally] is floored at 1 to guard against
  /// an empty month.
  Future<void> _loadEntries() async {
    final entries = await DatabaseHelper.instance.getEntriesForMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    int max = 1;
    for (final e in entries.values) {
      if (e.tally > max) max = e.tally;
    }
    setState(() {
      _entries = entries;
      _maxTally = max;
    });
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  /// Moves the calendar view back by one month.
  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadEntries();
  }

  /// Moves the calendar view forward by one month.
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadEntries();
  }

  // -------------------------------------------------------------------------
  // CSV export
  // -------------------------------------------------------------------------

  /// Exports all stored entries to a CSV file and opens the share sheet.
  ///
  /// ### CSV format
  /// ```
  /// date,tally,comment
  /// 2024-03-01,3,"went for a run"
  /// 2024-03-03,1,
  /// ```
  /// - Rows are ordered by date ascending.
  /// - Only days with a non-zero tally or a non-empty comment are included
  ///   (zero/empty rows are never stored in the DB).
  /// - The file is written to the platform's temp directory and shared via
  ///   the OS share sheet ([Share.shareXFiles]).
  ///
  /// Throws if the database or filesystem is unavailable.
  Future<void> _exportCSV() async {
    final entries = await DatabaseHelper.instance.getAllEntries();
    final rows = <List<dynamic>>[
      ['date', 'tally', 'comment'],
      ...entries.map((e) => [e.date, e.tally, e.comment]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/tally_calendar_export.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Tally Calendar Export');
  }

  // -------------------------------------------------------------------------
  // Day detail navigation
  // -------------------------------------------------------------------------

  /// Navigates to [DayDetailScreen] for [day] and reloads entries on return.
  ///
  /// Fetches the existing [DayEntry] for [day] before pushing (so the detail
  /// screen shows current values immediately), then calls [_loadEntries]
  /// after the user pops back to refresh the heatmap.
  Future<void> _openDay(DateTime day) async {
    final dateStr = formatDate(day);
    final entry = await DatabaseHelper.instance.getEntry(dateStr);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayDetailScreen(
          date: day,
          entry: entry,
        ),
      ),
    );
    _loadEntries();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_currentMonth);
    final daysInMonth = DateUtils.getDaysInMonth(
        _currentMonth.year, _currentMonth.month);

    // ISO week starts on Monday (weekday == 1), so Monday = column 0.
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final leadingBlanks = (firstWeekday - 1) % 7;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tally Calendar'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // CSV export button in the top-right of the AppBar.
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCSV,
          ),
        ],
      ),
      body: Column(
        children: [
          // ----------------------------------------------------------------
          // Month navigation header
          // ----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left)),
                Text(monthLabel,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),

          // ----------------------------------------------------------------
          // Weekday header row (Mon … Sun)
          // ----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),

          // ----------------------------------------------------------------
          // Day grid
          // The grid has 7 columns (Mon–Sun). Leading blank cells pad the
          // first row so day 1 lands in the correct column. Each cell:
          //   - Background colour = heatmapColor(tally, _maxTally)
          //   - Border = teal highlight if it is the logical today
          //   - Shows the day number and tally (if > 0)
          // ----------------------------------------------------------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (ctx, index) {
                  // Blank leading cell
                  if (index < leadingBlanks) {
                    return const SizedBox.shrink();
                  }

                  final day = index - leadingBlanks + 1;
                  final date = DateTime(
                      _currentMonth.year, _currentMonth.month, day);
                  final dateStr = formatDate(date);
                  final entry = _entries[dateStr];
                  final tally = entry?.tally ?? 0;
                  final isToday = dateStr == formatDate(_logicalToday);
                  final color = heatmapColor(tally, _maxTally);

                  return GestureDetector(
                    onTap: () => _openDay(date),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        border: isToday
                            ? Border.all(color: Colors.teal, width: 2.5)
                            : Border.all(
                                color: Colors.grey.shade300, width: 0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Day number
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: tally > 0
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                          // Tally value (only shown when non-zero)
                          if (tally > 0)
                            Text(
                              '$tally',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ----------------------------------------------------------------
          // Heatmap legend
          // Five colour swatches from the lowest to the highest colour,
          // labelled "Low" and "High".
          // ----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Low', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                ...List.generate(5, (i) {
                  final t = i / 4;
                  return Container(
                    width: 20,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: heatmapColor((t * 10).round(), 10),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
                const SizedBox(width: 6),
                const Text('High', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
