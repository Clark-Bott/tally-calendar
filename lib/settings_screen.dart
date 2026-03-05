import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// Date helpers
// ---------------------------------------------------------------------------

/// Attempts to parse a date string in either YYYY-MM-DD or DD.MM.YYYY format.
/// Returns the canonical YYYY-MM-DD string, or null if parsing fails.
String? _parseDate(String raw) {
  raw = raw.trim();

  // ISO format: YYYY-MM-DD
  final isoRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  final isoMatch = isoRe.firstMatch(raw);
  if (isoMatch != null) {
    final y = int.parse(isoMatch.group(1)!);
    final m = int.parse(isoMatch.group(2)!);
    final d = int.parse(isoMatch.group(3)!);
    if (_validDate(y, m, d)) {
      return '${y.toString().padLeft(4, '0')}-'
          '${m.toString().padLeft(2, '0')}-'
          '${d.toString().padLeft(2, '0')}';
    }
  }

  // European format: DD.MM.YYYY
  final euRe = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$');
  final euMatch = euRe.firstMatch(raw);
  if (euMatch != null) {
    final d = int.parse(euMatch.group(1)!);
    final m = int.parse(euMatch.group(2)!);
    final y = int.parse(euMatch.group(3)!);
    if (_validDate(y, m, d)) {
      return '${y.toString().padLeft(4, '0')}-'
          '${m.toString().padLeft(2, '0')}-'
          '${d.toString().padLeft(2, '0')}';
    }
  }

  return null;
}

bool _validDate(int y, int m, int d) =>
    y >= 2000 && y <= 2100 && m >= 1 && m <= 12 && d >= 1 && d <= 31;

// ---------------------------------------------------------------------------
// SettingsScreen
// ---------------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hideMonthDayNumber = false;
  bool _hideYearDayNumber = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hideMonthDayNumber = prefs.getBool('month_hide_day_number') ?? false;
      _hideYearDayNumber = prefs.getBool('year_hide_day_number') ?? true;
    });
  }

  Future<void> _setMonthHide(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('month_hide_day_number', val);
    setState(() => _hideMonthDayNumber = val);
  }

  Future<void> _setYearHide(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('year_hide_day_number', val);
    setState(() => _hideYearDayNumber = val);
  }

  // -------------------------------------------------------------------------
  // Export
  // -------------------------------------------------------------------------

  Future<void> _exportCSV() async {
    final entries = await DatabaseHelper.instance.getAllEntries();
    final rows = <List<dynamic>>[
      ['date', 'tally', 'comment'],
      ...entries.map((e) => [e.date, e.tally, e.comment]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/tally_export_$ts.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Tally Export');
  }

  // -------------------------------------------------------------------------
  // Import
  // -------------------------------------------------------------------------

  Future<void> _importCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;

    final bytes = result.files.single.bytes;
    final String content;
    if (bytes != null) {
      content = String.fromCharCodes(bytes);
    } else {
      final path = result.files.single.path;
      if (path == null) return;
      content = await File(path).readAsString();
    }

    final rows =
        const CsvToListConverter(shouldParseNumbers: false).convert(content);
    if (rows.isEmpty) {
      _snack('File is empty');
      return;
    }

    // --- Detect header row and column indices ---
    // Accepted header names (case-insensitive):
    //   date column : "date"
    //   tally column: "tally", "drinks", "count"
    //   comment col : "comment", "notes", "note"
    int dateCol = 0, tallyCol = 1, commentCol = 2;
    int dataStart = 0;

    final firstRow =
        rows[0].map((c) => c.toString().toLowerCase().trim()).toList();
    final dateIdx = firstRow.indexWhere((h) => h == 'date');
    final tallyIdx = firstRow
        .indexWhere((h) => ['tally', 'drinks', 'count'].contains(h));
    final commentIdx = firstRow
        .indexWhere((h) => ['comment', 'notes', 'note'].contains(h));

    if (dateIdx != -1 || tallyIdx != -1) {
      // Looks like a header row — use detected positions
      dateCol = dateIdx != -1 ? dateIdx : 0;
      tallyCol = tallyIdx != -1 ? tallyIdx : 1;
      commentCol = commentIdx != -1 ? commentIdx : 2;
      dataStart = 1;
    }

    // --- Import rows ---
    int imported = 0;
    int skipped = 0;

    for (int i = dataStart; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= tallyCol) {
        skipped++;
        continue;
      }

      final rawDate = row[dateCol].toString();
      final dateStr = _parseDate(rawDate);
      if (dateStr == null) {
        skipped++;
        continue;
      }

      final tally = int.tryParse(row[tallyCol].toString().trim());
      if (tally == null) {
        skipped++;
        continue;
      }

      final comment =
          (commentCol < row.length) ? row[commentCol].toString() : '';

      if (tally == 0 && comment.trim().isEmpty) {
        // No data to store — skip silently
        skipped++;
        continue;
      }

      await DatabaseHelper.instance.upsertEntry(
        DayEntry(date: dateStr, tally: tally, comment: comment),
      );
      imported++;
    }

    _snack('Imported $imported rows ($skipped skipped)');
  }

  // -------------------------------------------------------------------------
  // Repair: fix any DD.MM.YYYY dates already in the database
  // -------------------------------------------------------------------------

  Future<void> _repairDates() async {
    final entries = await DatabaseHelper.instance.getAllEntries();
    int fixed = 0;
    int bad = 0;

    for (final entry in entries) {
      // Already YYYY-MM-DD → nothing to do
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(entry.date)) continue;

      final corrected = _parseDate(entry.date);
      if (corrected == null) {
        bad++;
        continue;
      }

      // Delete old malformed row, insert with corrected date
      await DatabaseHelper.instance.deleteEntry(entry.date);
      await DatabaseHelper.instance.upsertEntry(
        DayEntry(date: corrected, tally: entry.tally, comment: entry.comment),
      );
      fixed++;
    }

    if (fixed == 0 && bad == 0) {
      _snack('All dates look correct — nothing to repair');
    } else {
      _snack(
        'Repaired $fixed date${fixed == 1 ? '' : 's'}'
        '${bad > 0 ? ", $bad could not be parsed" : ""}',
      );
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // --- Display ---
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Display',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Month view: hide day numbers'),
            value: _hideMonthDayNumber,
            onChanged: _setMonthHide,
          ),
          SwitchListTile(
            title: const Text('Year view: hide day numbers'),
            value: _hideYearDayNumber,
            onChanged: _setYearHide,
          ),
          const Divider(),

          // --- Data ---
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Data',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
          ListTile(
            title: const Text('Export CSV'),
            subtitle: const Text('date, tally, comment'),
            trailing: const Icon(Icons.download),
            onTap: _exportCSV,
          ),
          ListTile(
            title: const Text('Import CSV'),
            subtitle: const Text(
              'Accepts DD.MM.YYYY or YYYY-MM-DD dates.\n'
              'Headers: date/Date, tally/Drinks, comment/Notes',
            ),
            trailing: const Icon(Icons.upload_file),
            onTap: _importCSV,
          ),
          ListTile(
            title: const Text('Repair existing data'),
            subtitle: const Text(
              'Converts DD.MM.YYYY dates in the database to YYYY-MM-DD.\n'
              'Run once after importing from an old-format CSV.',
            ),
            trailing: const Icon(Icons.build_outlined),
            onTap: _repairDates,
          ),
        ],
      ),
    );
  }
}
