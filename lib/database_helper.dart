/// SQLite persistence layer for Tally Calendar.
///
/// All database access goes through [DatabaseHelper.instance] — a singleton
/// that lazily initialises the connection on first use and reuses it for the
/// lifetime of the process.
///
/// ### Schema
/// The app uses a single table:
/// ```sql
/// CREATE TABLE entries (
///   date    TEXT PRIMARY KEY,   -- ISO-8601 YYYY-MM-DD
///   tally   INTEGER NOT NULL DEFAULT 0,
///   comment TEXT    NOT NULL DEFAULT ''
/// );
/// ```
///
/// ### Zero-entry housekeeping
/// Days where both tally and comment are empty are deleted rather than stored
/// as rows with zeroed values. This keeps the database small and avoids
/// distinguishing "never touched" from "explicitly zeroed" at the UI layer.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// DatabaseHelper
// ---------------------------------------------------------------------------

/// Singleton wrapper around the app's SQLite database.
///
/// Obtain the instance via [DatabaseHelper.instance]; do not construct this
/// class directly.
///
/// All public methods are `async` and safe to call from any isolate, though
/// in practice the app only calls them from the main isolate.
class DatabaseHelper {
  // -------------------------------------------------------------------------
  // Singleton
  // -------------------------------------------------------------------------

  /// The single shared instance.
  ///
  /// Use `DatabaseHelper.instance.someMethod()` throughout the app.
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  /// Private constructor — use [instance] instead.
  DatabaseHelper._init();

  // -------------------------------------------------------------------------
  // Initialisation
  // -------------------------------------------------------------------------

  /// Returns the open [Database], initialising it on the first call.
  ///
  /// The database file is stored in the platform's default databases directory
  /// (returned by [getDatabasesPath]). The file is named
  /// `tally_calendar.db`.
  ///
  /// Subsequent calls return the cached instance immediately without I/O.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tally_calendar.db');
    return _database!;
  }

  /// Opens (or creates) the database at [filePath] within the platform's
  /// databases directory.
  ///
  /// Passes [_createDB] as the `onCreate` callback so the schema is applied
  /// when the file is first created.
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Creates the initial database schema.
  ///
  /// Called automatically by sqflite when the database file does not yet
  /// exist. Current version: **1**.
  ///
  /// Migration strategy: increment `version` in [_initDB] and add an
  /// `onUpgrade` callback for future schema changes.
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE entries (
        date TEXT PRIMARY KEY,
        tally INTEGER NOT NULL DEFAULT 0,
        comment TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  // -------------------------------------------------------------------------
  // Read operations
  // -------------------------------------------------------------------------

  /// Returns the [DayEntry] for [date] (`YYYY-MM-DD`), or `null` if no row
  /// exists for that date.
  ///
  /// A `null` return means the day has never been edited — treat it as
  /// `tally = 0, comment = ''`.
  Future<DayEntry?> getEntry(String date) async {
    final db = await database;
    final maps = await db.query('entries', where: 'date = ?', whereArgs: [date]);
    if (maps.isEmpty) return null;
    return DayEntry.fromMap(maps.first);
  }

  /// Returns all entries whose `date` starts with `YYYY-MM`, keyed by their
  /// date string.
  ///
  /// Used by [CalendarScreen] to populate the heatmap for a displayed month.
  /// Only rows that actually exist in the database are returned; missing days
  /// imply a tally of zero.
  ///
  /// Example:
  /// ```dart
  /// final entries = await DatabaseHelper.instance.getEntriesForMonth(2024, 3);
  /// final march15 = entries['2024-03-15']; // null if never edited
  /// ```
  Future<Map<String, DayEntry>> getEntriesForMonth(int year, int month) async {
    final db = await database;
    final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'entries',
      where: 'date LIKE ?',
      whereArgs: ['$prefix%'],
    );
    final result = <String, DayEntry>{};
    for (final m in maps) {
      final entry = DayEntry.fromMap(m);
      result[entry.date] = entry;
    }
    return result;
  }

  /// Returns every stored entry in ascending date order.
  ///
  /// Used exclusively by the CSV export feature to produce a full data dump.
  /// For large datasets this loads all rows into memory at once; acceptable
  /// for the expected lifetime of a personal daily-tracking app.
  Future<List<DayEntry>> getAllEntries() async {
    final db = await database;
    final maps = await db.query('entries', orderBy: 'date ASC');
    return maps.map((m) => DayEntry.fromMap(m)).toList();
  }

  // -------------------------------------------------------------------------
  // Write operations
  // -------------------------------------------------------------------------

  /// Inserts or replaces the row for [entry.date].
  ///
  /// Uses SQLite's `INSERT OR REPLACE` conflict resolution, so this is safe
  /// to call whether or not a row already exists for that date.
  ///
  /// Callers should first check whether both tally and comment are empty and
  /// call [deleteEntry] instead if so — see [DayDetailScreen._save].
  Future<void> upsertEntry(DayEntry entry) async {
    final db = await database;
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes the row for [date] from the database.
  ///
  /// Called when the user saves a day with tally == 0 and an empty comment,
  /// keeping the database free of semantically-empty rows.
  ///
  /// No-ops silently if no row exists for [date].
  Future<void> deleteEntry(String date) async {
    final db = await database;
    await db.delete('entries', where: 'date = ?', whereArgs: [date]);
  }
}
