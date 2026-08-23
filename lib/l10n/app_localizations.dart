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

  /// Sidebar label for the category and unit-of-measure management screens. The longest rail label.
  ///
  /// In fr, this message translates to:
  /// **'Catégories et unités'**
  String get navCatalog;

  /// Sidebar label for low-stock alerts.
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

  /// Quick action opening the Stock Out screen, for usage and waste.
  ///
  /// In fr, this message translates to:
  /// **'Sortie de stock'**
  String get actionLogUsage;

  /// Opens the physical-count correction screen.
  ///
  /// In fr, this message translates to:
  /// **'Ajuster le stock'**
  String get actionAdjustStock;

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

  /// Opens the edit form for the current record.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get actionEdit;

  /// Navigates to the previous screen.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get actionBack;

  /// Closes a dialog or panel.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get actionClose;

  /// Generic confirm button in a non-destructive dialog.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get actionConfirm;

  /// Retries after an error state.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get actionRetry;

  /// Snackbar action reversing the change just made. Same French word as cancel — correct in both places.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get actionUndo;

  /// Inline option at the bottom of every category/unit dropdown, opening a create sheet without leaving the form.
  ///
  /// In fr, this message translates to:
  /// **'+ Créer'**
  String get actionCreateNew;

  /// Search field label and tooltip in the top bar.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get actionSearch;

  /// Opens filter options on a list screen.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer'**
  String get actionFilter;

  /// Opens the export dialog on a report. Visual only in Phase 1.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get actionExport;

  /// Link from a dashboard summary card to the full list.
  ///
  /// In fr, this message translates to:
  /// **'Tout afficher'**
  String get actionViewAll;

  /// Tooltip on the top bar notification bell.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get topBarNotifications;

  /// Tooltip on the top bar avatar.
  ///
  /// In fr, this message translates to:
  /// **'Mon compte'**
  String get topBarAccount;

  /// Account menu entry returning to the login screen.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get actionLogout;

  /// Label above the store switcher in the top bar.
  ///
  /// In fr, this message translates to:
  /// **'Établissement'**
  String get storeSwitcherLabel;

  /// Menu entry returning to the store selector.
  ///
  /// In fr, this message translates to:
  /// **'Changer d\'établissement'**
  String get storeSwitcherChange;

  /// Offline banner headline. Offline is the app's normal state in a kitchen, not a failure — the tone should stay informational.
  ///
  /// In fr, this message translates to:
  /// **'Mode hors ligne'**
  String get offlineBannerTitle;

  /// Count of local changes waiting to sync, shown in the offline banner.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune modification en attente} =1{1 modification en attente} other{{count} modifications en attente}}'**
  String offlineBannerPending(int count);

  /// Empty state on the inventory list for a brand-new store.
  ///
  /// In fr, this message translates to:
  /// **'Aucun article pour le moment'**
  String get emptyStateNoItemsTitle;

  /// Supporting line under the inventory empty state.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre premier article pour commencer à suivre votre stock.'**
  String get emptyStateNoItemsBody;

  /// Shown when a search or filter matches nothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get emptyStateNoResultsTitle;

  /// Supporting line under the no-results empty state.
  ///
  /// In fr, this message translates to:
  /// **'Essayez un autre terme ou modifiez vos filtres.'**
  String get emptyStateNoResultsBody;

  /// Accessible label on the loading state.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get loadingLabel;

  /// Generic error state headline.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errorStateTitle;

  /// Generic error state supporting line.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'afficher ces données pour le moment.'**
  String get errorStateBody;

  /// Destructive confirmation dialog title. Note the narrow no-break space before the question mark, which French typography requires.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {name} ?'**
  String confirmDeleteTitle(String name);

  /// Warning line in destructive confirmation dialogs.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get confirmDeleteIrreversible;
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
