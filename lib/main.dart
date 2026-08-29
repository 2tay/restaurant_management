import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'core/utils/formatters.dart';
import 'data/database/app_database.dart';
import 'data/database/bootstrap.dart';
import 'data/providers.dart';
import 'mock_data/mock_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DateFormat throws for any locale whose symbols have not been loaded, and
  // fr_BE is not the default. Loading here rather than lazily means a missing
  // locale fails at startup instead of the first time somebody opens a report.
  await initializeDateFormatting(Formatters.locale);
  Intl.defaultLocale = Formatters.locale;

  // Snapshot the pristine dataset before anything can edit it, so the demo can
  // be put back between walkthroughs. Must happen before the first frame: after
  // that, "pristine" is whatever the last person left behind.
  MockWrite.captureSeed();

  // Open the local database, seeding it on a first launch. Awaited before the
  // first frame: every store-scoped screen needs an establishment to exist, and
  // a splash that resolves into "no data" is worse than a slightly later splash.
  //
  // The screens still read the mock lists — the cutover is stage 9. What this
  // does today is create and seed the file, which is what makes the rest of the
  // phase testable against something real.
  final AppDatabase database = await openAppDatabase();

  // Orientation is deliberately left unconstrained. The app is designed
  // landscape-first for ~10" tablets, but the brief requires portrait to remain
  // usable, so locking orientations here would be wrong.
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const StockInventoryApp(),
    ),
  );
}
