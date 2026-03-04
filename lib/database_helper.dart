import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tally_calendar.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE entries (
        date TEXT PRIMARY KEY,
        tally INTEGER NOT NULL DEFAULT 0,
        comment TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<DayEntry?> getEntry(String date) async {
    final db = await database;
    final maps = await db.query('entries', where: 'date = ?', whereArgs: [date]);
    if (maps.isEmpty) return null;
    return DayEntry.fromMap(maps.first);
  }

  Future<Map<String, DayEntry>> getEntriesForMonth(int year, int month) async {
    final db = await database;
    final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final maps = await db.query('entries', where: 'date LIKE ?', whereArgs: ['$prefix%']);
    final result = <String, DayEntry>{};
    for (final m in maps) {
      final entry = DayEntry.fromMap(m);
      result[entry.date] = entry;
    }
    return result;
  }

  Future<List<DayEntry>> getAllEntries() async {
    final db = await database;
    final maps = await db.query('entries', orderBy: 'date ASC');
    return maps.map((m) => DayEntry.fromMap(m)).toList();
  }

  Future<void> upsertEntry(DayEntry entry) async {
    final db = await database;
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteEntry(String date) async {
    final db = await database;
    await db.delete('entries', where: 'date = ?', whereArgs: [date]);
  }
}
