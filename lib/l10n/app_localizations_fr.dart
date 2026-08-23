// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Gestion de Stock';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navInventory => 'Inventaire';

  @override
  String get navStockMovement => 'Mouvements de stock';

  @override
  String get navSuppliers => 'Fournisseurs';

  @override
  String get navCatalog => 'Catégories et unités';

  @override
  String get navAlerts => 'Alertes';

  @override
  String get navReports => 'Rapports';

  @override
  String get navTeam => 'Équipe';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get stockStatusInStock => 'En stock';

  @override
  String get stockStatusLowStock => 'Stock faible';

  @override
  String get stockStatusOutOfStock => 'Rupture de stock';

  @override
  String get actionAddItem => 'Ajouter un article';

  @override
  String get actionAddDelivery => 'Enregistrer une livraison';

  @override
  String get actionLogUsage => 'Sortie de stock';

  @override
  String get actionAdjustStock => 'Ajuster le stock';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionBack => 'Retour';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionConfirm => 'Confirmer';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get actionUndo => 'Annuler';

  @override
  String get actionCreateNew => '+ Créer';

  @override
  String get actionSearch => 'Rechercher';

  @override
  String get actionFilter => 'Filtrer';

  @override
  String get actionExport => 'Exporter';

  @override
  String get actionViewAll => 'Tout afficher';

  @override
  String get topBarNotifications => 'Notifications';

  @override
  String get topBarAccount => 'Mon compte';

  @override
  String get actionLogout => 'Se déconnecter';

  @override
  String get storeSwitcherLabel => 'Établissement';

  @override
  String get storeSwitcherChange => 'Changer d\'établissement';

  @override
  String get offlineBannerTitle => 'Mode hors ligne';

  @override
  String offlineBannerPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente',
      one: '1 modification en attente',
      zero: 'Aucune modification en attente',
    );
    return '$_temp0';
  }

  @override
  String get emptyStateNoItemsTitle => 'Aucun article pour le moment';

  @override
  String get emptyStateNoItemsBody =>
      'Ajoutez votre premier article pour commencer à suivre votre stock.';

  @override
  String get emptyStateNoResultsTitle => 'Aucun résultat';

  @override
  String get emptyStateNoResultsBody =>
      'Essayez un autre terme ou modifiez vos filtres.';

  @override
  String get loadingLabel => 'Chargement…';

  @override
  String get errorStateTitle => 'Une erreur est survenue';

  @override
  String get errorStateBody =>
      'Impossible d\'afficher ces données pour le moment.';

  @override
  String confirmDeleteTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get confirmDeleteIrreversible => 'Cette action est irréversible.';

  @override
  String get loginTitle => 'Connexion';

  @override
  String get loginSubtitle =>
      'Connectez-vous pour accéder à vos établissements.';

  @override
  String get loginEmail => 'Adresse e-mail';

  @override
  String get loginPassword => 'Mot de passe';

  @override
  String get loginRemember => 'Rester connecté';

  @override
  String get loginForgot => 'Mot de passe oublié ?';

  @override
  String get loginSubmit => 'Se connecter';

  @override
  String get loginDemoNotice =>
      'Prototype de démonstration — aucune authentification réelle.';

  @override
  String get forgotTitle => 'Réinitialiser le mot de passe';

  @override
  String get forgotBody =>
      'Saisissez votre adresse e-mail et nous vous enverrons un lien de réinitialisation.';

  @override
  String get forgotSubmit => 'Envoyer le lien';

  @override
  String get forgotSentTitle => 'Vérifiez votre boîte mail';

  @override
  String forgotSentBody(String email) {
    return 'Si un compte existe pour $email, un lien de réinitialisation vient d\'être envoyé.';
  }

  @override
  String get forgotBackToLogin => 'Retour à la connexion';

  @override
  String get onboardingTitle => 'Bienvenue';

  @override
  String get onboardingBody =>
      'Suivez votre stock, vos fournisseurs et vos prix sur tous vos établissements, depuis une seule application.';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String get onboardingFeatureStock => 'Un stock toujours à jour';

  @override
  String get onboardingFeatureStockBody =>
      'Enregistrez les livraisons et les sorties en quelques secondes, même en plein service.';

  @override
  String get onboardingFeaturePrices => 'Comparez vos fournisseurs';

  @override
  String get onboardingFeaturePricesBody =>
      'Chaque fournisseur a son prix pour un même produit. Voyez lequel vous coûte le moins cher.';

  @override
  String get onboardingFeatureAlerts => 'Ne tombez plus en rupture';

  @override
  String get onboardingFeatureAlertsBody =>
      'Recevez une alerte dès qu\'un article passe sous son seuil.';

  @override
  String get storesTitle => 'Vos établissements';

  @override
  String get storesSubtitle =>
      'Sélectionnez l\'établissement que vous souhaitez gérer.';

  @override
  String get storesAdd => 'Ajouter un établissement';

  @override
  String storesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
      zero: 'Aucun article',
    );
    return '$_temp0';
  }

  @override
  String storesAlertCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alertes',
      one: '1 alerte',
      zero: 'Aucune alerte',
    );
    return '$_temp0';
  }

  @override
  String get storesNewBadge => 'Nouveau';

  @override
  String get addStoreTitle => 'Ajouter un établissement';

  @override
  String get addStoreName => 'Nom de l\'établissement';

  @override
  String get addStoreNameHint => 'Ex. : Brasserie du Sablon';

  @override
  String get addStoreAddress => 'Adresse';

  @override
  String get addStorePostalCode => 'Code postal';

  @override
  String get addStoreCity => 'Commune';

  @override
  String get addStorePhone => 'Téléphone';

  @override
  String get addStoreSubmit => 'Créer l\'établissement';

  @override
  String get addStoreCreated => 'Établissement créé';

  @override
  String get inventoryTitle => 'Inventaire';

  @override
  String get inventorySearchHint => 'Rechercher un article…';

  @override
  String get inventoryFilterCategory => 'Catégorie';

  @override
  String get inventoryFilterSupplier => 'Fournisseur';

  @override
  String get inventoryFilterAll => 'Toutes';

  @override
  String get inventoryFilterAllSuppliers => 'Tous';

  @override
  String get inventoryFilterLowOnly => 'Stock faible uniquement';

  @override
  String inventoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
      zero: 'Aucun article',
    );
    return '$_temp0';
  }

  @override
  String get inventoryClearFilters => 'Effacer les filtres';

  @override
  String get inventorySelectPrompt => 'Sélectionnez un article';

  @override
  String get inventorySelectPromptBody =>
      'Choisissez un article dans la liste pour voir son détail, ses fournisseurs et ses prix.';

  @override
  String get itemQuantityLabel => 'Quantité en stock';

  @override
  String get itemThresholdLabel => 'Seuil d\'alerte';

  @override
  String get itemCategoryLabel => 'Catégorie';

  @override
  String get itemUnitLabel => 'Unité';

  @override
  String get itemUpdatedLabel => 'Mis à jour';

  @override
  String get itemNoteLabel => 'Note';

  @override
  String get itemSuppliersTitle => 'Fournisseurs et prix';

  @override
  String get itemSuppliersSubtitle =>
      'Un même produit peut avoir plusieurs fournisseurs, chacun avec son prix.';

  @override
  String get itemNoSuppliersTitle => 'Aucun fournisseur associé';

  @override
  String get itemNoSuppliersBody =>
      'Associez un fournisseur pour enregistrer un prix et suivre son évolution.';

  @override
  String get itemLinkSupplier => 'Associer un fournisseur';

  @override
  String get itemDefaultSupplier => 'Par défaut';

  @override
  String get itemCheapest => 'Meilleur prix';

  @override
  String itemOverpayWarning(String amount, String unit, String supplier) {
    return 'Vous payez $amount de plus par $unit qu\'avec $supplier.';
  }

  @override
  String itemPriceUpdated(String date) {
    return 'Mis à jour le $date';
  }

  @override
  String get itemViewPriceHistory => 'Historique des prix';

  @override
  String get itemMovementsTitle => 'Mouvements récents';

  @override
  String get itemNoMovements => 'Aucun mouvement enregistré';

  @override
  String get itemDeleted => 'Article supprimé';

  @override
  String get itemSupplierRemoved => 'Fournisseur dissocié';

  @override
  String get itemRemoveSupplierWarning =>
      'Le prix enregistré et son historique pour ce fournisseur seront perdus.';

  @override
  String get addItemTitle => 'Ajouter un article';

  @override
  String get editItemTitle => 'Modifier l\'article';

  @override
  String get itemFormName => 'Nom de l\'article';

  @override
  String get itemFormNameHint => 'Ex. : Blanc de poulet';

  @override
  String get itemFormStartingQuantity => 'Quantité de départ';

  @override
  String get itemFormThresholdHelp =>
      'Vous serez alerté lorsque le stock atteindra ce niveau ou passera en dessous.';

  @override
  String get itemFormNoCostTitle => 'Pas de prix sur cette page';

  @override
  String get itemFormNoCostBody =>
      'Le prix dépend du fournisseur. Associez un ou plusieurs fournisseurs à cet article pour enregistrer leurs prix respectifs.';

  @override
  String get itemCreated => 'Article créé';

  @override
  String get itemUpdated => 'Article modifié';

  @override
  String get itemFormCreateCategory => '+ Créer une catégorie';

  @override
  String get itemFormCreateUnit => '+ Créer une unité';

  @override
  String get createCategoryTitle => 'Nouvelle catégorie';

  @override
  String get createCategoryName => 'Nom de la catégorie';

  @override
  String get createCategoryHint => 'Ex. : Fruits & Légumes';

  @override
  String get categoryCreated => 'Catégorie créée';

  @override
  String get createUnitTitle => 'Nouvelle unité de mesure';

  @override
  String get createUnitName => 'Nom complet';

  @override
  String get createUnitNameHint => 'Ex. : Kilogramme';

  @override
  String get createUnitAbbreviation => 'Abréviation';

  @override
  String get createUnitAbbreviationHint => 'Ex. : kg';

  @override
  String get unitCreated => 'Unité créée';

  @override
  String get linkSupplierTitle => 'Associer un fournisseur';

  @override
  String linkSupplierFor(String item) {
    return 'Pour $item';
  }

  @override
  String get linkSupplierPick => 'Fournisseur';

  @override
  String get linkSupplierCreate => '+ Créer un fournisseur';

  @override
  String linkSupplierPrice(String unit) {
    return 'Prix par $unit';
  }

  @override
  String get linkSupplierPriceHelp =>
      'Le prix de ce fournisseur pour cet article. Chaque modification sera enregistrée dans l\'historique.';

  @override
  String get linkSupplierSetDefault => 'Définir comme fournisseur par défaut';

  @override
  String get linkSupplierSetDefaultHelp =>
      'Ce fournisseur sera présélectionné lors de l\'enregistrement d\'une livraison.';

  @override
  String get linkSupplierSubmit => 'Associer';

  @override
  String get supplierLinked => 'Fournisseur associé';

  @override
  String get priceHistoryTitle => 'Historique des prix';

  @override
  String priceHistoryFor(String item, String supplier) {
    return '$item — $supplier';
  }

  @override
  String get priceHistoryCurrent => 'Prix actuel';

  @override
  String priceHistorySince(String date) {
    return 'Depuis le $date';
  }

  @override
  String get priceHistoryTotalChange => 'Évolution totale';

  @override
  String priceHistoryChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications',
      one: '1 modification',
      zero: 'Aucune modification',
    );
    return '$_temp0';
  }

  @override
  String get priceHistoryEmpty => 'Aucune modification de prix';

  @override
  String get priceHistoryEmptyBody =>
      'Le prix n\'a pas changé depuis son enregistrement.';

  @override
  String priceHistoryChangedBy(String name) {
    return 'Par $name';
  }
}
