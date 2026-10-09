import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/core/theme/app_theme.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';

/// Root of the application.
class StockInventoryApp extends StatelessWidget {
  const StockInventoryApp({super.key});

  /// Pinned rather than device-following: the app ships French-only in Phase 1.
  /// Region matters — `BE` drives `12,50 €` and `22/08/2026` formatting.
  static const Locale _locale = Locale('fr', 'BE');

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      // Buttons sized for the screen they are on — shorter on a tablet and
      // a phone. Here rather than in `theme:` because only below the app is
      // the screen's width known.
      builder: (context, child) => Theme(
        data: AppTheme.sizedFor(
          Theme.of(context),
          MediaQuery.sizeOf(context).width,
        ),
        child: child!,
      ),
    );
  }
}
