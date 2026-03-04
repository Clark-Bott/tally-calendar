import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'models.dart';
import 'utils.dart';
import 'day_detail_screen.dart';

class YearScreen extends StatefulWidget {
  const YearScreen({super.key});

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  late int _year;
  Map<String, DayEntry> _entries = {};
  int _maxTally = 1;
  bool _hideNumbers = true;

  @override
  void initState() {
    super.initState();
    _year = getLogicalToday().year;
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await DatabaseHelper.instance.getEntriesForYear(_year);
    int max = 1;
    for (final e in entries.values) {
      if (e.tally > max) max = e.tally;
    }
    if (mounted) {
      setState(() {
        _hideNumbers = prefs.getBool('year_hide_day_number') ?? true;
        _entries = entries;
        _maxTally = max;
      });
    }
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

  Widget _buildMonth(int month) {
    final monthName = DateFormat('MMMM').format(DateTime(_year, month));
    final daysInMonth = DateUtils.getDaysInMonth(_year, month);
    final firstWeekday = DateTime(_year, month, 1).weekday;
    final leadingBlanks = (firstWeekday - 1) % 7;
    final today = getLogicalToday();

    return Card(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1.0,
              ),
              itemCount: leadingBlanks + daysInMonth,
              itemBuilder: (ctx, index) {
                if (index < leadingBlanks) {
                  return const SizedBox.shrink();
                }
                final day = index - leadingBlanks + 1;
                final date = DateTime(_year, month, day);
                final dateStr = formatDate(date);
                final entry = _entries[dateStr];
                final tally = entry?.tally ?? 0;
                final isToday = dateStr == formatDate(today);
                final color = heatmapColor(tally, _maxTally);

                Widget? child;
                if (_hideNumbers) {
                  if (tally > 0) {
                    child = Center(
                      child: Text(
                        '$tally',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }
                } else {
                  child = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 9,
                          color: tally > 0
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (tally > 0)
                        Text(
                          '$tally',
                          style: const TextStyle(
                            fontSize: 7,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  );
                }

                return GestureDetector(
                  onTap: () => _openDay(date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      border: isToday
                          ? Border.all(color: Colors.teal, width: 1.5)
                          : null,
                    ),
                    child: child,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_year'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() => _year--);
            _loadAll();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _year++);
              _loadAll();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(4),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
          ),
          itemCount: 12,
          itemBuilder: (ctx, index) => _buildMonth(index + 1),
        ),
      ),
    );
  }
}
