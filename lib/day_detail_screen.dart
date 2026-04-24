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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Auto-zero: opening a day always starts at 0 if no prior entry.
    _tally = widget.entry?.tally ?? 0;
    _commentController =
        TextEditingController(text: widget.entry?.comment ?? '');
    // Persist the initial zero immediately so the heatmap reflects the entry.
    WidgetsBinding.instance.addPostFrameCallback((_) => _save());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _save();
    _commentController.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(widget.date);
  String get _dateLabel =>
      DateFormat('EEEE, MMMM d, yyyy').format(widget.date);

  void _increment() {
    setState(() => _tally += 1);
    _save();
  }

  void _decrement() {
    if (_tally > 0) {
      setState(() => _tally -= 1);
      _save();
    }
  }

  Future<void> _save() async {
    await DatabaseHelper.instance.upsertEntry(
      DayEntry(date: _dateStr, tally: _tally, comment: _commentController.text.trim()),
    );
  }

  Future<void> _clearEntry() async {
    setState(() {
      _tally = 0;
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
    final hasValue = _tally > 0 || _commentController.text.trim().isNotEmpty;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(_dateLabel),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (hasValue)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear entry',
              onPressed: _clearEntry,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Counter area ────────────────────────────────────────────────
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                // Left tap zone (decrement)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: screenWidth / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _decrement,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Icon(
                          Icons.chevron_left,
                          size: 48,
                          color: _tally > 0
                              ? Colors.grey.shade400
                              : Colors.grey.shade200,
                        ),
                      ),
                    ),
                  ),
                ),
                // Right tap zone (increment)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: screenWidth / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _increment,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(
                          Icons.chevron_right,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
                // Big number
                Center(
                  child: Text(
                    '$_tally',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Notes area ──────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Add a note…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(10),
                      ),
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 500),
                          _save,
                        );
                        // Rebuild to update the delete button visibility.
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
