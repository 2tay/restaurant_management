import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

  /// Application name, shown on the login screen and in the app switcher.
  ///
  /// In fr, this message translates to:
  /// **'Gestion de Stock'**
  String get appTitle;

  /// Sidebar label for the store dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get navDashboard;

  /// Sidebar label for the inventory list.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get navInventory;

  /// Sidebar label for stock in/out/adjustment history. One of the longest rail labels — size the NavigationRail against this string.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements de stock'**
  String get navStockMovement;

  /// Sidebar label for the suppliers list.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs'**
  String get navSuppliers;

  /// Sidebar label for the category and unit-of-measure management screens.
  ///
  /// In fr, this message translates to:
  /// **'Catégories et unités'**
  String get navCatalog;

  /// Sidebar label for low-stock alerts and notifications.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get navAlerts;

  /// Sidebar label for the reports section.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get navReports;

  /// Sidebar label for team members and roles.
  ///
  /// In fr, this message translates to:
  /// **'Équipe'**
  String get navTeam;

  /// Sidebar label for settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get navSettings;

  /// Stock status badge — quantity is above the low-stock threshold.
  ///
  /// In fr, this message translates to:
  /// **'En stock'**
  String get stockStatusInStock;

  /// Stock status badge — quantity is at or below the low-stock threshold.
  ///
  /// In fr, this message translates to:
  /// **'Stock faible'**
  String get stockStatusLowStock;

  /// Stock status badge — quantity is zero.
  ///
  /// In fr, this message translates to:
  /// **'Rupture de stock'**
  String get stockStatusOutOfStock;

  /// Primary action on the inventory list and its empty state.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un article'**
  String get actionAddItem;

  /// Quick action on the dashboard — opens the Stock In screen. Deliberately plain language, not 'create stock ingress record'.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer une livraison'**
  String get actionAddDelivery;

  /// Dismisses a dialog without applying changes.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get actionCancel;

  /// Confirms a destructive action in a confirmation dialog.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get actionDelete;

  /// Commits a form.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get actionSave;

  /// Inline option at the bottom of every category/unit dropdown, opening a create sheet without leaving the form.
  ///
  /// In fr, this message translates to:
  /// **'+ Créer'**
  String get actionCreateNew;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
