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
  /// null means "no value saved" — distinct from 0.
  int? _tally;
  late TextEditingController _commentController;
  late TextEditingController _tallyController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tally = widget.entry?.tally;
    _commentController =
        TextEditingController(text: widget.entry?.comment ?? '');
    _tallyController =
        TextEditingController(text: _tally != null ? '$_tally' : '');
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

  bool get _hasValue => _tally != null || _commentController.text.trim().isNotEmpty;

  void _increment() {
    setState(() {
      _tally = (_tally ?? 0) + 1;
      _tallyController.text = '$_tally';
    });
    _save();
  }

  void _decrement() {
    final current = _tally ?? 0;
    if (current > 0) {
      setState(() {
        _tally = current - 1;
        _tallyController.text = '$_tally';
      });
      _save();
    }
  }

  Future<void> _save() async {
    final comment = _commentController.text.trim();
    if (_tally == null && comment.isEmpty) {
      // No value at all — remove any existing row
      await DatabaseHelper.instance.deleteEntry(_dateStr);
    } else {
      final entry = DayEntry(
        date: _dateStr,
        tally: _tally ?? 0,
        comment: comment,
      );
      await DatabaseHelper.instance.upsertEntry(entry);
    }
  }

  Future<void> _clearEntry() async {
    setState(() {
      _tally = null;
      _tallyController.text = '';
      _commentController.text = '';
    });
    await DatabaseHelper.instance.deleteEntry(_dateStr);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_dateLabel),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_hasValue)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear entry',
              onPressed: _clearEntry,
            ),
        ],
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
                      hintText: '–',
                    ),
                    onChanged: (val) {
                      if (val.isEmpty) {
                        setState(() => _tally = null);
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 500),
                          _save,
                        );
                        return;
                      }
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
