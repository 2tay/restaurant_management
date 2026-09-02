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
  String get navEmployees => 'Gestion Employée';

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
  String get actionFullScreen => 'Plein écran';

  @override
  String get actionExitFullScreen => 'Quitter le plein écran';

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
  String get shellNoStoreTitle => 'Aucun établissement';

  @override
  String get shellNoStoreBody =>
      'La base locale ne contient aucun établissement. Réinitialisez la démonstration ou créez un établissement pour commencer.';

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
  String get inventorySearchHint => 'Rechercher un article ou un code-barres…';

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

  @override
  String get categoriesTitle => 'Catégories';

  @override
  String get categoriesSubtitle =>
      'Les catégories servent à classer et filtrer vos articles.';

  @override
  String get categoriesAdd => 'Ajouter une catégorie';

  @override
  String get categoriesEmpty => 'Aucune catégorie';

  @override
  String get categoriesEmptyBody =>
      'Créez une première catégorie pour organiser vos articles.';

  @override
  String categoriesItemCount(int count) {
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
  String categoriesInUseWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count articles utilisent cette catégorie et devront être reclassés.',
      one: '1 article utilise cette catégorie et devra être reclassé.',
    );
    return '$_temp0';
  }

  @override
  String get categoryDeleted => 'Catégorie supprimée';

  @override
  String get categoryUpdated => 'Catégorie modifiée';

  @override
  String get unitsTitle => 'Unités de mesure';

  @override
  String get unitsSubtitle =>
      'Kilogramme, litre, bac, caisse — définissez les unités utilisées dans votre cuisine.';

  @override
  String get unitsAdd => 'Ajouter une unité';

  @override
  String get unitsEmpty => 'Aucune unité de mesure';

  @override
  String get unitsEmptyBody =>
      'Créez une première unité pour pouvoir ajouter des articles.';

  @override
  String unitsInUseWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles utilisent cette unité.',
      one: '1 article utilise cette unité.',
    );
    return '$_temp0';
  }

  @override
  String get unitDeleted => 'Unité supprimée';

  @override
  String get unitUpdated => 'Unité modifiée';

  @override
  String get movementsTitle => 'Mouvements de stock';

  @override
  String get movementsSubtitle =>
      'Historique de toutes les entrées, sorties et corrections.';

  @override
  String get movementsEmpty => 'Aucun mouvement';

  @override
  String get movementsEmptyBody =>
      'Les livraisons et sorties de stock apparaîtront ici.';

  @override
  String movementsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mouvements',
      one: '1 mouvement',
      zero: 'Aucun mouvement',
    );
    return '$_temp0';
  }

  @override
  String get movementsFilterType => 'Type';

  @override
  String get movementsFilterAllTypes => 'Tous les types';

  @override
  String get movementsFilterPeriod => 'Période';

  @override
  String get movementsFilterUser => 'Utilisateur';

  @override
  String get movementsFilterAllUsers => 'Tous';

  @override
  String get periodLast7Days => '7 derniers jours';

  @override
  String get periodLast30Days => '30 derniers jours';

  @override
  String get periodLast90Days => '90 derniers jours';

  @override
  String get periodAll => 'Tout l\'historique';

  @override
  String get movementTypeIn => 'Livraison';

  @override
  String get movementTypeOut => 'Sortie';

  @override
  String get movementTypeAdjustment => 'Ajustement';

  @override
  String get reasonSale => 'Vente';

  @override
  String get reasonWaste => 'Perte';

  @override
  String get reasonSpoilage => 'Produit abîmé';

  @override
  String get reasonTransfer => 'Transfert';

  @override
  String get stockInTitle => 'Enregistrer une livraison';

  @override
  String get stockInSubtitle =>
      'Ajoutez au stock les articles que vous venez de recevoir.';

  @override
  String get stockInItem => 'Article';

  @override
  String get stockInSupplier => 'Fournisseur';

  @override
  String get stockInQuantity => 'Quantité reçue';

  @override
  String stockInUnitPrice(String unit) {
    return 'Prix payé par $unit';
  }

  @override
  String stockInPriceAutofilled(String supplier) {
    return 'Prix actuel de $supplier. Modifiez-le si la facture diffère.';
  }

  @override
  String stockInPriceChanged(String old) {
    return 'Ce prix diffère du prix enregistré ($old). L\'écart sera ajouté à l\'historique.';
  }

  @override
  String get stockInDate => 'Date de réception';

  @override
  String get stockInTotal => 'Total de la ligne';

  @override
  String get stockInSubmit => 'Enregistrer la livraison';

  @override
  String get stockInRecorded => 'Livraison enregistrée';

  @override
  String get stockInNoSupplier =>
      'Cet article n\'a pas encore de fournisseur associé.';

  @override
  String get stockOutTitle => 'Sortie de stock';

  @override
  String get stockOutSubtitle =>
      'Enregistrez ce qui a été vendu, utilisé ou perdu.';

  @override
  String get stockOutQuantity => 'Quantité sortie';

  @override
  String get stockOutReason => 'Motif';

  @override
  String stockOutAvailable(String quantity) {
    return 'Disponible : $quantity';
  }

  @override
  String get stockOutExceedsStock => 'La quantité dépasse le stock disponible.';

  @override
  String get stockOutSubmit => 'Enregistrer la sortie';

  @override
  String get stockOutRecorded => 'Sortie enregistrée';

  @override
  String get adjustmentTitle => 'Ajustement de stock';

  @override
  String get adjustmentSubtitle =>
      'Corrigez le stock enregistré après un comptage physique.';

  @override
  String get adjustmentSystemQuantity => 'Quantité au système';

  @override
  String get adjustmentCountedQuantity => 'Quantité comptée';

  @override
  String get adjustmentDifference => 'Écart';

  @override
  String get adjustmentNote => 'Motif de l\'écart';

  @override
  String get adjustmentNoteHint => 'Ex. : épluchures non comptabilisées';

  @override
  String get adjustmentSubmit => 'Enregistrer l\'ajustement';

  @override
  String get adjustmentRecorded => 'Ajustement enregistré';

  @override
  String get adjustmentLargeConfirmTitle => 'Confirmer cet ajustement ?';

  @override
  String adjustmentLargeConfirmBody(
    String amount,
    String item,
    String percent,
  ) {
    return 'Vous retirez $amount du stock de $item, soit une baisse de $percent. Vérifiez votre comptage avant de confirmer.';
  }

  @override
  String get adjustmentNoChange => 'Aucun écart — rien à enregistrer.';

  @override
  String get suppliersTitle => 'Fournisseurs';

  @override
  String get suppliersSubtitle =>
      'Vos fournisseurs et les produits qu\'ils livrent.';

  @override
  String get suppliersAdd => 'Ajouter un fournisseur';

  @override
  String get suppliersSearchHint => 'Rechercher un fournisseur…';

  @override
  String get suppliersEmpty => 'Aucun fournisseur';

  @override
  String get suppliersEmptyBody =>
      'Ajoutez un fournisseur pour enregistrer ses prix et vos livraisons.';

  @override
  String suppliersProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits',
      one: '1 produit',
      zero: 'Aucun produit',
    );
    return '$_temp0';
  }

  @override
  String get supplierContact => 'Contact';

  @override
  String get supplierProducts => 'Produits fournis';

  @override
  String get supplierProductsEmpty => 'Aucun produit associé à ce fournisseur';

  @override
  String get supplierEditPrices => 'Modifier les tarifs';

  @override
  String get supplierCreated => 'Fournisseur créé';

  @override
  String get supplierUpdated => 'Fournisseur modifié';

  @override
  String get supplierDeleted => 'Fournisseur supprimé';

  @override
  String supplierDeleteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count produits sont fournis par ce fournisseur. Leurs prix et historiques seront perdus.',
      one:
          '1 produit est fourni par ce fournisseur. Son prix et son historique seront perdus.',
    );
    return '$_temp0';
  }

  @override
  String get supplierFormName => 'Nom du fournisseur';

  @override
  String get supplierFormNameHint => 'Ex. : Grossiste Central Bruxelles';

  @override
  String get supplierFormContactName => 'Personne de contact';

  @override
  String get supplierFormEmail => 'E-mail';

  @override
  String get supplierFormPhone => 'Téléphone';

  @override
  String get supplierFormNote => 'Note';

  @override
  String get supplierFormNoteHint =>
      'Ex. : livraison les mardis et vendredis avant 10h';

  @override
  String get addSupplierTitle => 'Ajouter un fournisseur';

  @override
  String get editSupplierTitle => 'Modifier le fournisseur';

  @override
  String get supplierPricingTitle => 'Tarifs';

  @override
  String get supplierPricingSubtitle =>
      'Modifiez un prix pour l\'enregistrer dans l\'historique.';

  @override
  String get supplierPricingColumnProduct => 'Produit';

  @override
  String get supplierPricingColumnPrice => 'Prix unitaire';

  @override
  String get supplierPricingColumnUpdated => 'Dernière mise à jour';

  @override
  String get supplierPricingColumnCompare => 'Écart au meilleur prix';

  @override
  String get supplierPricingBest => 'Meilleur';

  @override
  String get priceUpdated => 'Prix mis à jour';

  @override
  String get dashboardTitle => 'Tableau de bord';

  @override
  String dashboardGreeting(String name) {
    return 'Bonjour $name';
  }

  @override
  String get dashboardTileStockValue => 'Valeur du stock';

  @override
  String get dashboardTileItems => 'Articles suivis';

  @override
  String get dashboardTileLowStock => 'À réapprovisionner';

  @override
  String get dashboardTileSuppliers => 'Fournisseurs';

  @override
  String get dashboardQuickActions => 'Actions rapides';

  @override
  String get dashboardRecentActivity => 'Activité récente';

  @override
  String get dashboardNoActivity => 'Aucune activité pour le moment';

  @override
  String get dashboardNoActivityBody =>
      'Enregistrez une livraison ou une sortie pour commencer.';

  @override
  String get dashboardAlertsTitle => 'Articles à surveiller';

  @override
  String get dashboardAllGood => 'Tout est en stock';

  @override
  String get dashboardAllGoodBody => 'Aucun article sous son seuil d\'alerte.';

  @override
  String get dashboardEmptyStore => 'Cet établissement est vide';

  @override
  String get dashboardEmptyStoreBody =>
      'Commencez par ajouter vos articles pour suivre votre stock.';

  @override
  String get alertsTitle => 'Alertes de stock';

  @override
  String get alertsSubtitle =>
      'Articles à réapprovisionner, les plus urgents en premier.';

  @override
  String get alertsEmpty => 'Aucune alerte';

  @override
  String get alertsEmptyBody =>
      'Tous vos articles sont au-dessus de leur seuil d\'alerte.';

  @override
  String alertsShortfall(String quantity) {
    return 'Il manque $quantity pour atteindre le seuil';
  }

  @override
  String alertsOrderFrom(String supplier) {
    return 'Commander chez $supplier';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'Aucune notification';

  @override
  String get notificationsEmptyBody =>
      'Les alertes de stock et les changements de prix apparaîtront ici.';

  @override
  String get notificationsMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notificationsAllRead => 'Toutes les notifications sont lues';

  @override
  String notificationsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non lues',
      one: '1 non lue',
      zero: 'Aucune non lue',
    );
    return '$_temp0';
  }

  @override
  String get notificationsFilterAll => 'Toutes';

  @override
  String get notificationsFilterUnread => 'Non lues';

  @override
  String get reportsTitle => 'Rapports';

  @override
  String get reportsSubtitle =>
      'Valeur de votre stock, consommation et comparaison des prix.';

  @override
  String get reportsValuation => 'Valorisation du stock';

  @override
  String get reportsValuationBody =>
      'Combien vaut ce que vous avez en réserve, par catégorie et par article.';

  @override
  String get reportsComparison => 'Comparaison des prix';

  @override
  String get reportsComparisonBody =>
      'Le même produit chez plusieurs fournisseurs, prix côte à côte.';

  @override
  String get reportsUsage => 'Consommation et pertes';

  @override
  String get reportsUsageBody =>
      'Ce qui sort de votre stock, et la part perdue.';

  @override
  String get reportsPotentialSaving => 'Économie potentielle';

  @override
  String get reportsPotentialSavingBody =>
      'Estimation annuelle si chaque article était commandé au meilleur prix disponible.';

  @override
  String get reportsUsage30Days => 'Consommation (30 jours)';

  @override
  String get reportsWasteShare => 'Part de pertes';

  @override
  String get reportsOpen => 'Ouvrir le rapport';

  @override
  String get reportsExportTitle => 'Exporter le rapport';

  @override
  String get reportsExportBody =>
      'Choisissez un format. Le fichier sera téléchargé sur cet appareil.';

  @override
  String get reportsExportPdf => 'Document PDF';

  @override
  String get reportsExportCsv => 'Tableur CSV';

  @override
  String get reportsExportUnavailable =>
      'L\'export sera disponible dans une prochaine version.';

  @override
  String get valuationTitle => 'Valorisation du stock';

  @override
  String get valuationTotal => 'Valeur totale';

  @override
  String get valuationByCategory => 'Par catégorie';

  @override
  String get valuationByItem => 'Articles les plus valorisés';

  @override
  String get valuationBasis =>
      'Valorisé au prix du fournisseur par défaut de chaque article.';

  @override
  String get valuationColumnCategory => 'Catégorie';

  @override
  String get valuationColumnItems => 'Articles';

  @override
  String get valuationColumnValue => 'Valeur';

  @override
  String get valuationColumnShare => 'Part';

  @override
  String get comparisonTitle => 'Comparaison des prix';

  @override
  String get comparisonSubtitle =>
      'Sélectionnez un article pour comparer les prix de tous ses fournisseurs.';

  @override
  String get comparisonPickItem => 'Article à comparer';

  @override
  String get comparisonColumnSupplier => 'Fournisseur';

  @override
  String get comparisonColumnPrice => 'Prix';

  @override
  String get comparisonColumnDifference => 'Écart';

  @override
  String get comparisonColumnUpdated => 'Mis à jour';

  @override
  String get comparisonSingleSupplier => 'Un seul fournisseur pour cet article';

  @override
  String get comparisonSingleSupplierBody =>
      'Associez un second fournisseur pour pouvoir comparer les prix.';

  @override
  String get usageReportTitle => 'Consommation et pertes';

  @override
  String get usageTrend => 'Consommation quotidienne';

  @override
  String get usageWasteTrend => 'Part de pertes par semaine';

  @override
  String get usageTotal => 'Total consommé';

  @override
  String get usageWasteValue => 'Valeur des pertes';

  @override
  String get addEmployeeTitle => 'Ajouter un employé';

  @override
  String get editEmployeeTitle => 'Modifier l\'employé';

  @override
  String get storeSettingsTitle => 'Paramètres de l\'établissement';

  @override
  String get storeSettingsGeneral => 'Informations générales';

  @override
  String get storeSettingsPreferences => 'Préférences';

  @override
  String get storeSettingsDefaultUnit => 'Unité par défaut';

  @override
  String get storeSettingsSaved => 'Paramètres enregistrés';

  @override
  String get accountSettingsTitle => 'Paramètres du compte';

  @override
  String get accountProfile => 'Profil';

  @override
  String get accountSecurity => 'Sécurité';

  @override
  String get accountChangePassword => 'Changer le mot de passe';

  @override
  String get accountLinkedStores => 'Établissements liés';

  @override
  String get notificationPrefsTitle => 'Préférences de notification';

  @override
  String get notificationPrefsSubtitle =>
      'Choisissez ce dont vous souhaitez être averti.';

  @override
  String get notificationPrefLowStock => 'Alertes de stock faible';

  @override
  String get notificationPrefLowStockBody =>
      'Recevez une alerte dès qu\'un article passe sous son seuil.';

  @override
  String get notificationPrefPriceChange => 'Changements de prix';

  @override
  String get notificationPrefPriceChangeBody =>
      'Soyez averti quand un fournisseur modifie un prix.';

  @override
  String get notificationPrefLargeAdjustment => 'Ajustements importants';

  @override
  String get notificationPrefLargeAdjustmentBody =>
      'Soyez averti lorsqu\'un comptage corrige fortement le stock.';

  @override
  String get notificationPrefDeliveries => 'Livraisons enregistrées';

  @override
  String get notificationPrefDeliveriesBody =>
      'Recevez un résumé de chaque livraison enregistrée.';

  @override
  String get syncTitle => 'État de la synchronisation';

  @override
  String get syncSubtitle =>
      'L\'application fonctionne hors ligne et se synchronise dès que la connexion revient.';

  @override
  String get syncLastSynced => 'Dernière synchronisation';

  @override
  String get syncPending => 'Modifications en attente';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get syncStarted => 'Synchronisation en cours…';

  @override
  String get syncOnline => 'Connecté';

  @override
  String get syncOffline => 'Hors ligne';

  @override
  String get syncDemoToggle => 'Simuler le mode hors ligne';

  @override
  String get syncDemoToggleBody =>
      'Pour la démonstration : affiche la bannière hors ligne dans toute l\'application.';

  @override
  String get syncLocalOnlyNote =>
      'Les données sont enregistrées sur cet appareil. La synchronisation entre appareils sera ajoutée en phase 3.';

  @override
  String get searchTitle => 'Recherche';

  @override
  String get searchHint => 'Article, code-barres, fournisseur…';

  @override
  String get searchPrompt => 'Que cherchez-vous ?';

  @override
  String get searchPromptBody =>
      'Recherchez parmi vos articles, fournisseurs et catégories.';

  @override
  String get searchSectionItems => 'Articles';

  @override
  String get searchSectionSuppliers => 'Fournisseurs';

  @override
  String get searchSectionCategories => 'Catégories';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
      zero: 'Aucun résultat',
    );
    return '$_temp0';
  }

  @override
  String storesCreatedOn(String date) {
    return 'Créé le $date';
  }

  @override
  String get actionShow => 'Afficher';

  @override
  String get actionHide => 'Masquer';

  @override
  String get a11yDecrease => 'Diminuer';

  @override
  String get a11yIncrease => 'Augmenter';

  @override
  String linkSupplierCheaperThan(String supplier, String amount, String unit) {
    return 'Meilleur prix que $supplier : $amount de moins par $unit.';
  }

  @override
  String linkSupplierSamePriceAs(String supplier) {
    return 'Même prix que $supplier.';
  }

  @override
  String linkSupplierDearerThan(String supplier, String amount, String unit) {
    return 'Plus cher que $supplier de $amount par $unit.';
  }

  @override
  String backTo(String destination) {
    return 'Retour à $destination';
  }

  @override
  String get backGeneric => 'Retour';

  @override
  String get breadcrumbLabel => 'Fil d\'ariane';

  @override
  String get discardChangesTitle => 'Abandonner les modifications ?';

  @override
  String get discardChangesBody =>
      'Les informations saisies sur cette page seront perdues.';

  @override
  String get discardChangesConfirm => 'Abandonner';

  @override
  String get discardChangesCancel => 'Continuer la saisie';

  @override
  String get catalogTabCategories => 'Catégories';

  @override
  String get catalogTabUnits => 'Unités de mesure';

  @override
  String get settingsTabStore => 'Établissement';

  @override
  String get settingsTabAccount => 'Compte';

  @override
  String get settingsTabNotifications => 'Notifications';

  @override
  String get settingsTabSync => 'Synchronisation';

  @override
  String get movementsTabHistory => 'Historique';

  @override
  String get loadingItems => 'Chargement de l\'inventaire…';

  @override
  String get itemBarcodeLabel => 'Code-barres (facultatif)';

  @override
  String get itemBarcodeShortLabel => 'Code-barres';

  @override
  String get itemBarcodeHint => '5412345001019';

  @override
  String get itemBarcodeHelp =>
      'Facultatif. Les produits frais — légumes, viande, poisson — n\'en ont généralement pas.';

  @override
  String get itemBarcodeScanTooltip =>
      'Scanner un code-barres (bientôt disponible)';

  @override
  String itemBarcodeDuplicate(String item) {
    return 'Ce code-barres est déjà utilisé par « $item ».';
  }

  @override
  String get itemBarcodeCopied => 'Code-barres copié.';

  @override
  String get itemBarcodeCopyTooltip => 'Copier le code-barres';

  @override
  String get navOrders => 'Commandes';

  @override
  String get ordersTitle => 'Commandes';

  @override
  String get ordersSubtitle => 'Commandes fournisseurs et réceptions';

  @override
  String get ordersNewAction => 'Nouvelle commande';

  @override
  String ordersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes',
      one: '1 commande',
      zero: 'Aucune commande',
    );
    return '$_temp0';
  }

  @override
  String get ordersEmptyTitle => 'Aucune commande';

  @override
  String get ordersEmptyBody =>
      'Une commande part chez un fournisseur et ne modifie pas le stock. Le stock bouge à la réception de la livraison.';

  @override
  String get ordersEmptyAction => 'Créer votre première commande';

  @override
  String get ordersFilterStatus => 'Statut';

  @override
  String get ordersFilterAllStatuses => 'Tous les statuts';

  @override
  String get ordersFilterPeriod => 'Période';

  @override
  String get ordersFilterAllPeriods => 'Toutes les dates';

  @override
  String get ordersFilterLast7 => '7 derniers jours';

  @override
  String get ordersFilterLast30 => '30 derniers jours';

  @override
  String get ordersFilterLast90 => '90 derniers jours';

  @override
  String ordersColumnLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes',
      one: '1 ligne',
    );
    return '$_temp0';
  }

  @override
  String get ordersOpenOnly => 'En cours';

  @override
  String get orderStatusDraft => 'Brouillon';

  @override
  String get orderStatusSent => 'Envoyée';

  @override
  String get orderStatusPartial => 'Partielle';

  @override
  String get orderStatusReceived => 'Reçue';

  @override
  String get orderStatusCancelled => 'Annulée';

  @override
  String orderDetailTitle(String reference) {
    return 'Commande $reference';
  }

  @override
  String orderCreatedOn(String date) {
    return 'Créée le $date';
  }

  @override
  String orderSentOn(String date) {
    return 'Envoyée le $date';
  }

  @override
  String orderClosedOn(String date) {
    return 'Clôturée le $date';
  }

  @override
  String get orderTotalLabel => 'Total de la commande';

  @override
  String get orderTabLines => 'Lignes';

  @override
  String get orderTabReceipts => 'Réceptions';

  @override
  String get orderColumnItem => 'Article';

  @override
  String get orderColumnOrdered => 'Commandé';

  @override
  String get orderColumnReceived => 'Reçu';

  @override
  String get orderColumnUnitPrice => 'Prix unitaire';

  @override
  String get orderColumnLineTotal => 'Total';

  @override
  String get orderReceiptsEmpty =>
      'Aucune livraison enregistrée pour cette commande.';

  @override
  String get orderNoteLabel => 'Note';

  @override
  String get orderNoteHint => 'Ex. livraison souhaitée mardi avant 10h';

  @override
  String get orderLockedNotice =>
      'Cette commande est envoyée : ses lignes ne sont plus modifiables. Le fournisseur en détient déjà une copie.';

  @override
  String orderShortfallNotice(String quantity) {
    return '$quantity non livrés sur cette commande.';
  }

  @override
  String get orderLineClosedShort => 'Clôturée';

  @override
  String orderLineOutstanding(String quantity) {
    return '$quantity en attente';
  }

  @override
  String get orderActionSend => 'Envoyer la commande';

  @override
  String get orderActionSaveDraft => 'Enregistrer le brouillon';

  @override
  String get orderActionEdit => 'Modifier';

  @override
  String get orderActionDelete => 'Supprimer le brouillon';

  @override
  String get orderActionCancel => 'Annuler la commande';

  @override
  String get orderActionReceive => 'Réceptionner la livraison';

  @override
  String get orderActionCloseShort => 'Clôturer la commande';

  @override
  String get orderActionCreate => 'Créer une commande';

  @override
  String orderSendConfirmTitle(String supplier) {
    return 'Envoyer la commande à $supplier ?';
  }

  @override
  String get orderSendConfirmBody =>
      'Une fois envoyée, la commande n\'est plus modifiable. Elle ne modifie pas le stock : seule la réception de la livraison le fait.';

  @override
  String get orderSendConfirmAction => 'Envoyer';

  @override
  String orderSent(String supplier) {
    return 'Commande envoyée à $supplier.';
  }

  @override
  String get orderDraftSaved => 'Brouillon enregistré.';

  @override
  String get orderDraftUpdated => 'Brouillon mis à jour.';

  @override
  String get orderDeleteWarning =>
      'Ce brouillon n\'a jamais été envoyé : sa suppression ne laisse aucune trace.';

  @override
  String get orderDeleted => 'Brouillon supprimé.';

  @override
  String orderCancelConfirmTitle(String reference) {
    return 'Annuler la commande $reference ?';
  }

  @override
  String get orderCancelConfirmBody =>
      'Le fournisseur détient déjà ce document. L\'annulation est définitive et ne peut pas être reprise.';

  @override
  String get orderCancelConfirmAction => 'Annuler la commande';

  @override
  String get orderCancelled => 'Commande annulée.';

  @override
  String orderCloseConfirmTitle(String reference) {
    return 'Clôturer la commande $reference ?';
  }

  @override
  String orderCloseConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count lignes encore en attente seront clôturées comme non livrées.',
      one: '1 ligne encore en attente sera clôturée comme non livrée.',
    );
    return '$_temp0 L\'écart reste enregistré.';
  }

  @override
  String get orderCloseConfirmAction => 'Clôturer';

  @override
  String get orderClosed => 'Commande clôturée.';

  @override
  String get createOrderTitle => 'Nouvelle commande';

  @override
  String get editOrderTitle => 'Modifier la commande';

  @override
  String get orderStepSupplier => 'Fournisseur';

  @override
  String get orderStepLines => 'Articles';

  @override
  String get orderSupplierPrompt => 'Choisissez un fournisseur';

  @override
  String get orderSupplierPromptBody =>
      'Une commande part chez un seul fournisseur. Ce choix filtre les articles proposés et remplit automatiquement les prix.';

  @override
  String get orderSupplierSearchHint => 'Rechercher un fournisseur…';

  @override
  String get orderSupplierChange => 'Changer de fournisseur';

  @override
  String get orderChangeSupplierTitle => 'Changer de fournisseur ?';

  @override
  String orderChangeSupplierBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les $count lignes déjà saisies seront supprimées.',
      one: 'La ligne déjà saisie sera supprimée.',
    );
    return '$_temp0 Les articles et les prix dépendent du fournisseur choisi.';
  }

  @override
  String get orderChangeSupplierAction => 'Changer et vider';

  @override
  String get orderAddLine => 'Ajouter un article';

  @override
  String get orderLinePickerLabel => 'Article';

  @override
  String get orderLineQuantity => 'Quantité';

  @override
  String orderLineUnitPrice(String unit) {
    return 'Prix / $unit';
  }

  @override
  String get orderLineTotal => 'Total ligne';

  @override
  String get orderRemoveLine => 'Retirer cette ligne';

  @override
  String get orderLineRemoved => 'Ligne retirée.';

  @override
  String get orderLinesEmptyTitle => 'Aucun article';

  @override
  String orderLinesEmptyBody(String supplier) {
    return 'Ajoutez les articles à commander chez $supplier.';
  }

  @override
  String orderPriceAutofilled(String supplier) {
    return 'Prix actuel de $supplier. Modifiable.';
  }

  @override
  String orderSuggestedTitle(String supplier) {
    return 'En stock faible chez $supplier';
  }

  @override
  String get orderSuggestedSubtitle =>
      'Articles de ce fournisseur à réapprovisionner.';

  @override
  String get orderSuggestedAddAll => 'Tout ajouter';

  @override
  String get orderSuggestedAdd => 'Ajouter';

  @override
  String orderSuggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles ajoutés.',
      one: '1 article ajouté.',
    );
    return '$_temp0';
  }

  @override
  String get orderSuggestedEmpty =>
      'Aucun article de ce fournisseur n\'est en stock faible.';

  @override
  String orderSuggestedShortfall(String quantity) {
    return 'Il manque $quantity';
  }

  @override
  String orderAlreadyOnOrder(String quantity) {
    return 'Déjà commandé : $quantity';
  }

  @override
  String orderAlreadyOnOrderDetail(String quantity, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes en cours',
      one: '1 commande en cours',
    );
    return '$quantity attendus sur $_temp0.';
  }

  @override
  String get itemOnHandLabel => 'En stock';

  @override
  String get itemOnOrderLabel => 'En commande';

  @override
  String get itemOpenOrdersTitle => 'Commandes en cours';

  @override
  String get itemNoOpenOrders => 'Aucune commande en cours pour cet article.';

  @override
  String receiveOrderTitle(String reference) {
    return 'Réception — $reference';
  }

  @override
  String get receiveOrderSubtitle =>
      'Vérifiez ligne par ligne ce qui est réellement arrivé.';

  @override
  String get receiveColumnOrdered => 'Commandé';

  @override
  String get receiveColumnReceived => 'Reçu';

  @override
  String receiveColumnPrice(String unit) {
    return 'Prix réel / $unit';
  }

  @override
  String get receiveLineNote => 'Note';

  @override
  String get receiveLineNoteHint =>
      'Ex. 2 cageots abîmés, repris par le chauffeur';

  @override
  String receiveShortTitle(String quantity) {
    return 'Livraison incomplète : il manque $quantity';
  }

  @override
  String get receiveShortClose => 'Clôturer l\'écart';

  @override
  String get receiveShortKeepOpen => 'Le reste doit arriver';

  @override
  String receiveOverBadge(String quantity) {
    return 'Sur-livraison de $quantity';
  }

  @override
  String get receiveUnorderedBadge => 'Non commandé';

  @override
  String get receiveAddUnordered => 'Ajouter un article non commandé';

  @override
  String get receiveUnorderedAdded =>
      'Article non commandé ajouté à la réception.';

  @override
  String get receiveUnorderedRemoved => 'Ligne retirée de la réception.';

  @override
  String get receiveSummaryTitle => 'Récapitulatif';

  @override
  String get receiveSummaryLines => 'Lignes reçues';

  @override
  String get receiveSummaryValue => 'Valeur reçue';

  @override
  String get receiveSummaryDiscrepancies => 'Écarts';

  @override
  String get receiveConfirm => 'Confirmer la réception';

  @override
  String get receiveConfirmed =>
      'Réception enregistrée — le stock a été mis à jour.';

  @override
  String get receiveNothing => 'Indiquez au moins une quantité reçue.';

  @override
  String receiveOrderedPrice(String price) {
    return 'Prix commandé : $price';
  }

  @override
  String get receivePriceConfirmTitle => 'Confirmer ce prix ?';

  @override
  String receivePriceConfirmBody(
    String item,
    String oldPrice,
    String newPrice,
  ) {
    return '$item était à $oldPrice, maintenant $newPrice. Confirmez-vous ce prix ?';
  }

  @override
  String get receivePriceConfirmAction => 'Confirmer le prix';

  @override
  String get receiveNoteLabel => 'Note de réception';

  @override
  String get receiveNoteHint => 'Ex. chauffeur en retard, palette échangée';

  @override
  String get receiveManagerNotice =>
      'La réception modifie le stock et les prix : elle est réservée aux gérants.';

  @override
  String receiptDetailTitle(String date) {
    return 'Réception du $date';
  }

  @override
  String receiptReceivedBy(String name) {
    return 'Réceptionnée par $name';
  }

  @override
  String receiptOrderReference(String reference) {
    return 'Commande $reference';
  }

  @override
  String get receiptReadOnlyNotice =>
      'Une réception confirmée ne peut être ni modifiée ni supprimée. Toute correction passe par un ajustement de stock, pour que l\'historique reste vérifiable.';

  @override
  String get receiptValueLabel => 'Valeur de la réception';

  @override
  String get receiptColumnNote => 'Note';

  @override
  String receiptPriceChanged(String oldPrice, String newPrice) {
    return '$oldPrice → $newPrice';
  }

  @override
  String movementFromOrder(String reference) {
    return 'Réception — commande $reference';
  }

  @override
  String get movementViewReceipt => 'Voir la réception';

  @override
  String get dashboardTileOnOrder => 'En attente de livraison';

  @override
  String dashboardOnOrderCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes ouvertes',
      one: '1 commande ouverte',
      zero: 'Rien en cours',
    );
    return '$_temp0';
  }

  @override
  String dashboardStaleOrdersTitle(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes partielles ouvertes depuis plus de $days jours',
      one: '1 commande partielle ouverte depuis plus de $days jours',
    );
    return '$_temp0';
  }

  @override
  String get dashboardStaleOrdersBody =>
      'Une commande laissée ouverte gonfle la quantité « en commande » et fausse l\'alerte de double commande.';

  @override
  String get dashboardStaleOrdersAction => 'Voir les commandes';

  @override
  String alertsOnOrder(String quantity) {
    return '$quantity en commande';
  }

  @override
  String get alertsNothingOnOrder => 'Rien en commande';

  @override
  String get alertsCreateOrders => 'Créer les commandes';

  @override
  String get supplierTabDetails => 'Fiche';

  @override
  String get supplierTabOrders => 'Commandes';

  @override
  String get supplierOrdersEmpty =>
      'Aucune commande passée chez ce fournisseur.';

  @override
  String get storeSettingsOrders => 'Commandes';

  @override
  String get storeSettingsStaleDays => 'Alerte commande partielle (jours)';

  @override
  String get storeSettingsStaleDaysHelp =>
      'Une commande partiellement reçue est signalée sur le tableau de bord passé ce délai. Par défaut : 7 jours.';

  @override
  String get demoResetTitle => 'Réinitialiser la démonstration';

  @override
  String get demoResetBody =>
      'Remet les articles, les stocks, les commandes et les prix dans leur état d\'origine. Les modifications faites pendant la démonstration ne sont conservées que le temps de la session.';

  @override
  String get demoResetConfirmTitle => 'Réinitialiser la démonstration ?';

  @override
  String get demoResetConfirmBody =>
      'Tout ce qui a été créé, modifié ou réceptionné depuis le démarrage sera annulé.';

  @override
  String get demoResetConfirmAction => 'Réinitialiser';

  @override
  String get demoResetDone => 'Démonstration réinitialisée.';

  @override
  String get actionUnderstood => 'Compris';

  @override
  String get editCategoryTitle => 'Modifier la catégorie';

  @override
  String get editUnitTitle => 'Modifier l\'unité de mesure';

  @override
  String get categoryNameTaken => 'Une catégorie porte déjà ce nom.';

  @override
  String get unitNameTaken => 'Une unité porte déjà ce nom.';

  @override
  String get unitAbbreviationTaken => 'Cette abréviation est déjà utilisée.';

  @override
  String categoryDeleteBlockedTitle(String name) {
    return 'Impossible de supprimer « $name »';
  }

  @override
  String categoryDeleteBlockedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles sont classés dans cette catégorie.',
      one: '1 article est classé dans cette catégorie.',
    );
    return '$_temp0 Reclassez-les avant de la supprimer.';
  }

  @override
  String unitDeleteBlockedTitle(String name) {
    return 'Impossible de supprimer « $name »';
  }

  @override
  String unitDeleteBlockedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles sont mesurés dans cette unité.',
      one: '1 article est mesuré dans cette unité.',
    );
    return '$_temp0 Changez leur unité avant de la supprimer.';
  }

  @override
  String get itemFormOpeningBalanceHelp =>
      'Enregistré comme un ajustement d\'inventaire, pour que l\'historique des mouvements soit complet dès le départ.';

  @override
  String get itemFormAdjustStock => 'Ajuster le stock';

  @override
  String get itemFormQuantityLocked =>
      'La quantité se modifie par un ajustement d\'inventaire, qui laisse une trace.';

  @override
  String itemDeleteBlockedTitle(String name) {
    return 'Impossible de supprimer « $name »';
  }

  @override
  String itemDeleteBlockedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cet article figure sur $count commandes en cours.',
      one: 'Cet article figure sur 1 commande en cours.',
    );
    return '$_temp0 Réceptionnez ou clôturez-la avant de le supprimer.';
  }

  @override
  String itemDeleteCascadeWarning(int movements, int suppliers) {
    String _temp0 = intl.Intl.pluralLogic(
      movements,
      locale: localeName,
      other: '$movements mouvements de stock',
      one: '1 mouvement de stock',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      suppliers,
      locale: localeName,
      other: ' et $suppliers fournisseurs associés',
      one: ' et 1 fournisseur associé',
      zero: '',
    );
    return '$_temp0$_temp1 seront également supprimés.';
  }

  @override
  String supplierDeleteBlockedTitle(String name) {
    return 'Impossible de supprimer « $name »';
  }

  @override
  String supplierDeleteBlockedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes en cours sont adressées à ce fournisseur.',
      one: 'Une commande en cours est adressée à ce fournisseur.',
    );
    return '$_temp0 Réceptionnez-les, clôturez-les ou annulez-les d\'abord.';
  }

  @override
  String get supplierPriceUpdated => 'Prix mis à jour.';

  @override
  String supplierDefaultChanged(String supplier) {
    return '$supplier est maintenant le fournisseur par défaut.';
  }

  @override
  String supplierPromotedToDefault(String supplier) {
    return '$supplier devient le fournisseur par défaut.';
  }

  @override
  String notificationsMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications marquées comme lues.',
      one: '1 notification marquée comme lue.',
    );
    return '$_temp0';
  }

  @override
  String get storeCreated => 'Établissement créé.';

  @override
  String get employeesNavPersonnel => 'Personnel';

  @override
  String get employeesNavTimeclock => 'Tableau de pointage';

  @override
  String get employeesNavAttendanceHistory => 'Historique pointage';

  @override
  String get employeesNavPayroll => 'Historique de paiement';

  @override
  String get employeeSectionComingSoonTitle => 'Bientôt disponible';

  @override
  String get employeeSectionComingSoonTimeclock =>
      'Le tableau de pointage arrive dans une prochaine étape.';

  @override
  String get employeeSectionComingSoonAttendanceHistory =>
      'L\'historique de pointage arrive dans une prochaine étape.';

  @override
  String get employeeSectionComingSoonPayroll =>
      'L\'historique de paiement arrive dans une prochaine étape.';

  @override
  String get employeeRoleOwner => 'Propriétaire';

  @override
  String get employeeRoleManager => 'Gérant';

  @override
  String get employeeRoleStaff => 'Employé';

  @override
  String get employeeRoleOwnerBody =>
      'Accès complet à tous les établissements, à la paie et à la gestion du personnel.';

  @override
  String get employeeRoleManagerBody =>
      'Gère l\'établissement au quotidien : pointage, historique, absences. Pas la paie.';

  @override
  String get employeeRoleStaffBody =>
      'Aucun accès à l\'application. Son pointage est fait au tableau de bord partagé.';

  @override
  String get contractTypeFixed => 'Salarié fixe';

  @override
  String get contractTypeExtra => 'Extra';

  @override
  String get employeesTitle => 'Personnel';

  @override
  String get employeesSubtitle =>
      'Le personnel de cet établissement — coordonnées, contrat et rôle.';

  @override
  String get employeesAdd => 'Ajouter un employé';

  @override
  String get employeesSearchHint => 'Rechercher (nom, CIN)';

  @override
  String get employeesShowArchived => 'Afficher les personnels retirés';

  @override
  String get employeesArchivedPill => 'Retiré';

  @override
  String get employeesEmpty => 'Aucun employé';

  @override
  String get employeesEmptyBody =>
      'Ajoutez les membres de votre personnel pour suivre leur pointage et leur paie.';

  @override
  String employeeCinLabel(String cin) {
    return 'CIN $cin';
  }

  @override
  String get employeesKpiActive => 'Personnel actif';

  @override
  String get employeesKpiContractSplit => 'Fixes / Extras';

  @override
  String employeesKpiContractSplitValue(int fixed, int extra) {
    return '$fixed fixes · $extra extras';
  }

  @override
  String get employeesKpiManagers => 'Gérants';

  @override
  String get employeesKpiHiredThisMonth => 'Embauches ce mois';

  @override
  String get employeeFormPhoto => 'Photo';

  @override
  String get employeeFormPhotoAction => 'Choisir une photo';

  @override
  String get employeeFormPhotoReplace => 'Remplacer la photo';

  @override
  String get employeeFormPhotoRemove => 'Supprimer';

  @override
  String get employeeFormPhotoReadError =>
      'Impossible de lire ce fichier image.';

  @override
  String get employeeFormFirstName => 'Prénom';

  @override
  String get employeeFormLastName => 'Nom';

  @override
  String get employeeFormCin => 'N° de carte d\'identité';

  @override
  String get employeeFormPhone => 'Téléphone';

  @override
  String get employeeFormEmail => 'Adresse e-mail';

  @override
  String get employeeCinTaken =>
      'Ce numéro de carte d\'identité est déjà utilisé.';

  @override
  String get employeeEmailTaken => 'Cette adresse e-mail est déjà utilisée.';

  @override
  String get employeeFormRole => 'Rôle et accès';

  @override
  String get employeeFormEmployment => 'Contrat et rémunération';

  @override
  String get employeeFormContractType => 'Type de contrat';

  @override
  String get employeeFormPayMonthly => 'Salaire mensuel (€)';

  @override
  String get employeeFormPayHourly => 'Tarif horaire (€/h)';

  @override
  String get employeeFormSchedule => 'Horaires';

  @override
  String get employeeFormScheduleStart => 'Heure d\'arrivée';

  @override
  String get employeeFormScheduleEnd => 'Heure de départ';

  @override
  String get employeeFormScheduleInvalid => 'Format attendu : HH:MM';

  @override
  String get employeeFormScheduleHelp =>
      'Laissez vide pour utiliser les horaires de l\'établissement.';

  @override
  String get employeeCreated => 'Employé ajouté';

  @override
  String get employeeUpdated => 'Employé modifié';

  @override
  String employeeHiredOn(String date) {
    return 'Embauché le $date';
  }

  @override
  String get employeeDetailContact => 'Coordonnées';

  @override
  String get employeeScheduleStoreHours => 'Horaires de l\'établissement';

  @override
  String get employeeHistoryTitle => 'Historique de pointage';

  @override
  String get employeePayrollTitle => 'Historique de paiement';

  @override
  String employeeArchiveTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get employeeArchiveBody =>
      'Cette personne n\'apparaîtra plus dans le personnel actif. Son historique de pointage et de paie reste conservé.';

  @override
  String get employeeArchiveConfirm => 'Retirer';

  @override
  String get employeeArchived => 'Employé retiré';

  @override
  String get employeeRestore => 'Restaurer';

  @override
  String get employeeRestored => 'Employé restauré';

  @override
  String employeeDetailArchivedOn(String date) {
    return 'Retiré le $date';
  }

  @override
  String get employeeHistoryEmpty => 'Aucun pointage enregistré.';

  @override
  String get attendanceStatusNotClockedIn => 'Non pointé';

  @override
  String get attendanceStatusWorking => 'En service';

  @override
  String get attendanceStatusOnBreak => 'En pause';

  @override
  String get attendanceStatusDone => 'Terminé';

  @override
  String get attendanceLate => 'En retard';

  @override
  String get attendanceBreakOverrun => 'Pause dépassée';

  @override
  String get timeclockBoardTitle => 'Tableau de pointage';

  @override
  String get timeclockBoardSubtitle =>
      'Pointage du jour — arrivées, pauses et départs.';

  @override
  String get timeclockBoardEmpty => 'Aucun personnel actif';

  @override
  String get timeclockBoardEmptyBody =>
      'Ajoutez du personnel pour commencer à pointer.';

  @override
  String get timeclockClockIn => 'Pointer';

  @override
  String get timeclockStartPause => 'Pause';

  @override
  String get timeclockEndPause => 'Reprendre';

  @override
  String get timeclockClockOut => 'Fin de journée';

  @override
  String timeclockClockInDone(String name) {
    return 'Pointage enregistré pour $name.';
  }

  @override
  String timeclockPauseStartDone(String name) {
    return 'Pause démarrée pour $name.';
  }

  @override
  String timeclockPauseEndDone(String name) {
    return 'Reprise enregistrée pour $name.';
  }

  @override
  String timeclockClockOutDone(String name) {
    return 'Fin de journée enregistrée pour $name.';
  }

  @override
  String get timeclockLogArrival => 'Arrivée';

  @override
  String get timeclockLogBreak => 'Pause';

  @override
  String get timeclockLogResume => 'Reprise';

  @override
  String get timeclockLogDeparture => 'Départ';

  @override
  String timeclockWorked(String duration) {
    return 'Travaillé : $duration';
  }

  @override
  String timeclockOvertimeMark(String duration) {
    return '+$duration sup.';
  }

  @override
  String get storeSettingsHours => 'Horaires de l\'établissement';

  @override
  String get storeSettingsOpenTime => 'Ouverture';

  @override
  String get storeSettingsCloseTime => 'Fermeture';

  @override
  String get storeSettingsMaxBreak => 'Pause max (minutes)';

  @override
  String get storeSettingsHoursHelp =>
      'Les horaires servent de base au calcul du retard et des heures supplémentaires (pour un employé sans horaire personnel). Une pause plus longue que le maximum est signalée « Pause dépassée ».';

  @override
  String paginatorRange(int first, int last, int total) {
    return '$first–$last sur $total';
  }

  @override
  String paginatorPage(int page, int count) {
    return '$page / $count';
  }

  @override
  String get paginatorPrevious => 'Page précédente';

  @override
  String get paginatorNext => 'Page suivante';

  @override
  String get attendanceHistoryTitle => 'Historique de pointage';

  @override
  String get attendanceHistorySubtitle =>
      'Consultez et filtrez les pointages de tout le personnel, jour par jour.';

  @override
  String attendanceHistoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
      zero: 'Aucun résultat',
    );
    return '$_temp0';
  }

  @override
  String get attendanceHistoryEmpty => 'Aucun historique de pointage';

  @override
  String get attendanceHistoryEmptyBody =>
      'Aucun pointage n\'a encore été enregistré dans cet établissement.';

  @override
  String get attendanceFilterEmployee => 'Employé';

  @override
  String get attendanceFilterAllEmployees => 'Tous les employés';

  @override
  String get attendanceFilterFrom => 'Du';

  @override
  String get attendanceFilterTo => 'Au';

  @override
  String attendanceFilterDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get attendanceStatDays => 'Jours pointés';

  @override
  String get attendanceStatWorked => 'Heures travaillées';

  @override
  String get attendanceStatLate => 'Retards';

  @override
  String get attendanceStatOvertime => 'Heures supplémentaires';

  @override
  String get attendanceColumnDate => 'Date';

  @override
  String get attendanceColumnEmployee => 'Employé';

  @override
  String get attendanceColumnArrival => 'Arrivée';

  @override
  String get attendanceColumnDeparture => 'Départ';

  @override
  String get attendanceColumnBreaks => 'Pauses';

  @override
  String get attendanceColumnWorked => 'Durée travail';

  @override
  String get attendanceColumnOvertime => 'Heures sup';

  @override
  String get attendanceColumnStatus => 'Statut';

  @override
  String get attendanceColumnFlags => 'Alertes';

  @override
  String get attendanceColumnActions => 'Détail';

  @override
  String get attendanceViewDetail => 'Voir le détail';

  @override
  String get attendanceDetailTitle => 'Détail du pointage';

  @override
  String attendanceDetailBreaks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pauses',
      one: '1 pause',
      zero: 'Aucune pause',
    );
    return '$_temp0';
  }

  @override
  String get storeSettingsPayroll => 'Paie';

  @override
  String get storeSettingsOvertimeMultiplier => 'Majoration heures sup.';

  @override
  String get storeSettingsWorkingDays => 'Jours ouvrés / mois';

  @override
  String get storeSettingsPayrollHelp =>
      'Un salarié fixe est payé son taux journalier (salaire ÷ jours ouvrés) par jour travaillé ; les heures supplémentaires sont payées à ce taux fois la majoration.';

  @override
  String get payrollHistoryTitle => 'Historique de paiement';

  @override
  String get payrollHistorySubtitle =>
      'L\'historique de paiement d\'un employé, jour par jour.';

  @override
  String get payrollFilterEmployee => 'Employé';

  @override
  String get payrollFilterAllEmployees => 'Tous les employés';

  @override
  String get payrollFilterFrom => 'Du';

  @override
  String get payrollFilterTo => 'Au';

  @override
  String get payrollFilterStatus => 'Statut de paiement';

  @override
  String get payrollStatusAll => 'Tous';

  @override
  String get payrollStatusPaid => 'Payé';

  @override
  String get payrollStatusUnpaid => 'Non payé';

  @override
  String payrollHistoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count journées',
      one: '1 journée',
      zero: 'Aucune journée',
    );
    return '$_temp0';
  }

  @override
  String get payrollHistoryEmpty => 'Aucune journée payable';

  @override
  String get payrollHistoryEmptyBody =>
      'Cet employé n\'a aucune journée terminée sur la période choisie.';

  @override
  String get payrollStatPaidDays => 'Jours payés';

  @override
  String get payrollStatUnpaidDays => 'Jours non payés';

  @override
  String get payrollStatWorkedHours => 'Heures travaillées';

  @override
  String get payrollStatOvertimeHours => 'Heures supplémentaires';

  @override
  String get payrollColumnEmployee => 'Employé';

  @override
  String get payrollColumnDate => 'Date';

  @override
  String get payrollColumnClockIn => 'Arrivée';

  @override
  String get payrollColumnClockOut => 'Départ';

  @override
  String get payrollColumnWorked => 'Durée travaillée';

  @override
  String get payrollColumnOvertime => 'Heures sup';

  @override
  String get payrollColumnAmount => 'Montant';

  @override
  String get payrollColumnStatus => 'Statut';

  @override
  String get payrollColumnPaidAt => 'Payé le';

  @override
  String get payrollPayAction => 'Payer';

  @override
  String payrollPayConfirmTitle(String name) {
    return 'Payer $name ?';
  }

  @override
  String payrollPayConfirmBody(String period, int days, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return '$period · $_temp0 · $amount. Les jours concernés seront verrouillés et ne pourront plus être modifiés.';
  }

  @override
  String get payrollPaid => 'Paiement enregistré';

  @override
  String get paymentStatusPaid => 'Payé';

  @override
  String get paymentStatusUnpaid => 'Non payé';

  @override
  String get loginCin => 'Numéro CIN';

  @override
  String get loginCinHint => 'AB.12.34-567.89';

  @override
  String get loginPin => 'Code PIN';

  @override
  String get loginPinHint => '4 chiffres';

  @override
  String get loginForgotPin => 'Code oublié ?';

  @override
  String get loginErrorBadCredentials => 'CIN ou code PIN incorrect.';

  @override
  String get loginErrorLocked =>
      'Compte verrouillé après plusieurs tentatives. Réessayez dans quelques minutes.';

  @override
  String get loginErrorNoAccess =>
      'Ce compte n\'a pas accès à l\'application. Le pointage se fait au tableau de bord partagé.';

  @override
  String get employeeFormCredentials => 'Identifiants';

  @override
  String get employeeFormPin => 'Code PIN';

  @override
  String get employeeFormPinConfirm => 'Confirmer le code';

  @override
  String get employeeFormPinHelp =>
      '4 chiffres. La personne se connecte avec son numéro CIN et ce code.';

  @override
  String get employeeFormPinEditHelp =>
      'Laisser vide pour conserver le code actuel.';

  @override
  String get employeeFormPinMismatch => 'Les deux codes ne correspondent pas.';

  @override
  String get storeSettingsReadOnlyNotice =>
      'Seul le propriétaire peut modifier les paramètres de l\'établissement.';

  @override
  String get itemFormOpeningCost => 'Coût d\'achat unitaire';

  @override
  String get itemFormOpeningCostHint => 'Ex. : 8,50';

  @override
  String get itemFormOpeningCostHelp =>
      'Facultatif. Sans ce montant, l\'article ne sera pas valorisé tant qu\'une livraison n\'aura pas été réceptionnée.';

  @override
  String get itemAverageCost => 'Coût moyen du stock';

  @override
  String get itemAverageCostUnknown => 'Non valorisé';

  @override
  String get itemAverageCostHelp =>
      'Moyenne pondérée de ce qui a été réellement payé pour le stock en rayon. Chaque livraison ne revalorise que les unités livrées.';

  @override
  String get movementUnitCost => 'Coût unitaire';

  @override
  String get valuationAtCost =>
      'Valorisé au coût d\'achat réel, et non au prix fournisseur du jour.';

  @override
  String get reportWasteValue => 'Valeur des pertes';

  @override
  String get reportConsumptionValue => 'Valeur consommée';

  @override
  String get addStoreVatNumber => 'Numéro de TVA';

  @override
  String get addStoreVatNumberHint => 'BE 0123.456.789';

  @override
  String get addStoreVatNumberHelp =>
      'Facultatif. Figure sur les bons de réception envoyés aux fournisseurs.';

  @override
  String get receiptDocAction => 'Bon de réception';

  @override
  String get receiptDocGenerating => 'Génération du document…';

  @override
  String get receiptDocFailed => 'Le document n\'a pas pu être généré.';

  @override
  String get receiptDocTitle => 'BON DE RÉCEPTION';

  @override
  String receiptDocVatNumber(String number) {
    return 'TVA $number';
  }

  @override
  String get receiptDocSupplierBlock => 'Fournisseur';

  @override
  String get receiptDocOrderReference => 'Commande';

  @override
  String get receiptDocOrderSent => 'Envoyée le';

  @override
  String get receiptDocReceivedAt => 'Réceptionnée le';

  @override
  String get receiptDocReceivedBy => 'Réceptionnée par';

  @override
  String get receiptDocColumnItem => 'Article';

  @override
  String get receiptDocColumnOrdered => 'Commandé';

  @override
  String get receiptDocColumnReceived => 'Reçu';

  @override
  String get receiptDocColumnGap => 'Écart';

  @override
  String get receiptDocColumnOrderedPrice => 'PU commandé';

  @override
  String get receiptDocColumnActualPrice => 'PU réel';

  @override
  String get receiptDocColumnTotal => 'Total';

  @override
  String get receiptDocUnordered => 'hors commande';

  @override
  String get receiptDocReserves => 'RÉSERVES';

  @override
  String get receiptDocNoReserves =>
      'Livraison conforme à la commande. Aucune réserve.';

  @override
  String receiptDocReserveShortClosed(
    String item,
    String quantity,
    String ordered,
  ) {
    return '$item : $quantity non livré(s) sur $ordered commandé(s). Ligne soldée, le solde n\'est plus attendu.';
  }

  @override
  String receiptDocReserveShortOpen(
    String item,
    String quantity,
    String ordered,
  ) {
    return '$item : $quantity non livré(s) sur $ordered commandé(s). Solde restant dû.';
  }

  @override
  String receiptDocReserveOver(String item, String quantity) {
    return '$item : $quantity livré(s) en plus de la quantité commandée.';
  }

  @override
  String receiptDocReserveUnordered(String item, String quantity) {
    return '$item : $quantity livré(s) sans figurer sur la commande.';
  }

  @override
  String receiptDocReservePrice(
    String item,
    String oldPrice,
    String newPrice,
    String delta,
  ) {
    return '$item : prix unitaire passé de $oldPrice à $newPrice ($delta) par rapport à la commande.';
  }

  @override
  String receiptDocReserveNote(String item, String note) {
    return '$item : $note';
  }

  @override
  String get receiptDocTotalLabel => 'Valeur réceptionnée';

  @override
  String get receiptDocNoteLabel => 'Remarques';

  @override
  String get receiptDocSignatureReceiver => 'Signature réception';

  @override
  String get receiptDocSignatureDriver => 'Signature livreur';

  @override
  String receiptDocFooter(String date) {
    return 'Document généré le $date — ne constitue pas une facture.';
  }

  @override
  String get storeSettingsRetroWarningTitle =>
      'Des journées ne sont pas encore payées';

  @override
  String storeSettingsRetroWarningBody(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days journées terminées n\'\'ont pas encore été payées',
      one: '1 journée terminée n\'\'a pas encore été payée',
    );
    return '$_temp0. Changer les horaires ou les coefficients modifiera le retard, les heures supplémentaires et le montant estimé de ces journées. Payez-les d\'\'abord pour figer leurs chiffres.';
  }

  @override
  String get storeSettingsRetroWarningConfirm => 'Changer quand même';

  @override
  String get identityPromptTitle => 'Confirmation d\'identité';

  @override
  String get identityPromptField => 'Numéro CIN';

  @override
  String get identityPromptValidate => 'Valider';

  @override
  String identityPromptWrong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tentatives restantes.',
      one: '1 tentative restante.',
      zero: 'Verrouillé.',
    );
    return 'Numéro incorrect. $_temp0';
  }

  @override
  String identityPromptLocked(String time) {
    return 'Trop de tentatives. Réessayez dans $time.';
  }

  @override
  String get identityPromptNoCredential =>
      'Aucun identifiant n\'est configuré pour cette personne.';

  @override
  String identityPromptPointageSubtitle(String action, String name) {
    return '$action · saisissez le numéro CIN de $name';
  }

  @override
  String identityPromptPayrollSubtitle(String name) {
    return 'Saisissez votre numéro CIN pour valider le paiement de $name';
  }
}
