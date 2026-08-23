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

  /// Placeholder in the inventory search field.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un article…'**
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
