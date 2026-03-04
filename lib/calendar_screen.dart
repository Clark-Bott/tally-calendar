import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'database_helper.dart';
import 'models.dart';
import 'day_detail_screen.dart';

/// Returns the "logical today": if current time is before 06:00, return yesterday.
DateTime getLogicalToday() {
  final now = DateTime.now();
  if (now.hour < 6) {
    return DateTime(now.year, now.month, now.day - 1);
  }
  return DateTime(now.year, now.month, now.day);
}

String formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Heatmap color: 0 = grey, low = cool blue, high = warm red
Color heatmapColor(int tally, int maxTally) {
  if (tally == 0) return Colors.grey.shade200;
  if (maxTally == 0) return Colors.grey.shade200;
  final t = (tally / maxTally).clamp(0.0, 1.0);
  // green (0,180,0) -> yellow (255,220,0) -> red (220,0,0)
  if (t < 0.5) {
    final s = t / 0.5;
    return Color.fromRGBO(
      (0 + s * 255).round(),
      (180 + s * (220 - 180)).round(),
      (0).round(),
      1.0,
    );
  } else {
    final s = (t - 0.5) / 0.5;
    return Color.fromRGBO(
      (255 + s * (220 - 255)).round(),
      (220 + s * (0 - 220)).round(),
      0,
      1.0,
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _currentMonth;
  late DateTime _logicalToday;
  Map<String, DayEntry> _entries = {};
  int _maxTally = 1;

  @override
  void initState() {
    super.initState();
    _logicalToday = getLogicalToday();
    _currentMonth = DateTime(_logicalToday.year, _logicalToday.month, 1);
    _loadEntries();
  }

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

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadEntries();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadEntries();
  }

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

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_currentMonth);
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon
    // We use Monday as first day of week
    final leadingBlanks = (firstWeekday - 1) % 7;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tally Calendar'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCSV,
          ),
        ],
      ),
      body: Column(
        children: [
          // Month navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                Text(monthLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          // Weekday headers
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
          // Calendar grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (ctx, index) {
                  if (index < leadingBlanks) {
                    return const SizedBox.shrink();
                  }
                  final day = index - leadingBlanks + 1;
                  final date = DateTime(_currentMonth.year, _currentMonth.month, day);
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
                            : Border.all(color: Colors.grey.shade300, width: 0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: tally > 0 ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                          if (tally > 0)
                            Text(
                              '$tally',
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Legend
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
