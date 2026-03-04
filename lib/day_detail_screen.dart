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

  @override
  void initState() {
    super.initState();
    _tally = widget.entry?.tally ?? 0;
    _commentController = TextEditingController(text: widget.entry?.comment ?? '');
    _tallyController = TextEditingController(text: '$_tally');
  }

  @override
  void dispose() {
    _commentController.dispose();
    _tallyController.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(widget.date);
  String get _dateLabel => DateFormat('EEEE, MMMM d, yyyy').format(widget.date);

  void _increment() {
    setState(() {
      _tally++;
      _tallyController.text = '$_tally';
    });
  }

  void _decrement() {
    if (_tally > 0) {
      setState(() {
        _tally--;
        _tallyController.text = '$_tally';
      });
    }
  }

  void _setFromField() {
    final val = int.tryParse(_tallyController.text);
    if (val != null && val >= 0) {
      setState(() {
        _tally = val;
      });
    } else {
      _tallyController.text = '$_tally';
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
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_dateLabel),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tally', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  child: const Icon(Icons.remove, color: Colors.red, size: 28),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _tallyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) => _setFromField(),
                    onEditingComplete: _setFromField,
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
                  child: const Icon(Icons.add, color: Colors.green, size: 28),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: _setFromField,
                  child: const Text('Set'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Comment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Add a note for this day...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
