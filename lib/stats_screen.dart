import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'models.dart';
import 'utils.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<DayEntry> _allEntries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DatabaseHelper.instance.getAllEntries();
    if (mounted) {
      setState(() {
        _allEntries = entries;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allEntries.isEmpty
              ? const Center(child: Text('No data yet'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Total per month'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: _buildMonthlyTotalChart(),
                      ),
                      const SizedBox(height: 32),
                      _sectionTitle('7-day moving average'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: _buildMovingAverageChart(),
                      ),
                      const SizedBox(height: 32),
                      _sectionTitle('Average per weekday'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: _buildWeekdayChart(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Monthly total bar chart
  // ---------------------------------------------------------------------------
  Widget _buildMonthlyTotalChart() {
    // Group entries by YYYY-MM
    final monthTotals = <String, int>{};
    for (final e in _allEntries) {
      final key = e.date.substring(0, 7); // YYYY-MM
      monthTotals[key] = (monthTotals[key] ?? 0) + e.tally;
    }

    if (monthTotals.isEmpty) return const Center(child: Text('No data'));

    final sortedKeys = monthTotals.keys.toList()..sort();

    // Show at most the last 12 months
    final displayKeys = sortedKeys.length > 12
        ? sortedKeys.sublist(sortedKeys.length - 12)
        : sortedKeys;

    final maxY = displayKeys
        .map((k) => monthTotals[k]!)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final key = displayKeys[group.x.toInt()];
              return BarTooltipItem(
                '$key\n${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= displayKeys.length) {
                  return const SizedBox.shrink();
                }
                final key = displayKeys[idx];
                // Show abbreviated month
                final month = int.tryParse(key.substring(5, 7)) ?? 1;
                final label = DateFormat('MMM')
                    .format(DateTime(2000, month));
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: const TextStyle(fontSize: 9)),
                );
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text('${value.toInt()}',
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barGroups: List.generate(displayKeys.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: monthTotals[displayKeys[i]]!.toDouble(),
                width: 14,
                color: Colors.teal,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(3),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. 7-day centered moving average line chart
  // ---------------------------------------------------------------------------
  Widget _buildMovingAverageChart() {
    if (_allEntries.isEmpty) return const Center(child: Text('No data'));

    // Build a map of date -> tally (only dates that have entries)
    final tallyMap = <DateTime, int>{};
    for (final e in _allEntries) {
      final parts = e.date.split('-');
      final dt = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      tallyMap[dt] = e.tally;
    }

    final sortedDates = tallyMap.keys.toList()..sort();
    if (sortedDates.length < 2) return const Center(child: Text('Not enough data'));

    final firstDate = sortedDates.first;
    final lastDate = sortedDates.last;
    final totalDays = lastDate.difference(firstDate).inDays + 1;

    // Build dense array including zero-days
    final dailyValues = <double>[];
    final dailyDates = <DateTime>[];
    for (int i = 0; i < totalDays; i++) {
      final dt = firstDate.add(Duration(days: i));
      dailyDates.add(dt);
      dailyValues.add((tallyMap[dt] ?? 0).toDouble());
    }

    // Centered 7-day moving average
    final maValues = <double>[];
    for (int i = 0; i < dailyValues.length; i++) {
      int start = i - 3;
      int end = i + 3;
      if (start < 0) start = 0;
      if (end >= dailyValues.length) end = dailyValues.length - 1;
      double sum = 0;
      int count = 0;
      for (int j = start; j <= end; j++) {
        sum += dailyValues[j];
        count++;
      }
      maValues.add(sum / count);
    }

    // Show at most 90 days
    final displayStart =
        maValues.length > 90 ? maValues.length - 90 : 0;
    final displayMA = maValues.sublist(displayStart);
    final displayDates = dailyDates.sublist(displayStart);

    final maxY =
        displayMA.reduce((a, b) => a > b ? a : b);

    final spots = List.generate(displayMA.length, (i) {
      return FlSpot(i.toDouble(), displayMA[i]);
    });

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.15,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final date = idx >= 0 && idx < displayDates.length
                    ? DateFormat('MMM d').format(displayDates[idx])
                    : '';
                return LineTooltipItem(
                  '$date\n${spot.y.toStringAsFixed(1)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (displayMA.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= displayDates.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('M/d').format(displayDates[idx]),
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text('${value.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: Colors.teal,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.teal.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Average per weekday bar chart
  // ---------------------------------------------------------------------------
  Widget _buildWeekdayChart() {
    // weekday 1=Mon .. 7=Sun
    final weekdayTotals = List.filled(7, 0);
    final weekdayCounts = List.filled(7, 0);

    for (final e in _allEntries) {
      final parts = e.date.split('-');
      final dt = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final wd = dt.weekday - 1; // 0=Mon..6=Sun
      weekdayTotals[wd] += e.tally;
      weekdayCounts[wd]++;
    }

    final weekdayAvgs = List.generate(7, (i) {
      return weekdayCounts[i] > 0
          ? weekdayTotals[i] / weekdayCounts[i]
          : 0.0;
    });

    final maxY = weekdayAvgs.reduce((a, b) => a > b ? a : b);
    if (maxY == 0) return const Center(child: Text('No data'));

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${dayNames[group.x.toInt()]}\n${rod.toY.toStringAsFixed(1)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(dayNames[idx],
                      style: const TextStyle(fontSize: 10)),
                );
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: weekdayAvgs[i],
                width: 20,
                color: Colors.teal.shade400,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(3),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
