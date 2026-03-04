/// Day detail / editing screen for Tally Calendar.
///
/// Shown when the user taps a day cell in [CalendarScreen].
/// Allows the user to:
/// - Increment/decrement the tally with ± buttons.
/// - Type a specific tally value directly into the number field.
/// - Write a free-text comment.
/// - Save or discard changes.
///
/// Changes are not persisted until the user explicitly taps **Save**.
/// Navigating back via the OS back button discards unsaved changes.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// DayDetailScreen
// ---------------------------------------------------------------------------

/// Editing screen for a single calendar day.
///
/// Receives the [date] (a [DateTime] with time component zeroed to midnight)
/// and the existing [entry] if one is stored in the database. If [entry] is
/// `null` the day has never been saved — the screen starts with tally = 0
/// and an empty comment.
///
/// ### Save logic (see [_DayDetailScreenState._save])
/// - If tally == 0 **and** comment is empty → row is deleted (or not
///   written) so the DB stays clean.
/// - Otherwise → [DatabaseHelper.upsertEntry] is called.
/// - After saving the screen pops, causing [CalendarScreen] to reload its
///   entries.
class DayDetailScreen extends StatefulWidget {
  /// The calendar day being edited (time component is unused).
  final DateTime date;

  /// Existing database entry for [date], or `null` if none exists yet.
  final DayEntry? entry;

  const DayDetailScreen({super.key, required this.date, this.entry});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  /// The current in-memory tally value.
  ///
  /// Starts from [widget.entry?.tally] (or 0 if null). Updated by
  /// [_increment], [_decrement], and [_setFromField].
  late int _tally;

  /// Controller for the comment text field.
  ///
  /// Initialised from [widget.entry?.comment].
  late TextEditingController _commentController;

  /// Controller for the tally number field.
  ///
  /// Kept in sync with [_tally]: updated programmatically by [_increment] /
  /// [_decrement], and read back by [_setFromField] when the user types.
  late TextEditingController _tallyController;

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
    // Always dispose controllers to avoid memory leaks.
    _commentController.dispose();
    _tallyController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Computed properties
  // -------------------------------------------------------------------------

  /// ISO-8601 date string for this day (`YYYY-MM-DD`).
  ///
  /// Used as the primary key when writing to / deleting from the database.
  String get _dateStr => DateFormat('yyyy-MM-dd').format(widget.date);

  /// Human-readable date label shown in the AppBar, e.g.
  /// `"Monday, March 4, 2024"`.
  String get _dateLabel =>
      DateFormat('EEEE, MMMM d, yyyy').format(widget.date);

  // -------------------------------------------------------------------------
  // Tally mutation helpers
  // -------------------------------------------------------------------------

  /// Increments the tally by 1 and updates the text field.
  ///
  /// There is no upper bound on the tally value.
  void _increment() {
    setState(() {
      _tally++;
      _tallyController.text = '$_tally';
    });
  }

  /// Decrements the tally by 1, clamped to a minimum of 0.
  ///
  /// The tally is never allowed to go negative — a tally of 0 on a day with
  /// no comment will cause the row to be deleted on save, effectively
  /// "clearing" the entry.
  void _decrement() {
    if (_tally > 0) {
      setState(() {
        _tally--;
        _tallyController.text = '$_tally';
      });
    }
  }

  /// Parses [_tallyController.text] and updates [_tally].
  ///
  /// Called when the user submits the tally text field (keyboard action or
  /// the explicit **Set** button). If the input is not a valid non-negative
  /// integer the field is reset to the last valid [_tally] value — the user
  /// sees their edit reverted rather than an error dialog.
  void _setFromField() {
    final val = int.tryParse(_tallyController.text);
    if (val != null && val >= 0) {
      setState(() {
        _tally = val;
      });
    } else {
      // Invalid input: revert field to current tally.
      _tallyController.text = '$_tally';
    }
  }

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  /// Saves the current tally and comment to the database, then pops the screen.
  ///
  /// ### Behaviour
  /// - **Tally == 0 and comment empty** → [DatabaseHelper.deleteEntry] is
  ///   called. This removes any previously stored row, keeping the DB clean.
  /// - **Otherwise** → [DatabaseHelper.upsertEntry] writes the entry.
  ///
  /// The comment is trimmed of leading/trailing whitespace before saving.
  ///
  /// After the database write the screen is popped via [Navigator.pop], which
  /// triggers [CalendarScreen._loadEntries] to refresh the heatmap.
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

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_dateLabel),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Quick-save button in the AppBar (mirrors the bottom Save button).
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------------------
            // Tally section
            // ----------------------------------------------------------------
            const Text('Tally',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                // Decrement button (red, circular)
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

                // Direct-entry tally field (large text, numeric keyboard)
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
                    // Accept value on keyboard "done" / "next"
                    onSubmitted: (_) => _setFromField(),
                    onEditingComplete: _setFromField,
                  ),
                ),
                const SizedBox(width: 16),

                // Increment button (green, circular)
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
                const SizedBox(width: 16),

                // Explicit "Set" button for when the user types a value and
                // does not want to submit via the keyboard action.
                TextButton(
                  onPressed: _setFromField,
                  child: const Text('Set'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ----------------------------------------------------------------
            // Comment section
            // ----------------------------------------------------------------
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
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Save button (full-width, primary colour)
            // ----------------------------------------------------------------
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
