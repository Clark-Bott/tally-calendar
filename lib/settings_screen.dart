import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';
import 'models.dart';

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

  Future<void> _exportCSV() async {
    final entries = await DatabaseHelper.instance.getAllEntries();
    final rows = <List<dynamic>>[
      ['date', 'tally', 'comment'],
      ...entries.map((e) => [e.date, e.tally, e.comment]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/tally_export.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Tally Export');
  }

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

    final rows = const CsvToListConverter().convert(content);
    int imported = 0;
    int skipped = 0;

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (i == 0 && row.isNotEmpty && row[0].toString() == 'date') continue;
      if (row.length < 2) {
        skipped++;
        continue;
      }
      final dateStr = row[0].toString();
      final tally = int.tryParse(row[1].toString());
      if (tally == null) {
        skipped++;
        continue;
      }
      final comment = row.length >= 3 ? row[2].toString() : '';
      await DatabaseHelper.instance.upsertEntry(
        DayEntry(date: dateStr, tally: tally, comment: comment),
      );
      imported++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $imported rows ($skipped skipped)'),
        ),
      );
    }
  }

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
            trailing: const Icon(Icons.download),
            onTap: _exportCSV,
          ),
          ListTile(
            title: const Text('Import CSV'),
            trailing: const Icon(Icons.upload_file),
            onTap: _importCSV,
          ),
        ],
      ),
    );
  }
}
