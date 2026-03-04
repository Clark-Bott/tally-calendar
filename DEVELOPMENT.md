# Development Guide — Tally Calendar

This guide covers everything needed to build, run, and extend the app.

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter | ≥ 3.x | Tested on 3.x stable channel |
| Dart | ≥ 3.0 | Included with Flutter |
| Android SDK | API 23–34 | Via Android Studio or standalone SDK |
| Java | 17 (JDK) | Required by Gradle |
| Android Studio | Any recent | Optional but recommended for emulator |

Install Flutter by following the [official docs](https://docs.flutter.dev/get-started/install).

Verify your setup:
```bash
flutter doctor
```
All entries should show ✓ or ✗ only for unused platforms (iOS, web, etc. are fine to skip).

---

## Setup

```bash
# Clone the repo
git clone https://github.com/Clark-Bott/tally-calendar.git
cd tally-calendar

# Fetch dependencies
flutter pub get
```

---

## Running locally

### On a connected Android device (recommended)

```bash
# List connected devices
flutter devices

# Run on a specific device
flutter run -d <device-id>
```

Enable USB debugging on your Android device first:
*Settings → About phone → tap Build number 7× → Developer options → USB debugging*.

### On the Android emulator

Open Android Studio → Device Manager → start a virtual device, then:
```bash
flutter run
```
Flutter auto-selects the running emulator.

---

## Building an APK

### Debug APK (for development / testing)

```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK (for distribution)

A release build requires a signing key. Generate one if you don't have one:

```bash
keytool -genkey -v \
  -keystore ~/tally-calendar-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias tally_calendar
```

Create `android/key.properties`:
```
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=tally_calendar
storeFile=<path-to>/tally-calendar-key.jks
```

Update `android/app/build.gradle` to reference `key.properties` (see Flutter signing docs).

Then build:
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

> ⚠️ Never commit `key.properties` or `.jks` files to version control. Both are in `.gitignore`.

---

## Running tests

```bash
flutter test
```

The test suite is minimal (the default Flutter widget smoke test). Contributions adding unit tests for `DatabaseHelper` and `heatmapColor` are especially welcome.

---

## Architecture

The app is intentionally simple — no state management library, no dependency injection, no BLoC/Provider/Riverpod. For a single-screen personal tool, plain `setState` is appropriate.

### Layers

```
UI (Widgets)
    ↓  calls
DatabaseHelper  (singleton, async)
    ↓  via
sqflite  (SQLite)
```

### Key design decisions

**Why Flutter?**
Allows producing a real installable APK without a full native Android project, while keeping the codebase small and readable. Single-file screens are feasible for an app this size.

**Why sqflite?**
SQLite is the natural choice for structured local data on Android. sqflite is the de-facto Flutter wrapper — mature, well-documented, no server required.

**Why no state management library?**
The app has one screen that owns all its state (`CalendarScreen`) and one transient screen (`DayDetailScreen`) that communicates back via Navigator.pop + a reload. Adding Provider or Riverpod would add more boilerplate than value.

**Why delete rows instead of storing zeros?**
It keeps the database clean and makes CSV export match intuition: only days the user actually touched appear. It also means `getEntriesForMonth` returns a sparse map — easy to reason about.

**Why a 06:00 cutoff for "today"?**
Purely UX: if you're tracking something daily and it's 02:00, you almost certainly want to update yesterday's entry. The cutoff is hard-coded; it could be made a user preference later.

### Adding features

**New fields on DayEntry**
1. Add the field to `models.dart`.
2. Update `toMap()` / `fromMap()`.
3. Bump the schema version in `DatabaseHelper._initDB` and add an `onUpgrade` handler.
4. Update `DayDetailScreen` to show/edit the field.
5. Update the CSV export in `CalendarScreen._exportCSV`.

**Multiple tallies per day**
The current schema supports one integer tally. Supporting multiple named counters would require a new `counter` table and a foreign key on `entries`.

**Widgets / notifications**
Flutter's `home_widget` and `flutter_local_notifications` packages are the usual starting points for Android home-screen widgets and daily reminder notifications.

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `sqflite` | ^2.3.3 | SQLite database |
| `path` | ^1.9.0 | Filesystem path joining |
| `path_provider` | ^2.1.2 | Platform temp/data directories |
| `csv` | ^6.0.0 | CSV serialisation for export |
| `intl` | ^0.19.0 | Date formatting |
| `share_plus` | ^9.0.0 | OS share sheet for CSV export |

All are null-safe and compatible with Dart ≥ 3.0.

---

## File-by-file reference

| File | Responsibility |
|---|---|
| `lib/main.dart` | Bootstrap: init Flutter bindings, pre-warm DB, launch app |
| `lib/models.dart` | `DayEntry` data class with serialisation and `copyWith` |
| `lib/database_helper.dart` | Singleton SQLite wrapper: open, CRUD, export query |
| `lib/calendar_screen.dart` | Main screen: heatmap grid, month navigation, CSV export |
| `lib/day_detail_screen.dart` | Day editing screen: tally ±, direct set, comment, save |

---

## Git & releases

The default branch is `main`. Release APKs are attached to GitHub Releases.

To cut a release:
1. Update `version` in `pubspec.yaml` (e.g. `1.1.0+2`).
2. Build the release APK (see above).
3. Tag the commit: `git tag v1.1.0 && git push --tags`.
4. Create a GitHub Release and attach `app-release.apk`.

---

## Clark's notes (agent context)

> This section is for the AI assistant (Clark) to pick up context between sessions.

- **Repo:** `Clark-Bott/tally-calendar` on GitHub
- **Local clone:** `/home/richard/Documents/tally-calendar`
- **Stack:** Flutter/Dart, sqflite, Material 3
- **Status (2026-03-04):** Code complete and pushed. No APK in Releases yet (Flutter SDK not installed on Richard's laptop — see `flutter doctor` output; Android SDK missing). To produce an APK, either install Flutter + Android SDK locally or use a CI/CD pipeline (GitHub Actions with `subosito/flutter-action` is the fastest path).
- **Next likely tasks:** APK build via CI, signing config, potential features (notifications, multiple counters, widget).
