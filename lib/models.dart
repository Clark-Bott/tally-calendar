/// Data models for Tally Calendar.
///
/// This file contains the [DayEntry] class which is the single core data
/// structure used throughout the app. Every piece of persisted state is
/// ultimately stored as (or derived from) a [DayEntry].

// ---------------------------------------------------------------------------
// DayEntry
// ---------------------------------------------------------------------------

/// Represents a single calendar day's record.
///
/// Each [DayEntry] maps to one row in the SQLite `entries` table.
/// The [date] field (ISO-8601, `YYYY-MM-DD`) is the primary key.
///
/// ### Lifecycle
/// 1. The app creates a [DayEntry] when the user edits a day for the first time.
/// 2. [DatabaseHelper.upsertEntry] writes it to disk (INSERT OR REPLACE).
/// 3. When tally is 0 **and** comment is empty, [DatabaseHelper.deleteEntry]
///    removes the row to keep the database lean.
///
/// ### Immutability
/// [DayEntry] is effectively immutable — mutating state is done via
/// [copyWith], which produces a new instance.
class DayEntry {
  /// ISO-8601 date string, e.g. `"2024-03-15"`.
  ///
  /// Always formatted as `YYYY-MM-DD` with zero-padded month and day.
  /// Acts as the primary key in the SQLite table.
  final String date;

  /// The tally count for this day.
  ///
  /// Always non-negative. The UI prevents decrementing below zero.
  /// A value of `0` combined with an empty [comment] triggers row deletion
  /// (see [DatabaseHelper.upsertEntry]).
  final int tally;

  /// An optional free-text note for this day.
  ///
  /// Stored as-is; never null (defaults to empty string). Leading/trailing
  /// whitespace is trimmed before saving (see [DayDetailScreen._save]).
  final String comment;

  /// Creates a [DayEntry].
  ///
  /// All fields are required. For new/empty days use:
  /// ```dart
  /// DayEntry(date: '2024-03-15', tally: 0, comment: '')
  /// ```
  DayEntry({required this.date, required this.tally, required this.comment});

  // -------------------------------------------------------------------------
  // Serialization
  // -------------------------------------------------------------------------

  /// Converts this entry to a [Map] suitable for SQLite insertion.
  ///
  /// Keys match column names in the `entries` table:
  /// | Key       | Type   | Description        |
  /// |-----------|--------|--------------------|
  /// | `date`    | TEXT   | Primary key        |
  /// | `tally`   | INTEGER| Non-negative count |
  /// | `comment` | TEXT   | Optional note      |
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'tally': tally,
      'comment': comment,
    };
  }

  /// Constructs a [DayEntry] from a SQLite row [Map].
  ///
  /// The `comment` column is nullable in legacy databases that may have been
  /// created before the NOT NULL constraint was applied, so it falls back to
  /// an empty string if absent.
  factory DayEntry.fromMap(Map<String, dynamic> map) {
    return DayEntry(
      date: map['date'] as String,
      tally: map['tally'] as int,
      comment: map['comment'] as String? ?? '',
    );
  }

  // -------------------------------------------------------------------------
  // Convenience
  // -------------------------------------------------------------------------

  /// Returns a new [DayEntry] with the provided fields overriding the
  /// corresponding fields of this instance.
  ///
  /// Unspecified fields keep their current value:
  /// ```dart
  /// final updated = entry.copyWith(tally: entry.tally + 1);
  /// ```
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
