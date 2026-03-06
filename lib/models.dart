/// Data models for Tally Calendar.

class DayEntry {
  /// ISO-8601 date string, e.g. `"2024-03-15"`.
  final String date;

  /// The tally count for this day. Non-negative.
  final int tally;

  /// An optional free-text note for this day.
  final String comment;

  DayEntry({required this.date, required this.tally, required this.comment});

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'tally': tally,
      'comment': comment,
    };
  }

  factory DayEntry.fromMap(Map<String, dynamic> map) {
    return DayEntry(
      date: map['date'] as String,
      tally: map['tally'] as int,
      comment: map['comment'] as String? ?? '',
    );
  }

  DayEntry copyWith({String? date, int? tally, String? comment}) {
    return DayEntry(
      date: date ?? this.date,
      tally: tally ?? this.tally,
      comment: comment ?? this.comment,
    );
  }

  @override
  String toString() => 'DayEntry(date: $date, tally: $tally, comment: "$comment")';
}
