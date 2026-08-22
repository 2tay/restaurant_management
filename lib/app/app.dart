import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stock_inventory/core/theme/app_theme.dart';
import 'package:stock_inventory/dev/theme_gallery_page.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';

/// Root of the application.
///
/// Stage 3 replaces [MaterialApp] with [MaterialApp.router] driven by
/// `app/router.dart`, and drops the gallery `home` below.
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
      theme: AppTheme.light,

      // Temporary. The gallery is the only thing to look at until the router
      // and real screens land in Stage 3.
      home: const ThemeGalleryPage(),
    );
  }
}
