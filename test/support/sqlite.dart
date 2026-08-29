// Makes SQLite loadable under `flutter test`.
//
// The app gets its SQLite from `sqlite3_flutter_libs`, a Flutter plugin that
// bundles the native library into the built application. `flutter test` does not
// build an application — it runs on the Dart VM with no plugins registered — so
// under test that library is simply not there, and the first
// `NativeDatabase.memory()` fails with "Failed to load dynamic library" from
// somewhere deep inside drift, several frames away from anything recognisable.
//
// The fix is to tell package:sqlite3 where to find one itself.
//
// On Windows we use `winsqlite3.dll`, which ships with the OS. No download, no
// gitignored build artefact, nothing for a new machine to set up — `git clone`
// then `flutter test` works. It is loaded by bare name so the loader finds it
// wherever Windows is installed rather than assuming C:.
//
// Its version trails the one the app bundles (3.43 against 3.51 at the time of
// writing). That is worth knowing but not worth solving: nothing in this schema
// is newer than 3.43 — no STRICT tables, no `RETURNING`, no JSON functions — and
// the day something is, the test suite is where it will fail first, which is the
// right place to find out.
//
// Other platforms fall through to package:sqlite3's own lookup, which finds the
// system library on Linux and macOS.

import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

bool _configured = false;

/// Points package:sqlite3 at a library the Dart VM can load.
///
/// Call once from `setUpAll`, or from the top of `main()`. Idempotent, so a
/// suite that pulls in two helpers which both call it is fine.
void useTestSqlite() {
  if (_configured) return;
  _configured = true;

  if (!Platform.isWindows) return;
  open.overrideFor(OperatingSystem.windows, _openWindowsSqlite);
}

DynamicLibrary _openWindowsSqlite() => DynamicLibrary.open('winsqlite3.dll');
