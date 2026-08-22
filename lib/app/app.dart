import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';

/// Root of the application.
///
/// Stage 0 renders a single placeholder. Stage 1 wires in the real theme and
/// Stage 3 replaces [MaterialApp] with [MaterialApp.router] driven by
/// `app/router.dart`.
class StockInventoryApp extends StatelessWidget {
  const StockInventoryApp({super.key});

  /// Pinned rather than device-following: the app ships French-only in Phase 1.
  /// Region matters — `BE` drives `12,50 €` and `22/08/2026` formatting.
  static const Locale _locale = Locale('fr', 'BE');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // TODO: Stage 1 — replace with AppTheme.light from core/theme/app_theme.dart.
      theme: ThemeData(useMaterial3: true),
      home: const _Placeholder(),
    );
  }
}

/// Temporary landing screen. Proves the l10n pipeline resolves before any real
/// screen exists. Deleted in Stage 3 when the router lands.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.appTitle, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Stage 0 — squelette du projet',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
