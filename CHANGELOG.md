# Changelog

All notable changes to Tally Calendar are documented here.

---

## [1.4.2] - 2026-04-24

### Fixed
- Zero tally is now always saved as a distinct state from "no data". Previously, saving a day with tally=0 and no comment would silently delete the row, making it indistinguishable from a day that was never opened. The clear button remains the only way to remove an entry entirely.

---

## [1.4.1] - 2026-04-24

### Fixed
- Widget test now initialises `sqflite_common_ffi` so the test environment can handle the database access triggered by the new auto-open behaviour on cold start.

---

## [1.4.0] - 2026-04-24

### Changed
- **Day detail screen redesigned**: the tally counter now fills most of the screen. Tap the right half to increment, tap the left half to decrement. Chevron arrows hint at the tap zones; the left arrow fades when the tally is already at zero.
- Notes/comments moved to a compact section at the bottom of the screen.
- Opening a day with no prior entry now automatically sets the tally to 0 and persists it immediately.

### Added
- App now navigates to today's detail screen automatically whenever it gains focus: on cold start, when switching back from another app, and when waking from sleep. Only fires if the main calendar screen is active, so navigating to stats/year/settings and backgrounding the app does not interrupt the user.

---

## [1.3.0] - 2026-03-06

### Added
- Stats screen with monthly and yearly breakdowns.
- Year view showing a full 12-month heatmap grid.
- Nullable tally (tally field can now be explicitly unset, distinct from zero).
- Auto-save: pending edits are flushed when navigating away from the day detail screen.

### Fixed
- CSV export file caching issue.

---

## [1.2.1] - 2026-03-05

### Fixed
- CSV import: handle DD.MM.YYYY date format, flexible column headers, and a repair tool for malformed files.
- Trim whitespace from imported date and tally values.
- Disable CSV number parsing to preserve date format.

---

## [1.2.0] - 2026-03-04

### Added
- Year view, settings screen, auto-save, CSV import.
- App renamed from "Tally Calendar" to "Tally".
- GitHub Actions CI/CD: debug APK on every push, signed release APK on version tags.
