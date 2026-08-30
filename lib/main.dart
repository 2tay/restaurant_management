import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'core/utils/formatters.dart';
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

  // Phase 2: open the local database (seeding it on a first launch), and hand
  // it to the provider that every repository reads from.
  final database = await openAppDatabase();

  // The employee module still runs on the in-memory mock layer. Snapshot it
  // before anything can edit it, so the demo can be put back between
  // walkthroughs, and start signed out so the app opens on the login screen.
  MockWrite.captureSeed();
  MockSession.signOut();

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
