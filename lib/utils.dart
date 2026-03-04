import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Returns the "logical today" for the app.
///
/// The app treats the day as not having rolled over until 06:00.
DateTime getLogicalToday() {
  final now = DateTime.now();
  if (now.hour < 6) {
    return DateTime(now.year, now.month, now.day - 1);
  }
  return DateTime(now.year, now.month, now.day);
}

/// Formats a [DateTime] as an ISO-8601 date string (YYYY-MM-DD).
String formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Maps a [tally] value to a heatmap colour relative to [maxTally].
Color heatmapColor(int tally, int maxTally) {
  if (tally == 0) return Colors.grey.shade200;
  if (maxTally == 0) return Colors.grey.shade200;
  final t = (tally / maxTally).clamp(0.0, 1.0);
  if (t < 0.5) {
    final s = t / 0.5;
    return Color.fromRGBO(
      (0 + s * 255).round(),
      (180 + s * (220 - 180)).round(),
      0,
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
