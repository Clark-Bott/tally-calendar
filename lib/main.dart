/// Entry point for Tally Calendar.
///
/// Initialises Flutter bindings and the SQLite database, then launches the
/// app widget tree rooted at [TallyCalendarApp].
///
/// ### Startup sequence
/// 1. [WidgetsFlutterBinding.ensureInitialized] — required before any
///    `async` platform-channel work (e.g. sqflite path resolution).
/// 2. `await DatabaseHelper.instance.database` — opens/creates the SQLite
///    file so the first screen never has to wait on a cold-open DB call.
/// 3. [runApp] launches the widget tree.

import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'calendar_screen.dart';

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

/// Application entry point.
///
/// Pre-warms the database connection before handing off to Flutter's
/// widget system so [CalendarScreen] can load data synchronously in its
/// first [State.initState] call (the `await` there still happens, but the
/// connection is already open).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const TallyCalendarApp());
}

// ---------------------------------------------------------------------------
// Root widget
// ---------------------------------------------------------------------------

/// Root [StatelessWidget] that configures [MaterialApp] and sets the theme.
///
/// The app uses **Material 3** with a teal colour seed. The single route is
/// [CalendarScreen] — there is no named-route table since navigation is
/// purely imperative (`Navigator.push`).
class TallyCalendarApp extends StatelessWidget {
  const TallyCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tally',
      // Material 3 theme generated from a teal seed colour.
      // Primary surfaces (AppBar, FAB) derive their colour from this scheme.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CalendarScreen(),
    );
  }
}
