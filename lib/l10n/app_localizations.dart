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

  /// Sidebar label for the Gestion Employée section — a dropdown expanding into Personnel, Tableau de bord, Historique pointage and Historique de paiement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion Employée'**
  String get navEmployees;

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

  /// Tooltip on a page's full-screen toggle button, shown when the page is not currently full-screen.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get actionFullScreen;

  /// Tooltip on a page's full-screen toggle button, shown while the page is currently full-screen.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le plein écran'**
  String get actionExitFullScreen;

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

  /// Login screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get loginTitle;

  /// Supporting line under the login heading.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour accéder à vos établissements.'**
  String get loginSubtitle;

  /// Email field label on the login form.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get loginEmail;

  /// Password field label.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get loginPassword;

  /// Remember-me toggle on the login form.
  ///
  /// In fr, this message translates to:
  /// **'Rester connecté'**
  String get loginRemember;

  /// Link to the password reset screen. Narrow no-break space before the question mark.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get loginForgot;

  /// Primary action on the login form.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get loginSubmit;

  /// Honest notice on the login screen. Phase 1 authenticates nothing and the demo should not imply otherwise.
  ///
  /// In fr, this message translates to:
  /// **'Prototype de démonstration — aucune authentification réelle.'**
  String get loginDemoNotice;

  /// Password reset screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser le mot de passe'**
  String get forgotTitle;

  /// Instructions on the password reset screen.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre adresse e-mail et nous vous enverrons un lien de réinitialisation.'**
  String get forgotBody;

  /// Primary action on the password reset form.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien'**
  String get forgotSubmit;

  /// Confirmation state heading after requesting a reset link.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre boîte mail'**
  String get forgotSentTitle;

  /// Confirmation body. Deliberately does not confirm whether the account exists, which would leak which addresses are registered.
  ///
  /// In fr, this message translates to:
  /// **'Si un compte existe pour {email}, un lien de réinitialisation vient d\'être envoyé.'**
  String forgotSentBody(String email);

  /// Link back to the login screen.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la connexion'**
  String get forgotBackToLogin;

  /// Onboarding screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get onboardingTitle;

  /// Onboarding supporting text.
  ///
  /// In fr, this message translates to:
  /// **'Suivez votre stock, vos fournisseurs et vos prix sur tous vos établissements, depuis une seule application.'**
  String get onboardingBody;

  /// Primary action on onboarding.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get onboardingStart;

  /// Onboarding feature bullet — inventory tracking.
  ///
  /// In fr, this message translates to:
  /// **'Un stock toujours à jour'**
  String get onboardingFeatureStock;

  /// Body for the inventory onboarding bullet.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez les livraisons et les sorties en quelques secondes, même en plein service.'**
  String get onboardingFeatureStockBody;

  /// Onboarding feature bullet — price comparison.
  ///
  /// In fr, this message translates to:
  /// **'Comparez vos fournisseurs'**
  String get onboardingFeaturePrices;

  /// Body for the price comparison onboarding bullet.
  ///
  /// In fr, this message translates to:
  /// **'Chaque fournisseur a son prix pour un même produit. Voyez lequel vous coûte le moins cher.'**
  String get onboardingFeaturePricesBody;

  /// Onboarding feature bullet — low stock alerts.
  ///
  /// In fr, this message translates to:
  /// **'Ne tombez plus en rupture'**
  String get onboardingFeatureAlerts;

  /// Body for the alerts onboarding bullet.
  ///
  /// In fr, this message translates to:
  /// **'Recevez une alerte dès qu\'un article passe sous son seuil.'**
  String get onboardingFeatureAlertsBody;

  /// Store selector heading.
  ///
  /// In fr, this message translates to:
  /// **'Vos établissements'**
  String get storesTitle;

  /// Store selector supporting line.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez l\'établissement que vous souhaitez gérer.'**
  String get storesSubtitle;

  /// Action opening the add-store form.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un établissement'**
  String get storesAdd;

  /// Item count on a store card.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun article} =1{1 article} other{{count} articles}}'**
  String storesItemCount(int count);

  /// Low-stock alert count badge on a store card.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune alerte} =1{1 alerte} other{{count} alertes}}'**
  String storesAlertCount(int count);

  /// Badge on a store created recently and still empty.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get storesNewBadge;

  /// Add-store screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un établissement'**
  String get addStoreTitle;

  /// Store name field label.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'établissement'**
  String get addStoreName;

  /// Placeholder for the store name field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Brasserie du Sablon'**
  String get addStoreNameHint;

  /// Street address field label.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get addStoreAddress;

  /// Belgian postal code field label.
  ///
  /// In fr, this message translates to:
  /// **'Code postal'**
  String get addStorePostalCode;

  /// City field label. 'Commune' is the Belgian administrative term.
  ///
  /// In fr, this message translates to:
  /// **'Commune'**
  String get addStoreCity;

  /// Phone field label.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get addStorePhone;

  /// Primary action on the add-store form.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'établissement'**
  String get addStoreSubmit;

  /// Snackbar shown after creating a store.
  ///
  /// In fr, this message translates to:
  /// **'Établissement créé'**
  String get addStoreCreated;

  /// Inventory list heading.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get inventoryTitle;

  /// Placeholder in the inventory search field. Mentions barcodes so staff know pasting or scanning one into the box works — an unadvertised capability is one nobody uses.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un article ou un code-barres…'**
  String get inventorySearchHint;

  /// Category filter label on the inventory list.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get inventoryFilterCategory;

  /// Supplier filter label on the inventory list.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get inventoryFilterSupplier;

  /// Filter option clearing the category filter. Feminine, agreeing with 'catégories'.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get inventoryFilterAll;

  /// Filter option clearing the supplier filter. Masculine, agreeing with 'fournisseurs'.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get inventoryFilterAllSuppliers;

  /// Toggle limiting the list to items needing attention.
  ///
  /// In fr, this message translates to:
  /// **'Stock faible uniquement'**
  String get inventoryFilterLowOnly;

  /// Result count under the inventory search.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun article} =1{1 article} other{{count} articles}}'**
  String inventoryCount(int count);

  /// Clears all active inventory filters.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les filtres'**
  String get inventoryClearFilters;

  /// Placeholder in the detail pane of the inventory split view.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un article'**
  String get inventorySelectPrompt;

  /// Supporting line in the empty detail pane.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un article dans la liste pour voir son détail, ses fournisseurs et ses prix.'**
  String get inventorySelectPromptBody;

  /// Label above an item's current quantity.
  ///
  /// In fr, this message translates to:
  /// **'Quantité en stock'**
  String get itemQuantityLabel;

  /// Label for the low-stock threshold.
  ///
  /// In fr, this message translates to:
  /// **'Seuil d\'alerte'**
  String get itemThresholdLabel;

  /// Label for an item's category.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get itemCategoryLabel;

  /// Label for an item's unit of measure.
  ///
  /// In fr, this message translates to:
  /// **'Unité'**
  String get itemUnitLabel;

  /// Label for when the item last changed.
  ///
  /// In fr, this message translates to:
  /// **'Mis à jour'**
  String get itemUpdatedLabel;

  /// Label for the free-text note on an item.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get itemNoteLabel;

  /// Section heading listing every supplier for this item with their price.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs et prix'**
  String get itemSuppliersTitle;

  /// States the core domain rule on the item detail screen: price belongs to the item-supplier link, not to the item.
  ///
  /// In fr, this message translates to:
  /// **'Un même produit peut avoir plusieurs fournisseurs, chacun avec son prix.'**
  String get itemSuppliersSubtitle;

  /// Empty state when an item has no supplier links.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fournisseur associé'**
  String get itemNoSuppliersTitle;

  /// Supporting line for the no-suppliers empty state.
  ///
  /// In fr, this message translates to:
  /// **'Associez un fournisseur pour enregistrer un prix et suivre son évolution.'**
  String get itemNoSuppliersBody;

  /// Action opening the link-supplier form.
  ///
  /// In fr, this message translates to:
  /// **'Associer un fournisseur'**
  String get itemLinkSupplier;

  /// Badge marking the supplier normally used for this item.
  ///
  /// In fr, this message translates to:
  /// **'Par défaut'**
  String get itemDefaultSupplier;

  /// Badge marking the cheapest supplier for this item.
  ///
  /// In fr, this message translates to:
  /// **'Meilleur prix'**
  String get itemCheapest;

  /// Shown when the default supplier is not the cheapest. This is the app's key selling point made concrete.
  ///
  /// In fr, this message translates to:
  /// **'Vous payez {amount} de plus par {unit} qu\'avec {supplier}.'**
  String itemOverpayWarning(String amount, String unit, String supplier);

  /// When a supplier's price for this item last changed.
  ///
  /// In fr, this message translates to:
  /// **'Mis à jour le {date}'**
  String itemPriceUpdated(String date);

  /// Link to the price history for one item-supplier pair.
  ///
  /// In fr, this message translates to:
  /// **'Historique des prix'**
  String get itemViewPriceHistory;

  /// Section heading for this item's stock movement history.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements récents'**
  String get itemMovementsTitle;

  /// Empty state for an item with no movement history.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mouvement enregistré'**
  String get itemNoMovements;

  /// Snackbar confirming an item was deleted.
  ///
  /// In fr, this message translates to:
  /// **'Article supprimé'**
  String get itemDeleted;

  /// Snackbar confirming a supplier link was removed from an item.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur dissocié'**
  String get itemSupplierRemoved;

  /// Extra warning in the remove-supplier-link confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Le prix enregistré et son historique pour ce fournisseur seront perdus.'**
  String get itemRemoveSupplierWarning;

  /// Add-item form heading.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un article'**
  String get addItemTitle;

  /// Edit-item form heading.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'article'**
  String get editItemTitle;

  /// Item name field label.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'article'**
  String get itemFormName;

  /// Placeholder for the item name field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Blanc de poulet'**
  String get itemFormNameHint;

  /// Opening stock quantity on the add-item form.
  ///
  /// In fr, this message translates to:
  /// **'Quantité de départ'**
  String get itemFormStartingQuantity;

  /// Helper text explaining the low-stock threshold.
  ///
  /// In fr, this message translates to:
  /// **'Vous serez alerté lorsque le stock atteindra ce niveau ou passera en dessous.'**
  String get itemFormThresholdHelp;

  /// Heading of the note explaining why the item form has no cost field.
  ///
  /// In fr, this message translates to:
  /// **'Pas de prix sur cette page'**
  String get itemFormNoCostTitle;

  /// Explains that price lives on the item-supplier link. Without this the missing cost field reads as an oversight.
  ///
  /// In fr, this message translates to:
  /// **'Le prix dépend du fournisseur. Associez un ou plusieurs fournisseurs à cet article pour enregistrer leurs prix respectifs.'**
  String get itemFormNoCostBody;

  /// Snackbar confirming item creation.
  ///
  /// In fr, this message translates to:
  /// **'Article créé'**
  String get itemCreated;

  /// Snackbar confirming item edit.
  ///
  /// In fr, this message translates to:
  /// **'Article modifié'**
  String get itemUpdated;

  /// Inline create option in the category dropdown.
  ///
  /// In fr, this message translates to:
  /// **'+ Créer une catégorie'**
  String get itemFormCreateCategory;

  /// Inline create option in the unit dropdown.
  ///
  /// In fr, this message translates to:
  /// **'+ Créer une unité'**
  String get itemFormCreateUnit;

  /// Heading of the inline category creation sheet.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get createCategoryTitle;

  /// Category name field label.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la catégorie'**
  String get createCategoryName;

  /// Placeholder for the category name field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Fruits & Légumes'**
  String get createCategoryHint;

  /// Snackbar confirming category creation.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie créée'**
  String get categoryCreated;

  /// Heading of the inline unit creation sheet.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle unité de mesure'**
  String get createUnitTitle;

  /// Unit full name field label, e.g. Kilogramme.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get createUnitName;

  /// Placeholder for the unit name field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Kilogramme'**
  String get createUnitNameHint;

  /// Unit short form field label, e.g. kg.
  ///
  /// In fr, this message translates to:
  /// **'Abréviation'**
  String get createUnitAbbreviation;

  /// Placeholder for the unit abbreviation field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : kg'**
  String get createUnitAbbreviationHint;

  /// Snackbar confirming unit creation.
  ///
  /// In fr, this message translates to:
  /// **'Unité créée'**
  String get unitCreated;

  /// Link-supplier form heading.
  ///
  /// In fr, this message translates to:
  /// **'Associer un fournisseur'**
  String get linkSupplierTitle;

  /// Subtitle naming the item a supplier is being linked to.
  ///
  /// In fr, this message translates to:
  /// **'Pour {item}'**
  String linkSupplierFor(String item);

  /// Supplier picker label.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get linkSupplierPick;

  /// Inline create option in the supplier picker.
  ///
  /// In fr, this message translates to:
  /// **'+ Créer un fournisseur'**
  String get linkSupplierCreate;

  /// Price field label, naming the item's unit.
  ///
  /// In fr, this message translates to:
  /// **'Prix par {unit}'**
  String linkSupplierPrice(String unit);

  /// Helper text under the price field.
  ///
  /// In fr, this message translates to:
  /// **'Le prix de ce fournisseur pour cet article. Chaque modification sera enregistrée dans l\'historique.'**
  String get linkSupplierPriceHelp;

  /// Toggle marking this supplier as the default for the item.
  ///
  /// In fr, this message translates to:
  /// **'Définir comme fournisseur par défaut'**
  String get linkSupplierSetDefault;

  /// Explains what the default-supplier toggle does.
  ///
  /// In fr, this message translates to:
  /// **'Ce fournisseur sera présélectionné lors de l\'enregistrement d\'une livraison.'**
  String get linkSupplierSetDefaultHelp;

  /// Primary action on the link-supplier form.
  ///
  /// In fr, this message translates to:
  /// **'Associer'**
  String get linkSupplierSubmit;

  /// Snackbar confirming a supplier was linked to an item.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur associé'**
  String get supplierLinked;

  /// Price history screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Historique des prix'**
  String get priceHistoryTitle;

  /// Subtitle naming the item-supplier pair. Price history is always scoped to a pair, never to an item alone.
  ///
  /// In fr, this message translates to:
  /// **'{item} — {supplier}'**
  String priceHistoryFor(String item, String supplier);

  /// Label above the current price on the history screen.
  ///
  /// In fr, this message translates to:
  /// **'Prix actuel'**
  String get priceHistoryCurrent;

  /// How long the current price has been in effect.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le {date}'**
  String priceHistorySince(String date);

  /// Label for the overall price movement across the recorded history.
  ///
  /// In fr, this message translates to:
  /// **'Évolution totale'**
  String get priceHistoryTotalChange;

  /// Count of recorded price changes.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune modification} =1{1 modification} other{{count} modifications}}'**
  String priceHistoryChanges(int count);

  /// Empty state when a supplier price has never changed.
  ///
  /// In fr, this message translates to:
  /// **'Aucune modification de prix'**
  String get priceHistoryEmpty;

  /// Supporting line for the empty price history state.
  ///
  /// In fr, this message translates to:
  /// **'Le prix n\'a pas changé depuis son enregistrement.'**
  String get priceHistoryEmptyBody;

  /// Who recorded a price change.
  ///
  /// In fr, this message translates to:
  /// **'Par {name}'**
  String priceHistoryChangedBy(String name);

  /// Categories management screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categoriesTitle;

  /// Supporting line on the categories screen.
  ///
  /// In fr, this message translates to:
  /// **'Les catégories servent à classer et filtrer vos articles.'**
  String get categoriesSubtitle;

  /// Primary action on the categories screen.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une catégorie'**
  String get categoriesAdd;

  /// Empty state on the categories screen.
  ///
  /// In fr, this message translates to:
  /// **'Aucune catégorie'**
  String get categoriesEmpty;

  /// Supporting line for the categories empty state.
  ///
  /// In fr, this message translates to:
  /// **'Créez une première catégorie pour organiser vos articles.'**
  String get categoriesEmptyBody;

  /// How many items use a category.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun article} =1{1 article} other{{count} articles}}'**
  String categoriesItemCount(int count);

  /// Extra warning when deleting a category that items still reference.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 article utilise cette catégorie et devra être reclassé.} other{{count} articles utilisent cette catégorie et devront être reclassés.}}'**
  String categoriesInUseWarning(int count);

  /// Snackbar confirming category deletion.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie supprimée'**
  String get categoryDeleted;

  /// Snackbar confirming a category was renamed.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie modifiée'**
  String get categoryUpdated;

  /// Units management screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Unités de mesure'**
  String get unitsTitle;

  /// Supporting line on the units screen. Names Belgian-specific units on purpose.
  ///
  /// In fr, this message translates to:
  /// **'Kilogramme, litre, bac, caisse — définissez les unités utilisées dans votre cuisine.'**
  String get unitsSubtitle;

  /// Primary action on the units screen.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une unité'**
  String get unitsAdd;

  /// Empty state on the units screen.
  ///
  /// In fr, this message translates to:
  /// **'Aucune unité de mesure'**
  String get unitsEmpty;

  /// Supporting line for the units empty state.
  ///
  /// In fr, this message translates to:
  /// **'Créez une première unité pour pouvoir ajouter des articles.'**
  String get unitsEmptyBody;

  /// Extra warning when deleting a unit that items still reference.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 article utilise cette unité.} other{{count} articles utilisent cette unité.}}'**
  String unitsInUseWarning(int count);

  /// Snackbar confirming unit deletion.
  ///
  /// In fr, this message translates to:
  /// **'Unité supprimée'**
  String get unitDeleted;

  /// Snackbar confirming a unit was edited.
  ///
  /// In fr, this message translates to:
  /// **'Unité modifiée'**
  String get unitUpdated;

  /// Movement history screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements de stock'**
  String get movementsTitle;

  /// Supporting line on the movement history screen.
  ///
  /// In fr, this message translates to:
  /// **'Historique de toutes les entrées, sorties et corrections.'**
  String get movementsSubtitle;

  /// Empty state on the movement history screen.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mouvement'**
  String get movementsEmpty;

  /// Supporting line for the movements empty state.
  ///
  /// In fr, this message translates to:
  /// **'Les livraisons et sorties de stock apparaîtront ici.'**
  String get movementsEmptyBody;

  /// Result count on the movement history.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun mouvement} =1{1 mouvement} other{{count} mouvements}}'**
  String movementsCount(int count);

  /// Movement type filter label.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get movementsFilterType;

  /// Clears the movement type filter.
  ///
  /// In fr, this message translates to:
  /// **'Tous les types'**
  String get movementsFilterAllTypes;

  /// Date range filter label.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get movementsFilterPeriod;

  /// User filter label on the movement history.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get movementsFilterUser;

  /// Clears the user filter.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get movementsFilterAllUsers;

  /// Date range option.
  ///
  /// In fr, this message translates to:
  /// **'7 derniers jours'**
  String get periodLast7Days;

  /// Date range option.
  ///
  /// In fr, this message translates to:
  /// **'30 derniers jours'**
  String get periodLast30Days;

  /// Date range option.
  ///
  /// In fr, this message translates to:
  /// **'90 derniers jours'**
  String get periodLast90Days;

  /// Date range option covering everything.
  ///
  /// In fr, this message translates to:
  /// **'Tout l\'historique'**
  String get periodAll;

  /// Stock-in movement type. Plain language, not 'stock ingress'.
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get movementTypeIn;

  /// Stock-out movement type.
  ///
  /// In fr, this message translates to:
  /// **'Sortie'**
  String get movementTypeOut;

  /// Adjustment movement type.
  ///
  /// In fr, this message translates to:
  /// **'Ajustement'**
  String get movementTypeAdjustment;

  /// Stock-out reason: sold to a customer.
  ///
  /// In fr, this message translates to:
  /// **'Vente'**
  String get reasonSale;

  /// Stock-out reason: thrown away, dropped, burnt.
  ///
  /// In fr, this message translates to:
  /// **'Perte'**
  String get reasonWaste;

  /// Stock-out reason: expired or spoiled.
  ///
  /// In fr, this message translates to:
  /// **'Produit abîmé'**
  String get reasonSpoilage;

  /// Stock-out reason: moved to another store.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get reasonTransfer;

  /// Stock-in screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer une livraison'**
  String get stockInTitle;

  /// Supporting line on the stock-in screen.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au stock les articles que vous venez de recevoir.'**
  String get stockInSubtitle;

  /// Item picker label on the stock-in form.
  ///
  /// In fr, this message translates to:
  /// **'Article'**
  String get stockInItem;

  /// Supplier picker on the stock-in form. Selecting one auto-fills its current price.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get stockInSupplier;

  /// Received quantity label.
  ///
  /// In fr, this message translates to:
  /// **'Quantité reçue'**
  String get stockInQuantity;

  /// Price actually paid, which may differ from the supplier's listed price.
  ///
  /// In fr, this message translates to:
  /// **'Prix payé par {unit}'**
  String stockInUnitPrice(String unit);

  /// Explains that the price was pre-filled from the supplier and can be corrected.
  ///
  /// In fr, this message translates to:
  /// **'Prix actuel de {supplier}. Modifiez-le si la facture diffère.'**
  String stockInPriceAutofilled(String supplier);

  /// Warning shown when the entered delivery price differs from the stored supplier price.
  ///
  /// In fr, this message translates to:
  /// **'Ce prix diffère du prix enregistré ({old}). L\'écart sera ajouté à l\'historique.'**
  String stockInPriceChanged(String old);

  /// Delivery date field label.
  ///
  /// In fr, this message translates to:
  /// **'Date de réception'**
  String get stockInDate;

  /// Quantity multiplied by unit price.
  ///
  /// In fr, this message translates to:
  /// **'Total de la ligne'**
  String get stockInTotal;

  /// Primary action on the stock-in form.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la livraison'**
  String get stockInSubmit;

  /// Snackbar confirming a delivery was recorded.
  ///
  /// In fr, this message translates to:
  /// **'Livraison enregistrée'**
  String get stockInRecorded;

  /// Shown when the selected item has no supplier links yet.
  ///
  /// In fr, this message translates to:
  /// **'Cet article n\'a pas encore de fournisseur associé.'**
  String get stockInNoSupplier;

  /// Stock-out screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Sortie de stock'**
  String get stockOutTitle;

  /// Supporting line on the stock-out screen.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez ce qui a été vendu, utilisé ou perdu.'**
  String get stockOutSubtitle;

  /// Quantity leaving stock.
  ///
  /// In fr, this message translates to:
  /// **'Quantité sortie'**
  String get stockOutQuantity;

  /// Reason picker label on the stock-out form.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get stockOutReason;

  /// How much is currently in stock, shown next to the quantity stepper.
  ///
  /// In fr, this message translates to:
  /// **'Disponible : {quantity}'**
  String stockOutAvailable(String quantity);

  /// Warning when removing more than is in stock.
  ///
  /// In fr, this message translates to:
  /// **'La quantité dépasse le stock disponible.'**
  String get stockOutExceedsStock;

  /// Primary action on the stock-out form.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la sortie'**
  String get stockOutSubmit;

  /// Snackbar confirming a stock-out was recorded.
  ///
  /// In fr, this message translates to:
  /// **'Sortie enregistrée'**
  String get stockOutRecorded;

  /// Stock adjustment screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Ajustement de stock'**
  String get adjustmentTitle;

  /// Supporting line on the adjustment screen.
  ///
  /// In fr, this message translates to:
  /// **'Corrigez le stock enregistré après un comptage physique.'**
  String get adjustmentSubtitle;

  /// What the app currently believes is in stock.
  ///
  /// In fr, this message translates to:
  /// **'Quantité au système'**
  String get adjustmentSystemQuantity;

  /// What the physical count found.
  ///
  /// In fr, this message translates to:
  /// **'Quantité comptée'**
  String get adjustmentCountedQuantity;

  /// Counted minus system.
  ///
  /// In fr, this message translates to:
  /// **'Écart'**
  String get adjustmentDifference;

  /// Free-text explanation for the adjustment.
  ///
  /// In fr, this message translates to:
  /// **'Motif de l\'écart'**
  String get adjustmentNote;

  /// Placeholder for the adjustment reason field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : épluchures non comptabilisées'**
  String get adjustmentNoteHint;

  /// Primary action on the adjustment form.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l\'ajustement'**
  String get adjustmentSubmit;

  /// Snackbar confirming an adjustment.
  ///
  /// In fr, this message translates to:
  /// **'Ajustement enregistré'**
  String get adjustmentRecorded;

  /// Confirmation dialog title for a large downward adjustment. The brief requires confirmation for these.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer cet ajustement ?'**
  String get adjustmentLargeConfirmTitle;

  /// Body of the large-adjustment confirmation, stating the size of the correction.
  ///
  /// In fr, this message translates to:
  /// **'Vous retirez {amount} du stock de {item}, soit une baisse de {percent}. Vérifiez votre comptage avant de confirmer.'**
  String adjustmentLargeConfirmBody(String amount, String item, String percent);

  /// Shown when counted equals system, so there is nothing to correct.
  ///
  /// In fr, this message translates to:
  /// **'Aucun écart — rien à enregistrer.'**
  String get adjustmentNoChange;

  /// Suppliers list heading.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs'**
  String get suppliersTitle;

  /// Supporting line on the suppliers list.
  ///
  /// In fr, this message translates to:
  /// **'Vos fournisseurs et les produits qu\'ils livrent.'**
  String get suppliersSubtitle;

  /// Primary action on the suppliers list.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un fournisseur'**
  String get suppliersAdd;

  /// Placeholder in the supplier search field.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un fournisseur…'**
  String get suppliersSearchHint;

  /// Empty state on the suppliers list.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fournisseur'**
  String get suppliersEmpty;

  /// Supporting line for the suppliers empty state.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un fournisseur pour enregistrer ses prix et vos livraisons.'**
  String get suppliersEmptyBody;

  /// How many products a supplier provides.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun produit} =1{1 produit} other{{count} produits}}'**
  String suppliersProductCount(int count);

  /// Section heading for a supplier's contact details.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get supplierContact;

  /// Section heading listing the products a supplier provides.
  ///
  /// In fr, this message translates to:
  /// **'Produits fournis'**
  String get supplierProducts;

  /// Empty state when a supplier supplies nothing yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit associé à ce fournisseur'**
  String get supplierProductsEmpty;

  /// Opens the editable pricing table for a supplier.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les tarifs'**
  String get supplierEditPrices;

  /// Snackbar confirming supplier creation.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur créé'**
  String get supplierCreated;

  /// Snackbar confirming a supplier was edited.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur modifié'**
  String get supplierUpdated;

  /// Snackbar confirming supplier deletion.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur supprimé'**
  String get supplierDeleted;

  /// Extra warning when deleting a supplier that still supplies products.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 produit est fourni par ce fournisseur. Son prix et son historique seront perdus.} other{{count} produits sont fournis par ce fournisseur. Leurs prix et historiques seront perdus.}}'**
  String supplierDeleteWarning(int count);

  /// Supplier name field label.
  ///
  /// In fr, this message translates to:
  /// **'Nom du fournisseur'**
  String get supplierFormName;

  /// Placeholder for the supplier name field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Grossiste Central Bruxelles'**
  String get supplierFormNameHint;

  /// Contact person field label.
  ///
  /// In fr, this message translates to:
  /// **'Personne de contact'**
  String get supplierFormContactName;

  /// Supplier email field label.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get supplierFormEmail;

  /// Supplier phone field label.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get supplierFormPhone;

  /// Free-text note on a supplier — delivery days, minimum order.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get supplierFormNote;

  /// Placeholder for the supplier note field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : livraison les mardis et vendredis avant 10h'**
  String get supplierFormNoteHint;

  /// Add-supplier form heading.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un fournisseur'**
  String get addSupplierTitle;

  /// Edit-supplier form heading.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le fournisseur'**
  String get editSupplierTitle;

  /// Supplier pricing table heading.
  ///
  /// In fr, this message translates to:
  /// **'Tarifs'**
  String get supplierPricingTitle;

  /// Explains that editing a price creates a history entry.
  ///
  /// In fr, this message translates to:
  /// **'Modifiez un prix pour l\'enregistrer dans l\'historique.'**
  String get supplierPricingSubtitle;

  /// Product column header in the pricing table.
  ///
  /// In fr, this message translates to:
  /// **'Produit'**
  String get supplierPricingColumnProduct;

  /// Unit price column header.
  ///
  /// In fr, this message translates to:
  /// **'Prix unitaire'**
  String get supplierPricingColumnPrice;

  /// Last-updated column header.
  ///
  /// In fr, this message translates to:
  /// **'Dernière mise à jour'**
  String get supplierPricingColumnUpdated;

  /// Column showing how this supplier's price compares to the cheapest available.
  ///
  /// In fr, this message translates to:
  /// **'Écart au meilleur prix'**
  String get supplierPricingColumnCompare;

  /// Marks a row where this supplier is the cheapest option.
  ///
  /// In fr, this message translates to:
  /// **'Meilleur'**
  String get supplierPricingBest;

  /// Snackbar confirming a price change was recorded.
  ///
  /// In fr, this message translates to:
  /// **'Prix mis à jour'**
  String get priceUpdated;

  /// Store dashboard heading.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get dashboardTitle;

  /// Greeting on the dashboard. Vouvoiement is used everywhere else; a first-name greeting is warm without being familiar.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {name}'**
  String dashboardGreeting(String name);

  /// Summary tile: total value of everything in stock.
  ///
  /// In fr, this message translates to:
  /// **'Valeur du stock'**
  String get dashboardTileStockValue;

  /// Summary tile: how many items are tracked.
  ///
  /// In fr, this message translates to:
  /// **'Articles suivis'**
  String get dashboardTileItems;

  /// Summary tile: items at or below threshold.
  ///
  /// In fr, this message translates to:
  /// **'À réapprovisionner'**
  String get dashboardTileLowStock;

  /// Summary tile: supplier count.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs'**
  String get dashboardTileSuppliers;

  /// Section heading above the large quick-action buttons.
  ///
  /// In fr, this message translates to:
  /// **'Actions rapides'**
  String get dashboardQuickActions;

  /// Section heading for the recent movement feed.
  ///
  /// In fr, this message translates to:
  /// **'Activité récente'**
  String get dashboardRecentActivity;

  /// Empty state for the activity feed.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité pour le moment'**
  String get dashboardNoActivity;

  /// Supporting line for the empty activity feed.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez une livraison ou une sortie pour commencer.'**
  String get dashboardNoActivityBody;

  /// Dashboard section listing items needing attention.
  ///
  /// In fr, this message translates to:
  /// **'Articles à surveiller'**
  String get dashboardAlertsTitle;

  /// Shown when nothing is below threshold.
  ///
  /// In fr, this message translates to:
  /// **'Tout est en stock'**
  String get dashboardAllGood;

  /// Supporting line when there are no alerts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun article sous son seuil d\'alerte.'**
  String get dashboardAllGoodBody;

  /// Dashboard empty state for a brand-new store.
  ///
  /// In fr, this message translates to:
  /// **'Cet établissement est vide'**
  String get dashboardEmptyStore;

  /// Supporting line for the empty-store dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Commencez par ajouter vos articles pour suivre votre stock.'**
  String get dashboardEmptyStoreBody;

  /// Low stock alerts screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Alertes de stock'**
  String get alertsTitle;

  /// Supporting line on the alerts screen.
  ///
  /// In fr, this message translates to:
  /// **'Articles à réapprovisionner, les plus urgents en premier.'**
  String get alertsSubtitle;

  /// Empty state when nothing is below threshold.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte'**
  String get alertsEmpty;

  /// Supporting line for the no-alerts state.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos articles sont au-dessus de leur seuil d\'alerte.'**
  String get alertsEmptyBody;

  /// How far below its threshold an item is.
  ///
  /// In fr, this message translates to:
  /// **'Il manque {quantity} pour atteindre le seuil'**
  String alertsShortfall(String quantity);

  /// Action suggesting the item's default supplier.
  ///
  /// In fr, this message translates to:
  /// **'Commander chez {supplier}'**
  String alertsOrderFrom(String supplier);

  /// Notification centre heading.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Empty state in the notification centre.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification'**
  String get notificationsEmpty;

  /// Supporting line for the empty notification centre.
  ///
  /// In fr, this message translates to:
  /// **'Les alertes de stock et les changements de prix apparaîtront ici.'**
  String get notificationsEmptyBody;

  /// Action clearing the unread state on every notification.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer comme lu'**
  String get notificationsMarkAllRead;

  /// Snackbar confirming everything was marked read.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les notifications sont lues'**
  String get notificationsAllRead;

  /// Unread notification count.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune non lue} =1{1 non lue} other{{count} non lues}}'**
  String notificationsUnread(int count);

  /// Shows every notification.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get notificationsFilterAll;

  /// Shows only unread notifications.
  ///
  /// In fr, this message translates to:
  /// **'Non lues'**
  String get notificationsFilterUnread;

  /// Reports dashboard heading.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get reportsTitle;

  /// Supporting line on the reports dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Valeur de votre stock, consommation et comparaison des prix.'**
  String get reportsSubtitle;

  /// Stock valuation report name.
  ///
  /// In fr, this message translates to:
  /// **'Valorisation du stock'**
  String get reportsValuation;

  /// Describes the valuation report.
  ///
  /// In fr, this message translates to:
  /// **'Combien vaut ce que vous avez en réserve, par catégorie et par article.'**
  String get reportsValuationBody;

  /// Price comparison report name.
  ///
  /// In fr, this message translates to:
  /// **'Comparaison des prix'**
  String get reportsComparison;

  /// Describes the price comparison report.
  ///
  /// In fr, this message translates to:
  /// **'Le même produit chez plusieurs fournisseurs, prix côte à côte.'**
  String get reportsComparisonBody;

  /// Usage report name.
  ///
  /// In fr, this message translates to:
  /// **'Consommation et pertes'**
  String get reportsUsage;

  /// Describes the usage report.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui sort de votre stock, et la part perdue.'**
  String get reportsUsageBody;

  /// Headline tile: estimated annual saving from switching to cheapest suppliers.
  ///
  /// In fr, this message translates to:
  /// **'Économie potentielle'**
  String get reportsPotentialSaving;

  /// Explains how the potential saving is estimated.
  ///
  /// In fr, this message translates to:
  /// **'Estimation annuelle si chaque article était commandé au meilleur prix disponible.'**
  String get reportsPotentialSavingBody;

  /// Tile: value consumed in the last 30 days.
  ///
  /// In fr, this message translates to:
  /// **'Consommation (30 jours)'**
  String get reportsUsage30Days;

  /// Tile: waste and spoilage as a share of consumption.
  ///
  /// In fr, this message translates to:
  /// **'Part de pertes'**
  String get reportsWasteShare;

  /// Action opening a report from its card.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le rapport'**
  String get reportsOpen;

  /// Export dialog heading.
  ///
  /// In fr, this message translates to:
  /// **'Exporter le rapport'**
  String get reportsExportTitle;

  /// Export dialog instructions.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un format. Le fichier sera téléchargé sur cet appareil.'**
  String get reportsExportBody;

  /// PDF export option.
  ///
  /// In fr, this message translates to:
  /// **'Document PDF'**
  String get reportsExportPdf;

  /// CSV export option.
  ///
  /// In fr, this message translates to:
  /// **'Tableur CSV'**
  String get reportsExportCsv;

  /// Honest note in the export dialog. Phase 1 generates no files and the demo should not pretend otherwise.
  ///
  /// In fr, this message translates to:
  /// **'L\'export sera disponible dans une prochaine version.'**
  String get reportsExportUnavailable;

  /// Valuation report heading.
  ///
  /// In fr, this message translates to:
  /// **'Valorisation du stock'**
  String get valuationTitle;

  /// Total stock value label.
  ///
  /// In fr, this message translates to:
  /// **'Valeur totale'**
  String get valuationTotal;

  /// Section heading for the category breakdown.
  ///
  /// In fr, this message translates to:
  /// **'Par catégorie'**
  String get valuationByCategory;

  /// Section heading for the highest-value items.
  ///
  /// In fr, this message translates to:
  /// **'Articles les plus valorisés'**
  String get valuationByItem;

  /// States how the valuation is computed. Necessary because an item has several supplier prices.
  ///
  /// In fr, this message translates to:
  /// **'Valorisé au prix du fournisseur par défaut de chaque article.'**
  String get valuationBasis;

  /// Category column header.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get valuationColumnCategory;

  /// Item-count column header.
  ///
  /// In fr, this message translates to:
  /// **'Articles'**
  String get valuationColumnItems;

  /// Value column header.
  ///
  /// In fr, this message translates to:
  /// **'Valeur'**
  String get valuationColumnValue;

  /// Share-of-total column header.
  ///
  /// In fr, this message translates to:
  /// **'Part'**
  String get valuationColumnShare;

  /// Price comparison report heading.
  ///
  /// In fr, this message translates to:
  /// **'Comparaison des prix'**
  String get comparisonTitle;

  /// Supporting line on the comparison report.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un article pour comparer les prix de tous ses fournisseurs.'**
  String get comparisonSubtitle;

  /// Item picker on the comparison report.
  ///
  /// In fr, this message translates to:
  /// **'Article à comparer'**
  String get comparisonPickItem;

  /// Supplier column header.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get comparisonColumnSupplier;

  /// Price column header.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get comparisonColumnPrice;

  /// Difference-from-cheapest column header.
  ///
  /// In fr, this message translates to:
  /// **'Écart'**
  String get comparisonColumnDifference;

  /// Last-updated column header.
  ///
  /// In fr, this message translates to:
  /// **'Mis à jour'**
  String get comparisonColumnUpdated;

  /// Shown when there is nothing to compare.
  ///
  /// In fr, this message translates to:
  /// **'Un seul fournisseur pour cet article'**
  String get comparisonSingleSupplier;

  /// Supporting line when an item has only one supplier.
  ///
  /// In fr, this message translates to:
  /// **'Associez un second fournisseur pour pouvoir comparer les prix.'**
  String get comparisonSingleSupplierBody;

  /// Usage report heading.
  ///
  /// In fr, this message translates to:
  /// **'Consommation et pertes'**
  String get usageReportTitle;

  /// Chart title for the daily consumption line.
  ///
  /// In fr, this message translates to:
  /// **'Consommation quotidienne'**
  String get usageTrend;

  /// Chart title for the weekly waste share.
  ///
  /// In fr, this message translates to:
  /// **'Part de pertes par semaine'**
  String get usageWasteTrend;

  /// Total value consumed over the period.
  ///
  /// In fr, this message translates to:
  /// **'Total consommé'**
  String get usageTotal;

  /// Value of waste and spoilage over the period.
  ///
  /// In fr, this message translates to:
  /// **'Valeur des pertes'**
  String get usageWasteValue;

  /// Add-employee form heading.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un employé'**
  String get addEmployeeTitle;

  /// Edit-employee form heading.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'employé'**
  String get editEmployeeTitle;

  /// Store settings heading.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de l\'établissement'**
  String get storeSettingsTitle;

  /// Section heading for store name and address.
  ///
  /// In fr, this message translates to:
  /// **'Informations générales'**
  String get storeSettingsGeneral;

  /// Section heading for store-level preferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get storeSettingsPreferences;

  /// Preferred unit pre-selected on new items.
  ///
  /// In fr, this message translates to:
  /// **'Unité par défaut'**
  String get storeSettingsDefaultUnit;

  /// Snackbar confirming settings were saved.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres enregistrés'**
  String get storeSettingsSaved;

  /// Account settings heading.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres du compte'**
  String get accountSettingsTitle;

  /// Section heading for the user's own details.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get accountProfile;

  /// Section heading for password and security.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get accountSecurity;

  /// Action opening the password change flow.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get accountChangePassword;

  /// Section listing the stores on this account.
  ///
  /// In fr, this message translates to:
  /// **'Établissements liés'**
  String get accountLinkedStores;

  /// Notification preferences heading.
  ///
  /// In fr, this message translates to:
  /// **'Préférences de notification'**
  String get notificationPrefsTitle;

  /// Supporting line on the notification preferences screen.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez ce dont vous souhaitez être averti.'**
  String get notificationPrefsSubtitle;

  /// Toggle: notify when an item drops below its threshold.
  ///
  /// In fr, this message translates to:
  /// **'Alertes de stock faible'**
  String get notificationPrefLowStock;

  /// Describes the low stock notification toggle.
  ///
  /// In fr, this message translates to:
  /// **'Recevez une alerte dès qu\'un article passe sous son seuil.'**
  String get notificationPrefLowStockBody;

  /// Toggle: notify when a supplier price changes.
  ///
  /// In fr, this message translates to:
  /// **'Changements de prix'**
  String get notificationPrefPriceChange;

  /// Describes the price change notification toggle.
  ///
  /// In fr, this message translates to:
  /// **'Soyez averti quand un fournisseur modifie un prix.'**
  String get notificationPrefPriceChangeBody;

  /// Toggle: notify on large stock corrections.
  ///
  /// In fr, this message translates to:
  /// **'Ajustements importants'**
  String get notificationPrefLargeAdjustment;

  /// Describes the large adjustment notification toggle.
  ///
  /// In fr, this message translates to:
  /// **'Soyez averti lorsqu\'un comptage corrige fortement le stock.'**
  String get notificationPrefLargeAdjustmentBody;

  /// Toggle: notify when a delivery is recorded.
  ///
  /// In fr, this message translates to:
  /// **'Livraisons enregistrées'**
  String get notificationPrefDeliveries;

  /// Describes the deliveries notification toggle.
  ///
  /// In fr, this message translates to:
  /// **'Recevez un résumé de chaque livraison enregistrée.'**
  String get notificationPrefDeliveriesBody;

  /// Sync status screen heading.
  ///
  /// In fr, this message translates to:
  /// **'État de la synchronisation'**
  String get syncTitle;

  /// Explains the offline-first model. Reassurance, not an apology.
  ///
  /// In fr, this message translates to:
  /// **'L\'application fonctionne hors ligne et se synchronise dès que la connexion revient.'**
  String get syncSubtitle;

  /// When data last reached the server.
  ///
  /// In fr, this message translates to:
  /// **'Dernière synchronisation'**
  String get syncLastSynced;

  /// Count of local changes not yet synced.
  ///
  /// In fr, this message translates to:
  /// **'Modifications en attente'**
  String get syncPending;

  /// Action forcing a sync.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser maintenant'**
  String get syncNow;

  /// Snackbar shown when a sync is triggered.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation en cours…'**
  String get syncStarted;

  /// Connection status: online.
  ///
  /// In fr, this message translates to:
  /// **'Connecté'**
  String get syncOnline;

  /// Connection status: offline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get syncOffline;

  /// Debug toggle letting the offline experience be demoed on demand. The brief asks for this explicitly.
  ///
  /// In fr, this message translates to:
  /// **'Simuler le mode hors ligne'**
  String get syncDemoToggle;

  /// Explains that the offline toggle is a demo aid, not a real setting.
  ///
  /// In fr, this message translates to:
  /// **'Pour la démonstration : affiche la bannière hors ligne dans toute l\'application.'**
  String get syncDemoToggleBody;

  /// Honest note that sync is not implemented in Phase 1.
  ///
  /// In fr, this message translates to:
  /// **'La synchronisation réelle sera ajoutée en phase 2. Les valeurs ci-dessus sont fictives.'**
  String get syncPhase2Note;

  /// Global search screen heading.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get searchTitle;

  /// Placeholder in the global search field. Names barcode explicitly so the capability is discoverable.
  ///
  /// In fr, this message translates to:
  /// **'Article, code-barres, fournisseur…'**
  String get searchHint;

  /// Prompt shown before anything is typed.
  ///
  /// In fr, this message translates to:
  /// **'Que cherchez-vous ?'**
  String get searchPrompt;

  /// Supporting line under the search prompt.
  ///
  /// In fr, this message translates to:
  /// **'Recherchez parmi vos articles, fournisseurs et catégories.'**
  String get searchPromptBody;

  /// Search results section: items.
  ///
  /// In fr, this message translates to:
  /// **'Articles'**
  String get searchSectionItems;

  /// Search results section: suppliers.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs'**
  String get searchSectionSuppliers;

  /// Search results section: categories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get searchSectionCategories;

  /// Total search result count.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun résultat} =1{1 résultat} other{{count} résultats}}'**
  String searchResultCount(int count);

  /// When a store was created, shown on its card in the selector.
  ///
  /// In fr, this message translates to:
  /// **'Créé le {date}'**
  String storesCreatedOn(String date);

  /// Reveals the masked password on the login form.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get actionShow;

  /// Re-masks the password on the login form.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get actionHide;

  /// Screen-reader label for the quantity stepper's minus button.
  ///
  /// In fr, this message translates to:
  /// **'Diminuer'**
  String get a11yDecrease;

  /// Screen-reader label for the quantity stepper's plus button.
  ///
  /// In fr, this message translates to:
  /// **'Augmenter'**
  String get a11yIncrease;

  /// Live comparison while a new supplier price is being typed, when it beats the current cheapest.
  ///
  /// In fr, this message translates to:
  /// **'Meilleur prix que {supplier} : {amount} de moins par {unit}.'**
  String linkSupplierCheaperThan(String supplier, String amount, String unit);

  /// Live comparison when the entered price matches the current cheapest.
  ///
  /// In fr, this message translates to:
  /// **'Même prix que {supplier}.'**
  String linkSupplierSamePriceAs(String supplier);

  /// Live comparison when the entered price is above the current cheapest.
  ///
  /// In fr, this message translates to:
  /// **'Plus cher que {supplier} de {amount} par {unit}.'**
  String linkSupplierDearerThan(String supplier, String amount, String unit);

  /// Back control label naming where it leads, e.g. 'Retour à Inventaire'. Naming the destination means a rushed user does not have to guess.
  ///
  /// In fr, this message translates to:
  /// **'Retour à {destination}'**
  String backTo(String destination);

  /// Back control label when the destination is too long to name.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get backGeneric;

  /// Screen-reader label for the breadcrumb trail.
  ///
  /// In fr, this message translates to:
  /// **'Fil d\'ariane'**
  String get breadcrumbLabel;

  /// Title of the dialog shown when leaving a form with unsaved input. Narrow no-break space before the question mark.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner les modifications ?'**
  String get discardChangesTitle;

  /// Body of the unsaved-changes dialog.
  ///
  /// In fr, this message translates to:
  /// **'Les informations saisies sur cette page seront perdues.'**
  String get discardChangesBody;

  /// Confirms leaving and losing the input. Sits on the right as the forward action.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner'**
  String get discardChangesConfirm;

  /// Returns to the form. Sits on the left as the dismissive action.
  ///
  /// In fr, this message translates to:
  /// **'Continuer la saisie'**
  String get discardChangesCancel;

  /// Sub-navigation tab for the categories screen.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get catalogTabCategories;

  /// Sub-navigation tab for the units screen.
  ///
  /// In fr, this message translates to:
  /// **'Unités de mesure'**
  String get catalogTabUnits;

  /// Settings sub-navigation tab for store settings.
  ///
  /// In fr, this message translates to:
  /// **'Établissement'**
  String get settingsTabStore;

  /// Settings sub-navigation tab for account settings.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get settingsTabAccount;

  /// Settings sub-navigation tab for notification preferences.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get settingsTabNotifications;

  /// Settings sub-navigation tab for sync status.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation'**
  String get settingsTabSync;

  /// Stock movement sub-navigation tab for the history list.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get movementsTabHistory;

  /// Accessible label on the inventory skeleton loader.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de l\'inventaire…'**
  String get loadingItems;

  /// Label of the barcode field on the add/edit item form. The parenthesis matters: most restaurant stock has no barcode and the form must not read as if one is expected.
  ///
  /// In fr, this message translates to:
  /// **'Code-barres (facultatif)'**
  String get itemBarcodeLabel;

  /// Label of the barcode row on the item detail, where the optional nature is already obvious because the row is only shown when there is one.
  ///
  /// In fr, this message translates to:
  /// **'Code-barres'**
  String get itemBarcodeShortLabel;

  /// Placeholder in the barcode field. A plausible EAN-13, shown as an example of the shape rather than as a rule — letters are accepted too.
  ///
  /// In fr, this message translates to:
  /// **'5412345001019'**
  String get itemBarcodeHint;

  /// Helper text under the barcode field explaining when to expect one.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif. Les produits frais — légumes, viande, poisson — n\'en ont généralement pas.'**
  String get itemBarcodeHelp;

  /// Tooltip on the disabled scan button reserved inside the barcode field. The slot exists now so adding the camera later does not reflow the form.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un code-barres (bientôt disponible)'**
  String get itemBarcodeScanTooltip;

  /// Inline error under the barcode field when the entered code already belongs to another item. Names the conflicting item so the user can go and look at it.
  ///
  /// In fr, this message translates to:
  /// **'Ce code-barres est déjà utilisé par « {item} ».'**
  String itemBarcodeDuplicate(String item);

  /// Snackbar after tapping the barcode row on the item detail to copy it.
  ///
  /// In fr, this message translates to:
  /// **'Code-barres copié.'**
  String get itemBarcodeCopied;

  /// Tooltip on the barcode row of the item detail.
  ///
  /// In fr, this message translates to:
  /// **'Copier le code-barres'**
  String get itemBarcodeCopyTooltip;

  /// Sidebar label for the purchase orders section. 'Commande' is what a Belgian restaurant calls a supplier order — never 'bon de commande', which reads as paperwork.
  ///
  /// In fr, this message translates to:
  /// **'Commandes'**
  String get navOrders;

  /// Title of the orders list screen.
  ///
  /// In fr, this message translates to:
  /// **'Commandes'**
  String get ordersTitle;

  /// Subtitle of the orders list screen.
  ///
  /// In fr, this message translates to:
  /// **'Commandes fournisseurs et réceptions'**
  String get ordersSubtitle;

  /// Primary action on the orders list, top right.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle commande'**
  String get ordersNewAction;

  /// Result count above the orders list.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune commande} =1{1 commande} other{{count} commandes}}'**
  String ordersCount(int count);

  /// Empty state title when the store has never had an order.
  ///
  /// In fr, this message translates to:
  /// **'Aucune commande'**
  String get ordersEmptyTitle;

  /// Empty state body on the orders list. States the core rule of the feature up front, because it is the thing users get wrong.
  ///
  /// In fr, this message translates to:
  /// **'Une commande part chez un fournisseur et ne modifie pas le stock. Le stock bouge à la réception de la livraison.'**
  String get ordersEmptyBody;

  /// Action in the orders list empty state.
  ///
  /// In fr, this message translates to:
  /// **'Créer votre première commande'**
  String get ordersEmptyAction;

  /// Status filter chip on the orders list.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get ordersFilterStatus;

  /// Clears the status filter.
  ///
  /// In fr, this message translates to:
  /// **'Tous les statuts'**
  String get ordersFilterAllStatuses;

  /// Date range filter chip on the orders list.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get ordersFilterPeriod;

  /// Clears the date range filter.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les dates'**
  String get ordersFilterAllPeriods;

  /// Date range option on the orders list.
  ///
  /// In fr, this message translates to:
  /// **'7 derniers jours'**
  String get ordersFilterLast7;

  /// Date range option on the orders list.
  ///
  /// In fr, this message translates to:
  /// **'30 derniers jours'**
  String get ordersFilterLast30;

  /// Date range option on the orders list.
  ///
  /// In fr, this message translates to:
  /// **'90 derniers jours'**
  String get ordersFilterLast90;

  /// Line count on an order row.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 ligne} other{{count} lignes}}'**
  String ordersColumnLines(int count);

  /// Filter chip limiting the orders list to sent and partial orders — the ones somebody still has to do something about.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get ordersOpenOnly;

  /// Order status: being built, never sent.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get orderStatusDraft;

  /// Order status: sent to the supplier, nothing received yet.
  ///
  /// In fr, this message translates to:
  /// **'Envoyée'**
  String get orderStatusSent;

  /// Order status: some lines received, order still open.
  ///
  /// In fr, this message translates to:
  /// **'Partielle'**
  String get orderStatusPartial;

  /// Order status: fully received or closed short. Final.
  ///
  /// In fr, this message translates to:
  /// **'Reçue'**
  String get orderStatusReceived;

  /// Order status: cancelled before anything was received. Final.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get orderStatusCancelled;

  /// Title of the order detail screen, using the human-readable order number rather than the internal id.
  ///
  /// In fr, this message translates to:
  /// **'Commande {reference}'**
  String orderDetailTitle(String reference);

  /// Date line on the order detail for a draft.
  ///
  /// In fr, this message translates to:
  /// **'Créée le {date}'**
  String orderCreatedOn(String date);

  /// Date line on the order detail once sent.
  ///
  /// In fr, this message translates to:
  /// **'Envoyée le {date}'**
  String orderSentOn(String date);

  /// Date line on the order detail once final.
  ///
  /// In fr, this message translates to:
  /// **'Clôturée le {date}'**
  String orderClosedOn(String date);

  /// Running total on the order form and on the order detail header.
  ///
  /// In fr, this message translates to:
  /// **'Total de la commande'**
  String get orderTotalLabel;

  /// Order detail tab showing the ordered lines.
  ///
  /// In fr, this message translates to:
  /// **'Lignes'**
  String get orderTabLines;

  /// Order detail tab listing the deliveries recorded against this order.
  ///
  /// In fr, this message translates to:
  /// **'Réceptions'**
  String get orderTabReceipts;

  /// Order lines table column.
  ///
  /// In fr, this message translates to:
  /// **'Article'**
  String get orderColumnItem;

  /// Order lines table column: quantity ordered.
  ///
  /// In fr, this message translates to:
  /// **'Commandé'**
  String get orderColumnOrdered;

  /// Order lines table column: quantity received so far.
  ///
  /// In fr, this message translates to:
  /// **'Reçu'**
  String get orderColumnReceived;

  /// Order lines table column.
  ///
  /// In fr, this message translates to:
  /// **'Prix unitaire'**
  String get orderColumnUnitPrice;

  /// Order lines table column: quantity multiplied by unit price.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get orderColumnLineTotal;

  /// Empty state on the receipts tab of the order detail.
  ///
  /// In fr, this message translates to:
  /// **'Aucune livraison enregistrée pour cette commande.'**
  String get orderReceiptsEmpty;

  /// Free-text note on an order.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get orderNoteLabel;

  /// Placeholder for the order note field.
  ///
  /// In fr, this message translates to:
  /// **'Ex. livraison souhaitée mardi avant 10h'**
  String get orderNoteHint;

  /// Explains why the edit action is absent on a sent order. Says why rather than just disabling the button, which would leave the user hunting.
  ///
  /// In fr, this message translates to:
  /// **'Cette commande est envoyée : ses lignes ne sont plus modifiables. Le fournisseur en détient déjà une copie.'**
  String get orderLockedNotice;

  /// Summary of the recorded shortfall on an order that was closed short. This figure is what tells an owner which suppliers under-deliver.
  ///
  /// In fr, this message translates to:
  /// **'{quantity} non livrés sur cette commande.'**
  String orderShortfallNotice(String quantity);

  /// Badge on an order line the receiver closed short — the balance is not coming.
  ///
  /// In fr, this message translates to:
  /// **'Clôturée'**
  String get orderLineClosedShort;

  /// Badge on an order line still expecting goods.
  ///
  /// In fr, this message translates to:
  /// **'{quantity} en attente'**
  String orderLineOutstanding(String quantity);

  /// Sends a draft to the supplier. Constructive, so bottom right.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la commande'**
  String get orderActionSend;

  /// Saves an order without sending it.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le brouillon'**
  String get orderActionSaveDraft;

  /// Edits a draft order. Only ever shown on drafts.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get orderActionEdit;

  /// Deletes a draft outright. Only ever shown on drafts.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le brouillon'**
  String get orderActionDelete;

  /// Cancels a sent order. Only allowed while nothing has been received.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la commande'**
  String get orderActionCancel;

  /// Opens the receiving screen. The single most important action in the feature.
  ///
  /// In fr, this message translates to:
  /// **'Réceptionner la livraison'**
  String get orderActionReceive;

  /// Closes a partial order, accepting that the outstanding lines are not coming.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer la commande'**
  String get orderActionCloseShort;

  /// Creates an order, used from the low stock alerts screen and from empty states.
  ///
  /// In fr, this message translates to:
  /// **'Créer une commande'**
  String get orderActionCreate;

  /// Confirmation before sending a draft.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la commande à {supplier} ?'**
  String orderSendConfirmTitle(String supplier);

  /// Body of the send confirmation. Restates the core rule at the moment it matters most.
  ///
  /// In fr, this message translates to:
  /// **'Une fois envoyée, la commande n\'est plus modifiable. Elle ne modifie pas le stock : seule la réception de la livraison le fait.'**
  String get orderSendConfirmBody;

  /// Confirms sending.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get orderSendConfirmAction;

  /// Snackbar after sending an order.
  ///
  /// In fr, this message translates to:
  /// **'Commande envoyée à {supplier}.'**
  String orderSent(String supplier);

  /// Snackbar after saving an order as a draft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon enregistré.'**
  String get orderDraftSaved;

  /// Snackbar after editing an existing draft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon mis à jour.'**
  String get orderDraftUpdated;

  /// Extra warning in the delete confirmation for a draft order.
  ///
  /// In fr, this message translates to:
  /// **'Ce brouillon n\'a jamais été envoyé : sa suppression ne laisse aucune trace.'**
  String get orderDeleteWarning;

  /// Snackbar after deleting a draft order.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon supprimé.'**
  String get orderDeleted;

  /// Confirmation before cancelling a sent order.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la commande {reference} ?'**
  String orderCancelConfirmTitle(String reference);

  /// Body of the cancel confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Le fournisseur détient déjà ce document. L\'annulation est définitive et ne peut pas être reprise.'**
  String get orderCancelConfirmBody;

  /// Confirms cancelling. Deliberately repeats the noun: a bare 'Annuler' next to a dialog's own cancel button is how people cancel the wrong thing.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la commande'**
  String get orderCancelConfirmAction;

  /// Snackbar after cancelling an order.
  ///
  /// In fr, this message translates to:
  /// **'Commande annulée.'**
  String get orderCancelled;

  /// Confirmation before closing a partial order short.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer la commande {reference} ?'**
  String orderCloseConfirmTitle(String reference);

  /// Body of the close-short confirmation. The last sentence matters: closing short records the shortfall rather than pretending less was ordered.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 ligne encore en attente sera clôturée comme non livrée.} other{{count} lignes encore en attente seront clôturées comme non livrées.}} L\'écart reste enregistré.'**
  String orderCloseConfirmBody(int count);

  /// Confirms closing an order short.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer'**
  String get orderCloseConfirmAction;

  /// Snackbar after closing an order short.
  ///
  /// In fr, this message translates to:
  /// **'Commande clôturée.'**
  String get orderClosed;

  /// Title of the create order screen.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle commande'**
  String get createOrderTitle;

  /// Title of the edit order screen. Drafts only.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la commande'**
  String get editOrderTitle;

  /// First step of creating an order. Supplier selection comes first, not as a field in the middle of the form — everything else on the screen depends on it.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get orderStepSupplier;

  /// Second step of creating an order: the line builder.
  ///
  /// In fr, this message translates to:
  /// **'Articles'**
  String get orderStepLines;

  /// Prompt shown before a supplier is chosen on the create order screen.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un fournisseur'**
  String get orderSupplierPrompt;

  /// Explains why the supplier comes first.
  ///
  /// In fr, this message translates to:
  /// **'Une commande part chez un seul fournisseur. Ce choix filtre les articles proposés et remplit automatiquement les prix.'**
  String get orderSupplierPromptBody;

  /// Placeholder in the supplier picker search field.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un fournisseur…'**
  String get orderSupplierSearchHint;

  /// Action that reopens the supplier picker after one has been chosen.
  ///
  /// In fr, this message translates to:
  /// **'Changer de fournisseur'**
  String get orderSupplierChange;

  /// Confirmation when changing supplier on an order that already has lines.
  ///
  /// In fr, this message translates to:
  /// **'Changer de fournisseur ?'**
  String get orderChangeSupplierTitle;

  /// Body of the change-supplier confirmation.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{La ligne déjà saisie sera supprimée.} other{Les {count} lignes déjà saisies seront supprimées.}} Les articles et les prix dépendent du fournisseur choisi.'**
  String orderChangeSupplierBody(int count);

  /// Confirms changing supplier and clearing the lines. Says what will happen rather than just 'Continuer'.
  ///
  /// In fr, this message translates to:
  /// **'Changer et vider'**
  String get orderChangeSupplierAction;

  /// Adds a line to the order being built.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un article'**
  String get orderAddLine;

  /// Label of the item picker on an order line. The picker only offers items the chosen supplier actually supplies.
  ///
  /// In fr, this message translates to:
  /// **'Article'**
  String get orderLinePickerLabel;

  /// Quantity field on an order line.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get orderLineQuantity;

  /// Unit price field on an order line. Auto-filled from the supplier's current price and editable, because negotiation happens.
  ///
  /// In fr, this message translates to:
  /// **'Prix / {unit}'**
  String orderLineUnitPrice(String unit);

  /// Computed line total on an order line.
  ///
  /// In fr, this message translates to:
  /// **'Total ligne'**
  String get orderLineTotal;

  /// Tooltip on the remove button of an order line.
  ///
  /// In fr, this message translates to:
  /// **'Retirer cette ligne'**
  String get orderRemoveLine;

  /// Snackbar after removing an order line.
  ///
  /// In fr, this message translates to:
  /// **'Ligne retirée.'**
  String get orderLineRemoved;

  /// Empty state in the order line builder.
  ///
  /// In fr, this message translates to:
  /// **'Aucun article'**
  String get orderLinesEmptyTitle;

  /// Body of the order line builder empty state.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez les articles à commander chez {supplier}.'**
  String orderLinesEmptyBody(String supplier);

  /// Note under an auto-filled order line price.
  ///
  /// In fr, this message translates to:
  /// **'Prix actuel de {supplier}. Modifiable.'**
  String orderPriceAutofilled(String supplier);

  /// Header of the suggested items panel on the create order screen — this supplier's items currently below their threshold.
  ///
  /// In fr, this message translates to:
  /// **'En stock faible chez {supplier}'**
  String orderSuggestedTitle(String supplier);

  /// Subtitle of the suggested items panel.
  ///
  /// In fr, this message translates to:
  /// **'Articles de ce fournisseur à réapprovisionner.'**
  String get orderSuggestedSubtitle;

  /// Adds every suggested item to the order in one tap.
  ///
  /// In fr, this message translates to:
  /// **'Tout ajouter'**
  String get orderSuggestedAddAll;

  /// Adds one suggested item to the order.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get orderSuggestedAdd;

  /// Snackbar after adding suggested items.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 article ajouté.} other{{count} articles ajoutés.}}'**
  String orderSuggestedAdded(int count);

  /// Shown in place of the suggestions panel when nothing this supplier provides is low.
  ///
  /// In fr, this message translates to:
  /// **'Aucun article de ce fournisseur n\'est en stock faible.'**
  String get orderSuggestedEmpty;

  /// How much a suggested item is below its threshold.
  ///
  /// In fr, this message translates to:
  /// **'Il manque {quantity}'**
  String orderSuggestedShortfall(String quantity);

  /// Badge on an order line for an item that already appears on another open order. Without this, a manager who ordered on Monday orders again on Wednesday because stock still looks low.
  ///
  /// In fr, this message translates to:
  /// **'Déjà commandé : {quantity}'**
  String orderAlreadyOnOrder(String quantity);

  /// Tooltip expanding the already-on-order badge.
  ///
  /// In fr, this message translates to:
  /// **'{quantity} attendus sur {count, plural, =1{1 commande en cours} other{{count} commandes en cours}}.'**
  String orderAlreadyOnOrderDetail(String quantity, int count);

  /// Quantity physically in the store, as opposed to on order.
  ///
  /// In fr, this message translates to:
  /// **'En stock'**
  String get itemOnHandLabel;

  /// Quantity still expected across open orders. Shown alongside on-hand so low-and-already-ordered looks different from low-and-nobody-acted.
  ///
  /// In fr, this message translates to:
  /// **'En commande'**
  String get itemOnOrderLabel;

  /// Section on the item detail listing the open orders containing this item.
  ///
  /// In fr, this message translates to:
  /// **'Commandes en cours'**
  String get itemOpenOrdersTitle;

  /// Shown when an item is on no open order.
  ///
  /// In fr, this message translates to:
  /// **'Aucune commande en cours pour cet article.'**
  String get itemNoOpenOrders;

  /// Title of the receiving screen.
  ///
  /// In fr, this message translates to:
  /// **'Réception — {reference}'**
  String receiveOrderTitle(String reference);

  /// Subtitle of the receiving screen.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez ligne par ligne ce qui est réellement arrivé.'**
  String get receiveOrderSubtitle;

  /// Ordered quantity on a receiving line — what is still outstanding, not the original order quantity.
  ///
  /// In fr, this message translates to:
  /// **'Commandé'**
  String get receiveColumnOrdered;

  /// Received quantity field on a receiving line. Pre-filled with the outstanding quantity, because it usually matches.
  ///
  /// In fr, this message translates to:
  /// **'Reçu'**
  String get receiveColumnReceived;

  /// Actual unit price field on a receiving line, pre-filled with the ordered price and corrected if the delivery note differs.
  ///
  /// In fr, this message translates to:
  /// **'Prix réel / {unit}'**
  String receiveColumnPrice(String unit);

  /// Free-text note on a receiving line.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get receiveLineNote;

  /// Placeholder for the receiving line note.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 2 cageots abîmés, repris par le chauffeur'**
  String get receiveLineNoteHint;

  /// Inline control heading revealed when less than ordered was received.
  ///
  /// In fr, this message translates to:
  /// **'Livraison incomplète : il manque {quantity}'**
  String receiveShortTitle(String quantity);

  /// Default choice on a short delivery: the balance is not coming. Default because most restaurant purchasing is fresh goods, where a shortfall is gone rather than delayed — and orders left open forever permanently inflate the on-order quantity.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer l\'écart'**
  String get receiveShortClose;

  /// Alternative on a short delivery: keep the line open for a later delivery.
  ///
  /// In fr, this message translates to:
  /// **'Le reste doit arriver'**
  String get receiveShortKeepOpen;

  /// Badge on a line where more arrived than was ordered. Allowed, but flagged, because it affects cost.
  ///
  /// In fr, this message translates to:
  /// **'Sur-livraison de {quantity}'**
  String receiveOverBadge(String quantity);

  /// Badge on a line the driver brought that was not on the order. Allowed but never invisible.
  ///
  /// In fr, this message translates to:
  /// **'Non commandé'**
  String get receiveUnorderedBadge;

  /// Adds a line at receipt time for something that was not ordered.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un article non commandé'**
  String get receiveAddUnordered;

  /// Snackbar after adding an unordered line.
  ///
  /// In fr, this message translates to:
  /// **'Article non commandé ajouté à la réception.'**
  String get receiveUnorderedAdded;

  /// Snackbar after removing an unordered line from the receipt being built.
  ///
  /// In fr, this message translates to:
  /// **'Ligne retirée de la réception.'**
  String get receiveUnorderedRemoved;

  /// Summary card shown before confirming a receipt.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get receiveSummaryTitle;

  /// Summary figure: how many lines have a received quantity.
  ///
  /// In fr, this message translates to:
  /// **'Lignes reçues'**
  String get receiveSummaryLines;

  /// Summary figure: total value of the delivery at the actual prices.
  ///
  /// In fr, this message translates to:
  /// **'Valeur reçue'**
  String get receiveSummaryValue;

  /// Summary figure: how many lines are short, over, or unordered.
  ///
  /// In fr, this message translates to:
  /// **'Écarts'**
  String get receiveSummaryDiscrepancies;

  /// Confirms the receipt. Generates one stock movement per line and updates prices.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la réception'**
  String get receiveConfirm;

  /// Snackbar after confirming a receipt. Says what actually happened rather than just 'saved'.
  ///
  /// In fr, this message translates to:
  /// **'Réception enregistrée — le stock a été mis à jour.'**
  String get receiveConfirmed;

  /// Why the confirm button is disabled when nothing has been entered.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez au moins une quantité reçue.'**
  String get receiveNothing;

  /// Reminder of the ordered price under an edited actual price.
  ///
  /// In fr, this message translates to:
  /// **'Prix commandé : {price}'**
  String receiveOrderedPrice(String price);

  /// Confirmation shown when a unit price moves by more than the significant-change threshold. Usually either a real increase the owner must know about, or a typo.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer ce prix ?'**
  String get receivePriceConfirmTitle;

  /// Body of the significant price change confirmation.
  ///
  /// In fr, this message translates to:
  /// **'{item} était à {oldPrice}, maintenant {newPrice}. Confirmez-vous ce prix ?'**
  String receivePriceConfirmBody(String item, String oldPrice, String newPrice);

  /// Accepts the changed price and continues confirming the receipt.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le prix'**
  String get receivePriceConfirmAction;

  /// Free-text note covering the whole delivery.
  ///
  /// In fr, this message translates to:
  /// **'Note de réception'**
  String get receiveNoteLabel;

  /// Placeholder for the receipt note.
  ///
  /// In fr, this message translates to:
  /// **'Ex. chauffeur en retard, palette échangée'**
  String get receiveNoteHint;

  /// Note on the receiving screen explaining why it is a manager-level action.
  ///
  /// In fr, this message translates to:
  /// **'La réception modifie le stock et les prix : elle est réservée aux gérants.'**
  String get receiveManagerNotice;

  /// Title of the read-only receipt detail screen.
  ///
  /// In fr, this message translates to:
  /// **'Réception du {date}'**
  String receiptDetailTitle(String date);

  /// Who confirmed the delivery.
  ///
  /// In fr, this message translates to:
  /// **'Réceptionnée par {name}'**
  String receiptReceivedBy(String name);

  /// Link back from a receipt to its order.
  ///
  /// In fr, this message translates to:
  /// **'Commande {reference}'**
  String receiptOrderReference(String reference);

  /// Explains why the receipt detail has no edit or delete action.
  ///
  /// In fr, this message translates to:
  /// **'Une réception confirmée ne peut être ni modifiée ni supprimée. Toute correction passe par un ajustement de stock, pour que l\'historique reste vérifiable.'**
  String get receiptReadOnlyNotice;

  /// Total value of one delivery at the prices actually charged.
  ///
  /// In fr, this message translates to:
  /// **'Valeur de la réception'**
  String get receiptValueLabel;

  /// Receipt lines table column.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get receiptColumnNote;

  /// Shows a price change recorded by a receipt line.
  ///
  /// In fr, this message translates to:
  /// **'{oldPrice} → {newPrice}'**
  String receiptPriceChanged(String oldPrice, String newPrice);

  /// Description of a stock movement generated by confirming a receipt, as opposed to a manually entered delivery.
  ///
  /// In fr, this message translates to:
  /// **'Réception — commande {reference}'**
  String movementFromOrder(String reference);

  /// Action on a movement generated by a receipt, opening the receipt it came from.
  ///
  /// In fr, this message translates to:
  /// **'Voir la réception'**
  String get movementViewReceipt;

  /// Dashboard tile counting sent and partial orders.
  ///
  /// In fr, this message translates to:
  /// **'En attente de livraison'**
  String get dashboardTileOnOrder;

  /// Caption under the awaiting-delivery tile.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Rien en cours} =1{1 commande ouverte} other{{count} commandes ouvertes}}'**
  String dashboardOnOrderCaption(int count);

  /// Dashboard warning about orders left half-received. The real protection against stale open orders, independent of what anyone chose at receiving time.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 commande partielle ouverte depuis plus de {days} jours} other{{count} commandes partielles ouvertes depuis plus de {days} jours}}'**
  String dashboardStaleOrdersTitle(int count, int days);

  /// Explains why a stale partial order matters.
  ///
  /// In fr, this message translates to:
  /// **'Une commande laissée ouverte gonfle la quantité « en commande » et fausse l\'alerte de double commande.'**
  String get dashboardStaleOrdersBody;

  /// Opens the orders list filtered to open orders.
  ///
  /// In fr, this message translates to:
  /// **'Voir les commandes'**
  String get dashboardStaleOrdersAction;

  /// Shown on a low stock alert row when the item is already on an open order.
  ///
  /// In fr, this message translates to:
  /// **'{quantity} en commande'**
  String alertsOnOrder(String quantity);

  /// Shown on a low stock alert row when nobody has ordered the item yet. The contrast with the previous string is the entire point of showing on-order here.
  ///
  /// In fr, this message translates to:
  /// **'Rien en commande'**
  String get alertsNothingOnOrder;

  /// Action on the low stock alerts screen that starts drafts grouped by supplier.
  ///
  /// In fr, this message translates to:
  /// **'Créer les commandes'**
  String get alertsCreateOrders;

  /// Supplier detail tab showing contact details and prices.
  ///
  /// In fr, this message translates to:
  /// **'Fiche'**
  String get supplierTabDetails;

  /// Supplier detail tab listing orders placed with this supplier.
  ///
  /// In fr, this message translates to:
  /// **'Commandes'**
  String get supplierTabOrders;

  /// Empty state on the supplier order history tab.
  ///
  /// In fr, this message translates to:
  /// **'Aucune commande passée chez ce fournisseur.'**
  String get supplierOrdersEmpty;

  /// Store settings section covering order behaviour.
  ///
  /// In fr, this message translates to:
  /// **'Commandes'**
  String get storeSettingsOrders;

  /// Setting: how long a partial order may sit before the dashboard flags it.
  ///
  /// In fr, this message translates to:
  /// **'Alerte commande partielle (jours)'**
  String get storeSettingsStaleDays;

  /// Helper text for the stale partial order threshold.
  ///
  /// In fr, this message translates to:
  /// **'Une commande partiellement reçue est signalée sur le tableau de bord passé ce délai. Par défaut : 7 jours.'**
  String get storeSettingsStaleDaysHelp;

  /// Section and action that puts the prototype's data back to how it shipped. Present because a client demo gets walked several times in one sitting and the second run should not start from the first one's leftovers.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser la démonstration'**
  String get demoResetTitle;

  /// Explains what the reset action does and, implicitly, that nothing persists anyway.
  ///
  /// In fr, this message translates to:
  /// **'Remet les articles, les stocks, les commandes et les prix dans leur état d\'origine. Les modifications faites pendant la démonstration ne sont conservées que le temps de la session.'**
  String get demoResetBody;

  /// Shown in place of the reset action when nothing has been changed yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune modification à annuler.'**
  String get demoResetNothing;

  /// Confirmation before resetting.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser la démonstration ?'**
  String get demoResetConfirmTitle;

  /// Body of the reset confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Tout ce qui a été créé, modifié ou réceptionné depuis le démarrage sera annulé.'**
  String get demoResetConfirmBody;

  /// Confirms the reset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get demoResetConfirmAction;

  /// Snackbar after resetting the demo data.
  ///
  /// In fr, this message translates to:
  /// **'Démonstration réinitialisée.'**
  String get demoResetDone;

  /// Sole button on a dialog that explains why something cannot be done. Not 'OK' — the user is acknowledging an explanation, not approving an action.
  ///
  /// In fr, this message translates to:
  /// **'Compris'**
  String get actionUnderstood;

  /// Title of the sheet used to rename a category.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la catégorie'**
  String get editCategoryTitle;

  /// Title of the sheet used to edit a unit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'unité de mesure'**
  String get editUnitTitle;

  /// Inline error when the category name is already used in this store. Comparison ignores case and surrounding spaces.
  ///
  /// In fr, this message translates to:
  /// **'Une catégorie porte déjà ce nom.'**
  String get categoryNameTaken;

  /// Inline error when the unit name is already used in this store.
  ///
  /// In fr, this message translates to:
  /// **'Une unité porte déjà ce nom.'**
  String get unitNameTaken;

  /// Inline error when the unit abbreviation is already used. Checked as well as the name because the abbreviation is what appears next to every quantity in the app.
  ///
  /// In fr, this message translates to:
  /// **'Cette abréviation est déjà utilisée.'**
  String get unitAbbreviationTaken;

  /// Title of the dialog shown when a category cannot be deleted because items still use it.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer « {name} »'**
  String categoryDeleteBlockedTitle(String name);

  /// Explains why a category cannot be deleted and what to do about it. Naming the number and the fix is what makes it actionable.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 article est classé dans cette catégorie.} other{{count} articles sont classés dans cette catégorie.}} Reclassez-les avant de la supprimer.'**
  String categoryDeleteBlockedBody(int count);

  /// Title of the dialog shown when a unit cannot be deleted because items are measured in it.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer « {name} »'**
  String unitDeleteBlockedTitle(String name);

  /// Explains why a unit cannot be deleted and what to do about it.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 article est mesuré dans cette unité.} other{{count} articles sont mesurés dans cette unité.}} Changez leur unité avant de la supprimer.'**
  String unitDeleteBlockedBody(int count);

  /// Explains that a new item's starting quantity is recorded as an opening-balance movement rather than simply set.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré comme un ajustement d\'inventaire, pour que l\'historique des mouvements soit complet dès le départ.'**
  String get itemFormOpeningBalanceHelp;

  /// Link from the edit item form to the stock adjustment screen. Quantity is read-only when editing: changing it here would be an untraceable stock change hidden inside a routine form.
  ///
  /// In fr, this message translates to:
  /// **'Ajuster le stock'**
  String get itemFormAdjustStock;

  /// Explains why the quantity field is read-only on the edit item form.
  ///
  /// In fr, this message translates to:
  /// **'La quantité se modifie par un ajustement d\'inventaire, qui laisse une trace.'**
  String get itemFormQuantityLocked;

  /// Title of the dialog shown when an item cannot be deleted because it is on an open order.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer « {name} »'**
  String itemDeleteBlockedTitle(String name);

  /// Explains why an item cannot be deleted. The open order is a document a supplier is holding, so removing the article would leave it referring to nothing.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Cet article figure sur 1 commande en cours.} other{Cet article figure sur {count} commandes en cours.}} Réceptionnez ou clôturez-la avant de le supprimer.'**
  String itemDeleteBlockedBody(int count);

  /// States exactly what disappears alongside a deleted item. Naming the counts is what makes the confirmation honest rather than a formality.
  ///
  /// In fr, this message translates to:
  /// **'{movements, plural, =0{} =1{1 mouvement de stock} other{{movements} mouvements de stock}}{suppliers, plural, =0{} =1{ et 1 fournisseur associé} other{ et {suppliers} fournisseurs associés}} seront également supprimés.'**
  String itemDeleteCascadeWarning(int movements, int suppliers);

  /// Title of the dialog shown when a supplier cannot be deleted because they have an open order.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer « {name} »'**
  String supplierDeleteBlockedTitle(String name);

  /// Explains why a supplier cannot be deleted.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une commande en cours est adressée à ce fournisseur.} other{{count} commandes en cours sont adressées à ce fournisseur.}} Réceptionnez-les, clôturez-les ou annulez-les d\'abord.'**
  String supplierDeleteBlockedBody(int count);

  /// Snackbar after changing a supplier's price for an item. The change is recorded in that item-supplier pair's price history.
  ///
  /// In fr, this message translates to:
  /// **'Prix mis à jour.'**
  String get supplierPriceUpdated;

  /// Snackbar after promoting a supplier to an item's default.
  ///
  /// In fr, this message translates to:
  /// **'{supplier} est maintenant le fournisseur par défaut.'**
  String supplierDefaultChanged(String supplier);

  /// Snackbar shown when removing an item's default supplier automatically promotes the next cheapest, so the change does not happen silently.
  ///
  /// In fr, this message translates to:
  /// **'{supplier} devient le fournisseur par défaut.'**
  String supplierPromotedToDefault(String supplier);

  /// Snackbar after marking notifications read.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 notification marquée comme lue.} other{{count} notifications marquées comme lues.}}'**
  String notificationsMarkedRead(int count);

  /// Snackbar after creating a store.
  ///
  /// In fr, this message translates to:
  /// **'Établissement créé.'**
  String get storeCreated;

  /// Gestion Employée dropdown item — the staff roster.
  ///
  /// In fr, this message translates to:
  /// **'Personnel'**
  String get employeesNavPersonnel;

  /// Gestion Employée dropdown item — the pointage kiosk board. Not 'Tableau de bord', which is the dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de pointage'**
  String get employeesNavTimeclock;

  /// Gestion Employée dropdown item — the attendance log.
  ///
  /// In fr, this message translates to:
  /// **'Historique pointage'**
  String get employeesNavAttendanceHistory;

  /// Gestion Employée dropdown item — the payroll history.
  ///
  /// In fr, this message translates to:
  /// **'Historique de paiement'**
  String get employeesNavPayroll;

  /// Heading of the placeholder screen for a Gestion Employée section not yet built.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get employeeSectionComingSoonTitle;

  /// Placeholder body for the pointage board.
  ///
  /// In fr, this message translates to:
  /// **'Le tableau de pointage arrive dans une prochaine étape.'**
  String get employeeSectionComingSoonTimeclock;

  /// Placeholder body for the attendance history.
  ///
  /// In fr, this message translates to:
  /// **'L\'historique de pointage arrive dans une prochaine étape.'**
  String get employeeSectionComingSoonAttendanceHistory;

  /// Placeholder body for the payroll history.
  ///
  /// In fr, this message translates to:
  /// **'L\'historique de paiement arrive dans une prochaine étape.'**
  String get employeeSectionComingSoonPayroll;

  /// Employee role: full access to every store, payroll and staff management.
  ///
  /// In fr, this message translates to:
  /// **'Propriétaire'**
  String get employeeRoleOwner;

  /// Employee role: runs the store day to day, no payroll or staff management.
  ///
  /// In fr, this message translates to:
  /// **'Gérant'**
  String get employeeRoleManager;

  /// Employee role: no active app access; pointage done for them at the kiosk.
  ///
  /// In fr, this message translates to:
  /// **'Employé'**
  String get employeeRoleStaff;

  /// Describes the owner role on the role picker.
  ///
  /// In fr, this message translates to:
  /// **'Accès complet à tous les établissements, à la paie et à la gestion du personnel.'**
  String get employeeRoleOwnerBody;

  /// Describes the manager role on the role picker.
  ///
  /// In fr, this message translates to:
  /// **'Gère l\'établissement au quotidien : pointage, historique, absences. Pas la paie.'**
  String get employeeRoleManagerBody;

  /// Describes the staff role on the role picker.
  ///
  /// In fr, this message translates to:
  /// **'Aucun accès à l\'application. Son pointage est fait au tableau de bord partagé.'**
  String get employeeRoleStaffBody;

  /// Contract type: a monthly salary.
  ///
  /// In fr, this message translates to:
  /// **'Salarié fixe'**
  String get contractTypeFixed;

  /// Contract type: an hourly rate, paid only for hours worked.
  ///
  /// In fr, this message translates to:
  /// **'Extra'**
  String get contractTypeExtra;

  /// Staff roster page heading.
  ///
  /// In fr, this message translates to:
  /// **'Personnel'**
  String get employeesTitle;

  /// Supporting line on the roster page.
  ///
  /// In fr, this message translates to:
  /// **'Le personnel de cet établissement — coordonnées, contrat et rôle.'**
  String get employeesSubtitle;

  /// Primary action on the roster page.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un employé'**
  String get employeesAdd;

  /// Placeholder in the roster search field.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher (nom, CIN)'**
  String get employeesSearchHint;

  /// Toggle on the roster. Off by default, matching items and suppliers defaulting to what is currently usable.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les personnels retirés'**
  String get employeesShowArchived;

  /// Badge on an archived employee's row.
  ///
  /// In fr, this message translates to:
  /// **'Retiré'**
  String get employeesArchivedPill;

  /// Empty state on the roster when the store has none.
  ///
  /// In fr, this message translates to:
  /// **'Aucun employé'**
  String get employeesEmpty;

  /// Supporting line for the fully-empty roster.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez les membres de votre personnel pour suivre leur pointage et leur paie.'**
  String get employeesEmptyBody;

  /// Compact CIN label shown under an employee's name.
  ///
  /// In fr, this message translates to:
  /// **'CIN {cin}'**
  String employeeCinLabel(String cin);

  /// Roster KPI: count of active employees.
  ///
  /// In fr, this message translates to:
  /// **'Personnel actif'**
  String get employeesKpiActive;

  /// Roster KPI label: split between fixed and extra contracts.
  ///
  /// In fr, this message translates to:
  /// **'Fixes / Extras'**
  String get employeesKpiContractSplit;

  /// Roster KPI value: the fixed/extra split.
  ///
  /// In fr, this message translates to:
  /// **'{fixed} fixes · {extra} extras'**
  String employeesKpiContractSplitValue(int fixed, int extra);

  /// Roster KPI: count of owners and managers.
  ///
  /// In fr, this message translates to:
  /// **'Gérants'**
  String get employeesKpiManagers;

  /// Roster KPI: employees hired this calendar month.
  ///
  /// In fr, this message translates to:
  /// **'Embauches ce mois'**
  String get employeesKpiHiredThisMonth;

  /// Photo section label on the employee form.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get employeeFormPhoto;

  /// Button under the employee photo tile. Mocked — see employeeFormPhotoMockNotice.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get employeeFormPhotoAction;

  /// Warning snackbar shown when tapping the mocked photo picker.
  ///
  /// In fr, this message translates to:
  /// **'Le choix de photo n\'est pas encore disponible dans cette version.'**
  String get employeeFormPhotoMockNotice;

  /// Employee first name field label.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get employeeFormFirstName;

  /// Employee last name field label.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get employeeFormLastName;

  /// Employee national identity card number field label.
  ///
  /// In fr, this message translates to:
  /// **'N° de carte d\'identité'**
  String get employeeFormCin;

  /// Employee phone field label.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get employeeFormPhone;

  /// Employee email field label.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get employeeFormEmail;

  /// Inline error when the CIN already belongs to another employee.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro de carte d\'identité est déjà utilisé.'**
  String get employeeCinTaken;

  /// Inline error when the email already belongs to another employee.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse e-mail est déjà utilisée.'**
  String get employeeEmailTaken;

  /// Role section header on the employee form.
  ///
  /// In fr, this message translates to:
  /// **'Rôle et accès'**
  String get employeeFormRole;

  /// Employment section header on the employee form and detail page.
  ///
  /// In fr, this message translates to:
  /// **'Contrat et rémunération'**
  String get employeeFormEmployment;

  /// Contract type dropdown label.
  ///
  /// In fr, this message translates to:
  /// **'Type de contrat'**
  String get employeeFormContractType;

  /// Pay field label when the contract is fixed.
  ///
  /// In fr, this message translates to:
  /// **'Salaire mensuel (€)'**
  String get employeeFormPayMonthly;

  /// Pay field label when the contract is extra.
  ///
  /// In fr, this message translates to:
  /// **'Tarif horaire (€/h)'**
  String get employeeFormPayHourly;

  /// Schedule section header on the employee form and detail page.
  ///
  /// In fr, this message translates to:
  /// **'Horaires'**
  String get employeeFormSchedule;

  /// Scheduled start-of-day field label.
  ///
  /// In fr, this message translates to:
  /// **'Heure d\'arrivée'**
  String get employeeFormScheduleStart;

  /// Scheduled end-of-day field label.
  ///
  /// In fr, this message translates to:
  /// **'Heure de départ'**
  String get employeeFormScheduleEnd;

  /// Inline error when a schedule time does not parse.
  ///
  /// In fr, this message translates to:
  /// **'Format attendu : HH:MM'**
  String get employeeFormScheduleInvalid;

  /// Helper text under the schedule fields.
  ///
  /// In fr, this message translates to:
  /// **'Laissez vide pour utiliser les horaires de l\'établissement.'**
  String get employeeFormScheduleHelp;

  /// Snackbar confirming a new employee was created.
  ///
  /// In fr, this message translates to:
  /// **'Employé ajouté'**
  String get employeeCreated;

  /// Snackbar confirming an employee was edited.
  ///
  /// In fr, this message translates to:
  /// **'Employé modifié'**
  String get employeeUpdated;

  /// Hire date line on the employee detail header.
  ///
  /// In fr, this message translates to:
  /// **'Embauché le {date}'**
  String employeeHiredOn(String date);

  /// Section heading on the employee detail page for contact fields.
  ///
  /// In fr, this message translates to:
  /// **'Coordonnées'**
  String get employeeDetailContact;

  /// Shown for the schedule when the employee has no custom start/end.
  ///
  /// In fr, this message translates to:
  /// **'Horaires de l\'établissement'**
  String get employeeScheduleStoreHours;

  /// Section heading for one employee's attendance history.
  ///
  /// In fr, this message translates to:
  /// **'Historique de pointage'**
  String get employeeHistoryTitle;

  /// Section heading for one employee's payroll history.
  ///
  /// In fr, this message translates to:
  /// **'Historique de paiement'**
  String get employeePayrollTitle;

  /// Destructive confirmation dialog title for archiving an employee. Regular space before the question mark, matching the rest of the file.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name} ?'**
  String employeeArchiveTitle(String name);

  /// Body of the archive-employee confirmation dialog.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne n\'apparaîtra plus dans le personnel actif. Son historique de pointage et de paie reste conservé.'**
  String get employeeArchiveBody;

  /// Confirms archiving an employee. Deliberately not 'Supprimer' — this is a soft removal.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get employeeArchiveConfirm;

  /// Snackbar confirming an employee was archived.
  ///
  /// In fr, this message translates to:
  /// **'Employé retiré'**
  String get employeeArchived;

  /// Action on an archived employee's detail page bringing them back to active.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get employeeRestore;

  /// Snackbar confirming an archived employee was restored.
  ///
  /// In fr, this message translates to:
  /// **'Employé restauré'**
  String get employeeRestored;

  /// Status line on an archived employee's detail page.
  ///
  /// In fr, this message translates to:
  /// **'Retiré le {date}'**
  String employeeDetailArchivedOn(String date);
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
