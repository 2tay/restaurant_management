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
  String get teamTitle => 'Équipe';

  @override
  String get teamSubtitle =>
      'Qui a accès à cet établissement, et avec quels droits.';

  @override
  String get teamInvite => 'Inviter un membre';

  @override
  String get teamEmpty => 'Aucun membre';

  @override
  String get teamEmptyBody =>
      'Invitez vos collaborateurs pour qu\'ils puissent enregistrer les mouvements de stock.';

  @override
  String get teamPending => 'Invitation en attente';

  @override
  String teamLastActive(String when) {
    return 'Actif $when';
  }

  @override
  String teamStoreAccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count établissements',
      one: '1 établissement',
    );
    return '$_temp0';
  }

  @override
  String get roleOwner => 'Propriétaire';

  @override
  String get roleManager => 'Gérant';

  @override
  String get roleStaff => 'Employé';

  @override
  String get roleOwnerBody =>
      'Accès complet à tous les établissements, à la facturation et à l\'équipe.';

  @override
  String get roleManagerBody =>
      'Accès complet aux établissements assignés, sauf les paramètres du compte.';

  @override
  String get roleStaffBody =>
      'Peut enregistrer les livraisons et les sorties, et consulter l\'inventaire.';

  @override
  String get inviteTitle => 'Inviter un membre';

  @override
  String get editMemberTitle => 'Modifier le membre';

  @override
  String get memberFormName => 'Nom complet';

  @override
  String get memberFormEmail => 'Adresse e-mail';

  @override
  String get memberFormRole => 'Rôle';

  @override
  String get memberFormStores => 'Établissements accessibles';

  @override
  String get memberInvited => 'Invitation envoyée';

  @override
  String get memberUpdated => 'Membre modifié';

  @override
  String get memberRemoved => 'Membre retiré';

  @override
  String get memberRemoveWarning =>
      'Cette personne perdra immédiatement l\'accès à l\'application.';

  @override
  String get rolesTitle => 'Rôles et permissions';

  @override
  String get rolesSubtitle => 'Ce que chaque rôle peut faire.';

  @override
  String get permissionViewInventory => 'Consulter l\'inventaire';

  @override
  String get permissionRecordMovements => 'Enregistrer les mouvements';

  @override
  String get permissionEditItems => 'Créer et modifier les articles';

  @override
  String get permissionManageSuppliers => 'Gérer les fournisseurs et les prix';

  @override
  String get permissionViewReports => 'Consulter les rapports';

  @override
  String get permissionManageTeam => 'Gérer l\'équipe';

  @override
  String get permissionManageAccount => 'Gérer le compte et les établissements';

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
  String get syncPhase2Note =>
      'La synchronisation réelle sera ajoutée en phase 2. Les valeurs ci-dessus sont fictives.';

  @override
  String get searchTitle => 'Recherche';

  @override
  String get searchHint => 'Article, fournisseur, catégorie…';

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
  String get a11yPermissionGranted => 'Autorisé';

  @override
  String get a11yPermissionDenied => 'Non autorisé';

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
}
