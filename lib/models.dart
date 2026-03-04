class DayEntry {
  final String date; // YYYY-MM-DD
  final int tally;
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
}
