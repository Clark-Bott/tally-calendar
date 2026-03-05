import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'models.dart';

class DayDetailScreen extends StatefulWidget {
  final DateTime date;
  final DayEntry? entry;

  const DayDetailScreen({super.key, required this.date, this.entry});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  late int _tally;
  late TextEditingController _commentController;
  late TextEditingController _tallyController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tally = widget.entry?.tally ?? 0;
    _commentController =
        TextEditingController(text: widget.entry?.comment ?? '');
    _tallyController = TextEditingController(text: '$_tally');
  }

  @override
  void dispose() {
    // If a save is pending, fire it now before we lose the widget.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _save();
    }
    _commentController.dispose();
    _tallyController.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(widget.date);
  String get _dateLabel =>
      DateFormat('EEEE, MMMM d, yyyy').format(widget.date);

  void _increment() {
    setState(() {
      _tally++;
      _tallyController.text = '$_tally';
    });
    _save();
  }

  void _decrement() {
    if (_tally > 0) {
      setState(() {
        _tally--;
        _tallyController.text = '$_tally';
      });
      _save();
    }
  }

  Future<void> _save() async {
    final entry = DayEntry(
      date: _dateStr,
      tally: _tally,
      comment: _commentController.text.trim(),
    );
    if (_tally == 0 && entry.comment.isEmpty) {
      await DatabaseHelper.instance.deleteEntry(_dateStr);
    } else {
      await DatabaseHelper.instance.upsertEntry(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_dateLabel),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tally',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _decrement,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.red.shade100,
                  ),
                  child:
                      const Icon(Icons.remove, color: Colors.red, size: 28),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _tallyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 0) {
                        setState(() {
                          _tally = parsed;
                        });
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 500),
                          _save,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _increment,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green.shade100,
                  ),
                  child:
                      const Icon(Icons.add, color: Colors.green, size: 28),
                ),
              ],
            ),

            const SizedBox(height: 32),

            const Text('Comment',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Add a note for this day...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 500),
                  _save,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
