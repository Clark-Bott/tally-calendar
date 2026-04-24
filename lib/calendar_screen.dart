import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'models.dart';
import 'utils.dart';
import 'day_detail_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'year_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with WidgetsBindingObserver {
  late DateTime _currentMonth;
  late DateTime _logicalToday;
  Map<String, DayEntry> _entries = {};
  int _maxTally = 1;
  bool _hideNumbers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logicalToday = getLogicalToday();
    _currentMonth = DateTime(_logicalToday.year, _logicalToday.month, 1);
    _loadAll();
    // Open today's detail screen after the first frame on cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openToday());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _openToday();
    }
  }

  /// Navigates to [DayDetailScreen] for the current logical day.
  ///
  /// Only pushes if [CalendarScreen] is currently the top route, so we don't
  /// interrupt the user if they're already looking at a day or another screen.
  Future<void> _openToday() async {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _logicalToday = getLogicalToday();
    if (_currentMonth.year != _logicalToday.year ||
        _currentMonth.month != _logicalToday.month) {
      setState(() {
        _currentMonth = DateTime(_logicalToday.year, _logicalToday.month, 1);
      });
      await _loadAll();
    }
    if (!mounted) return;
    _openDay(_logicalToday);
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await DatabaseHelper.instance.getEntriesForMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    int max = 1;
    for (final e in entries.values) {
      if (e.tally > max) max = e.tally;
    }
    if (mounted) {
      setState(() {
        _hideNumbers = prefs.getBool('month_hide_day_number') ?? false;
        _entries = entries;
        _maxTally = max;
      });
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadAll();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadAll();
  }

  Future<void> _openDay(DateTime day) async {
    final dateStr = formatDate(day);
    final entry = await DatabaseHelper.instance.getEntry(dateStr);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayDetailScreen(date: day, entry: entry),
      ),
    );
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_currentMonth);
    final daysInMonth =
        DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final leadingBlanks = (firstWeekday - 1) % 7;

    // Stats for this month
    final daysWithEntries = _entries.values.where((e) => true).toList();
    final totalTally = daysWithEntries.fold<int>(0, (sum, e) => sum + e.tally);
    final nonzeroDays = daysWithEntries.where((e) => e.tally > 0).length;
    final avgTally = daysWithEntries.isEmpty
        ? 0.0
        : totalTally / daysWithEntries.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tally'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Stats',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
              _loadAll();
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Year view',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const YearScreen()),
              );
              _loadAll();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadAll();
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
          // Stats row
          if (daysWithEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statChip('Avg', avgTally.toStringAsFixed(1)),
                  _statChip('Total', '$totalTally'),
                  _statChip('Days', '$nonzeroDays'),
                ],
              ),
            ),
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
                  if (index < leadingBlanks) {
                    return const SizedBox.shrink();
                  }

                  final day = index - leadingBlanks + 1;
                  final date = DateTime(
                      _currentMonth.year, _currentMonth.month, day);
                  final dateStr = formatDate(date);
                  final entry = _entries[dateStr];
                  final tally = entry?.tally ?? 0;
                  final hasEntry = entry != null;
                  final isToday = dateStr == formatDate(_logicalToday);
                  final color = hasEntry
                      ? heatmapColor(tally, _maxTally)
                      : Colors.grey.shade200;

                  Widget cellChild;
                  if (_hideNumbers) {
                    if (hasEntry) {
                      cellChild = Center(
                        child: Text(
                          '$tally',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      );
                    } else {
                      cellChild = const SizedBox.shrink();
                    }
                  } else {
                    cellChild = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: hasEntry && tally > 0
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (hasEntry)
                          Text(
                            '$tally',
                            style: TextStyle(
                                fontSize: 10,
                                color: tally > 0
                                    ? Colors.white70
                                    : Colors.grey.shade500),
                          ),
                      ],
                    );
                  }

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
                      child: cellChild,
                    ),
                  );
                },
              ),
            ),
          ),
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

  Widget _statChip(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
