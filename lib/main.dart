import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'core/utils/formatters.dart';
import 'data/current_employee.dart';
import 'data/database/app_database.dart';
import 'data/database/bootstrap.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DateFormat throws for any locale whose symbols have not been loaded, and
  // fr_BE is not the default. Loading here rather than lazily means a missing
  // locale fails at startup instead of the first time somebody opens a report.
  await initializeDateFormatting(Formatters.locale);
  Intl.defaultLocale = Formatters.locale;

  // Open the local database, seeding it on a first launch. Awaited before the
  // first frame: every store-scoped screen needs an establishment to exist, and
  // a splash that resolves into "no data" is worse than a slightly later splash.
  //
  // Nothing else in the app opens a database. This instance is handed to
  // `databaseProvider` below and every repository is built from it, which is
  // what makes one connection, one file, and one place to look when something
  // is wrong with either.
  //
  // Putting the demo back is `DemoRepository.resetDemo()` now, behind
  // *Paramètres → Synchronisation*. Phase 1 snapshotted the dataset in memory
  // here because a restart was the only other way back; a re-seed writes the
  // dataset again from `data/seed/dataset/`, and survives the restart too.
  final AppDatabase database = await openAppDatabase();

  // Resolve the session before the first frame. `router.dart`'s `_guard` reads
  // `currentEmployeeProvider` synchronously on every navigation, so it must
  // already hold a value — Employee or null — by the time the first route is
  // built. A fresh install has no `meta.currentEmployeeId`, so this resolves to
  // null and the app opens on `/login`.
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(database)],
  );
  await container.read(currentEmployeeProvider.notifier).hydrate();

  // Orientation is deliberately left unconstrained. The app is designed
  // landscape-first for ~10" tablets, but the brief requires portrait to remain
  // usable, so locking orientations here would be wrong.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StockInventoryApp(),
    ),
  );
}
