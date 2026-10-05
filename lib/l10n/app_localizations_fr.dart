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
  String get navInventory => 'Produits';

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
  String get shortAddItem => 'Ajouter';

  @override
  String get shortAddDelivery => 'Livraison';

  @override
  String get shortLogUsage => 'Sortie';

  @override
  String get shortAdjustStock => 'Ajuster';

  @override
  String get shortAddSupplier => 'Ajouter';

  @override
  String get shortAddEmployee => 'Ajouter';

  @override
  String get shortAddCategory => 'Ajouter';

  @override
  String get shortAddUnit => 'Ajouter';

  @override
  String get shortNewOrder => 'Nouvelle';

  @override
  String get shortCreateOrders => 'Commander';

  @override
  String get shortEditPrices => 'Tarifs';

  @override
  String get shortMarkAllRead => 'Tout lire';

  @override
  String get filtersTitle => 'Filtres';

  @override
  String filtersTitleWithCount(int count) {
    return 'Filtres · $count';
  }

  @override
  String get filtersClearAll => 'Tout effacer';

  @override
  String get filtersDone => 'Voir les résultats';

  @override
  String get actionAddItem => 'Ajouter un produit';

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
  String get actionClear => 'Effacer';

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
  String get sidebarMyStores => 'Mes établissements';

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
  String get emptyStateNoItemsTitle => 'Aucun produit pour le moment';

  @override
  String get emptyStateNoItemsBody =>
      'Ajoutez votre premier produit pour commencer à suivre votre stock.';

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
  String get loginEmailHint => 'prenom.nom@exemple.be';

  @override
  String get loginRemember => 'Rester connecté';

  @override
  String get loginForgot => 'Mot de passe oublié ?';

  @override
  String get loginSubmit => 'Se connecter';

  @override
  String get loginDemoNotice =>
      'Mode démonstration : restaurant fictif, rien n\'est envoyé.';

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
      'Recevez une alerte dès qu\'un produit passe sous son seuil.';

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
      other: '$count produits',
      one: '1 produit',
      zero: 'Aucun produit',
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
  String get inventoryTitle => 'Produits';

  @override
  String get inventorySearchHint => 'Rechercher un produit ou un code-barres…';

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
      other: '$count produits',
      one: '1 produit',
      zero: 'Aucun produit',
    );
    return '$_temp0';
  }

  @override
  String get inventoryClearFilters => 'Effacer les filtres';

  @override
  String get inventorySortLabel => 'Trier par';

  @override
  String get inventorySortStatus => 'Stock prioritaire';

  @override
  String get inventorySortRecent => 'Plus récent';

  @override
  String get inventorySortNameAsc => 'Nom A → Z';

  @override
  String get inventorySortNameDesc => 'Nom Z → A';

  @override
  String get inventorySortStockAsc => 'Stock croissant';

  @override
  String get inventorySortStockDesc => 'Stock décroissant';

  @override
  String get inventoryViewTable => 'Vue tableau';

  @override
  String movementsShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count restants',
      one: '1 restant',
    );
    return 'Afficher plus ($_temp0)';
  }

  @override
  String get movementsViewList => 'Vue liste';

  @override
  String get movementsViewTable => 'Vue tableau';

  @override
  String get tableColProduct => 'Produit';

  @override
  String get tableColStock => 'Stock';

  @override
  String get tableColThreshold => 'Stock min/max';

  @override
  String get tableColLevel => 'Niveau';

  @override
  String get tableColValue => 'Valeur';

  @override
  String get tableColStatus => 'Statut';

  @override
  String get tableColDate => 'Date';

  @override
  String get tableColType => 'Type';

  @override
  String get tableColQuantity => 'Quantité';

  @override
  String get tableColBy => 'Par';

  @override
  String get tableColTime => 'Heure';

  @override
  String get inventoryViewGrid => 'Vue grille';

  @override
  String get inventoryViewList => 'Vue liste';

  @override
  String get wizardNext => 'Suivant';

  @override
  String get wizardPrevious => 'Précédent';

  @override
  String get wizardReset => 'Réinitialiser';

  @override
  String get wizardResetTitle => 'Réinitialiser le formulaire ?';

  @override
  String get wizardResetBody =>
      'Les informations saisies seront effacées et vous reviendrez à la première étape.';

  @override
  String wizardStepOf(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get viewModeGrid => 'Vue grille';

  @override
  String get viewModeList => 'Vue liste';

  @override
  String get inventoryStockCurrent => 'Stock actuel';

  @override
  String get inventorySelectPrompt => 'Sélectionnez un produit';

  @override
  String get inventorySelectPromptBody =>
      'Choisissez un produit dans la liste pour voir son détail, ses fournisseurs et ses prix.';

  @override
  String get itemQuantityLabel => 'Quantité';

  @override
  String get itemThresholdLabel => 'Stock minimum';

  @override
  String get itemImageLabel => 'Photo du produit';

  @override
  String get itemImageHelp =>
      'Facultative. Elle aide à repérer un produit d\'un coup d\'œil dans la liste.';

  @override
  String get itemImageChoose => 'Choisir une photo';

  @override
  String get itemImageReplace => 'Remplacer la photo';

  @override
  String get itemImageRemove => 'Retirer';

  @override
  String get itemImageFailed => 'La photo n\'a pas pu être enregistrée.';

  @override
  String get itemDefaultSupplierLabel => 'Fournisseur par défaut';

  @override
  String get itemDefaultSupplierNone => 'Aucun';

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
  String get itemDeleted => 'Produit supprimé';

  @override
  String get itemSupplierRemoved => 'Fournisseur dissocié';

  @override
  String get itemRemoveSupplierWarning =>
      'Le prix enregistré et son historique pour ce fournisseur seront perdus.';

  @override
  String get addItemTitle => 'Ajouter un produit';

  @override
  String get editItemTitle => 'Modifier le produit';

  @override
  String get itemFormName => 'Nom du produit';

  @override
  String get itemFormNameHint => 'Ex. : Blanc de poulet';

  @override
  String get itemFormThresholdHelp =>
      'Vous serez alerté lorsque le stock atteindra ce niveau ou passera en dessous.';

  @override
  String get itemHolidayMinLabel => 'Stock minimum en forte affluence';

  @override
  String itemHolidayMinHelp(String quantity) {
    return 'Facultatif. Laissez vide pour le double du stock minimum, soit $quantity.';
  }

  @override
  String get itemHolidayMinInvalid =>
      'Le minimum en forte affluence doit dépasser le stock minimum.';

  @override
  String get itemFormSectionIdentity => 'Identité';

  @override
  String get itemFormSectionClassification => 'Classement';

  @override
  String get itemFormSectionLevels => 'Niveaux de stock';

  @override
  String get itemFormSectionNote => 'Note';

  @override
  String get itemMaxStockLabel => 'Stock maximum';

  @override
  String get itemFormMaxStockHelp =>
      'La quantité visée quand le stock est complet. Une commande propose de remonter à ce niveau.';

  @override
  String get itemFormMaxStockInvalid =>
      'Le stock maximum doit être supérieur au stock minimum.';

  @override
  String get itemFormThresholdRequired =>
      'Indiquez un stock minimum supérieur à 0.';

  @override
  String get itemFormNoCostTitle => 'Pas de prix sur cette page';

  @override
  String get itemFormNoCostBody =>
      'Le prix dépend du fournisseur. Associez un ou plusieurs fournisseurs à ce produit pour enregistrer leurs prix respectifs.';

  @override
  String get itemCreated => 'Produit créé';

  @override
  String get itemUpdated => 'Produit modifié';

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
      'Le prix de ce fournisseur pour ce produit. Chaque modification sera enregistrée dans l\'historique.';

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
      'Les catégories servent à classer et filtrer vos produits.';

  @override
  String get categoriesAdd => 'Ajouter une catégorie';

  @override
  String get categoriesEmpty => 'Aucune catégorie';

  @override
  String get categoriesEmptyBody =>
      'Créez une première catégorie pour organiser vos produits.';

  @override
  String categoriesItemCount(int count) {
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
  String categoriesInUseWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count produits utilisent cette catégorie et devront être reclassés.',
      one: '1 produit utilise cette catégorie et devra être reclassé.',
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
      'Créez une première unité pour pouvoir ajouter des produits.';

  @override
  String unitsInUseWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits utilisent cette unité.',
      one: '1 produit utilise cette unité.',
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
  String get movementTypeIn => 'Entrée';

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
      'Ajoutez au stock les produits que vous venez de recevoir.';

  @override
  String get stockInItem => 'Produit';

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
      'Ce produit n\'a pas encore de fournisseur associé.';

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
  String adjustmentLargeDropWarning(String percent) {
    return 'Baisse de $percent — vérifiez votre comptage.';
  }

  @override
  String adjustmentLargeConfirmBodyMany(int count, String percent) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits baissent',
      one: '1 produit baisse',
    );
    return '$_temp0 d\'au moins $percent. Vérifiez votre comptage avant de confirmer.';
  }

  @override
  String movementCountedOf(String counted, String expected) {
    return 'Compté $counted — prévu $expected';
  }

  @override
  String get dateToday => 'Aujourd\'hui';

  @override
  String get dateYesterday => 'Hier';

  @override
  String get pickerTitle => 'Choisir des produits';

  @override
  String get pickerSearchHint => 'Rechercher un produit';

  @override
  String get pickerAllCategories => 'Toutes';

  @override
  String get pickerNoResults => 'Aucun produit ne correspond.';

  @override
  String pickerConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count produits',
      one: 'Ajouter 1 produit',
      zero: 'Sélectionnez des produits',
    );
    return '$_temp0';
  }

  @override
  String get cartEmptyBody =>
      'Touchez les produits concernés — vous pourrez en ajouter d\'autres ensuite.';

  @override
  String get cartAddProduct => 'Ajouter un produit';

  @override
  String cartInStock(String quantity) {
    return 'En stock : $quantity';
  }

  @override
  String cartLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits',
      one: '1 produit',
    );
    return '$_temp0';
  }

  @override
  String get cartRemoveLine => 'Retirer';

  @override
  String get cartTotal => 'Total';

  @override
  String get cartProducts => 'Produits';

  @override
  String get lineChooseSupplier => 'Choisir un fournisseur';

  @override
  String linePriceEdited(String old) {
    return 'prix modifié (avant $old)';
  }

  @override
  String linePriceLabel(String unit) {
    return 'Prix / $unit';
  }

  @override
  String supplierSheetTitle(String item) {
    return 'Fournisseur — $item';
  }

  @override
  String get supplierBestPrice => 'Meilleur prix';

  @override
  String get supplierUsual => 'Habituel';

  @override
  String get supplierApplyAll =>
      'Utiliser ce fournisseur pour tous les produits qu\'il propose';

  @override
  String supplierAppliedAll(String supplier, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits',
      one: '1 produit',
    );
    return '$supplier choisi pour $_temp0';
  }

  @override
  String cartIssueNoSupplier(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits sans fournisseur',
      one: '1 produit sans fournisseur',
    );
    return '$_temp0';
  }

  @override
  String cartIssueNoQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits sans quantité',
      one: '1 produit sans quantité',
    );
    return '$_temp0';
  }

  @override
  String adjustmentExpected(String quantity) {
    return 'prévu $quantity';
  }

  @override
  String get adjustmentMarkCorrect => 'Juste';

  @override
  String adjustmentCorrectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count justes',
      one: '1 juste',
    );
    return '$_temp0';
  }

  @override
  String adjustmentGapCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count écarts',
      one: '1 écart',
    );
    return '$_temp0';
  }

  @override
  String get pickerSectionRestock => 'À réapprovisionner';

  @override
  String get pickerSectionRecent => 'Utilisés récemment';

  @override
  String get pickerSectionAll => 'Tous les produits';

  @override
  String deliveryReceivedOn(String date) {
    return 'Reçue $date';
  }

  @override
  String get actorSheetTitle => 'Qui enregistre ?';

  @override
  String get actorSheetSubtitle =>
      'Touchez votre nom, puis confirmez avec votre numéro PIN.';

  @override
  String get actorMe => 'Moi';

  @override
  String get actorSearchHint => 'Rechercher un employé';

  @override
  String get actorNoEmployees => 'Aucun employé actif dans cet établissement.';

  @override
  String movementsRecordedBy(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mouvements enregistrés',
      one: '1 mouvement enregistré',
    );
    return '$_temp0 par $name';
  }

  @override
  String receiveConfirmedBy(String name) {
    return 'Livraison reçue par $name';
  }

  @override
  String movementsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mouvements enregistrés',
      one: '1 mouvement enregistré',
    );
    return '$_temp0';
  }

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
  String get dashboardTileItems => 'Produits suivis';

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
  String get dashboardAlertsTitle => 'Produits à surveiller';

  @override
  String get dashboardAllGood => 'Tout est en stock';

  @override
  String get dashboardAllGoodBody => 'Aucun produit sous son seuil d\'alerte.';

  @override
  String get dashboardTabActivity => 'Activité';

  @override
  String get dashboardTabAlerts => 'À surveiller';

  @override
  String dashboardAlertLevel(String quantity, String threshold) {
    return '$quantity / seuil $threshold';
  }

  @override
  String get dashboardAddProductShort => 'Produit';

  @override
  String get dashboardEmptyStore => 'Cet établissement est vide';

  @override
  String get dashboardEmptyStoreBody =>
      'Commencez par ajouter vos produits pour suivre votre stock.';

  @override
  String get alertsTitle => 'Alertes de stock';

  @override
  String get alertsSubtitle =>
      'Produits à réapprovisionner, les plus urgents en premier.';

  @override
  String get alertsEmpty => 'Aucune alerte';

  @override
  String get alertsEmptyBody =>
      'Tous vos produits sont au-dessus de leur seuil d\'alerte.';

  @override
  String get alertsSeverityOutOfStock => 'Ruptures';

  @override
  String get alertsSeverityLowStock => 'Stock bas';

  @override
  String get alertsFilterCoverage => 'Couverture';

  @override
  String get alertsFilterSupplier => 'Fournisseur';

  @override
  String get alertsFilterSort => 'Tri';

  @override
  String get alertsFilterAll => 'Toutes';

  @override
  String get alertsFilterAllSuppliers => 'Tous';

  @override
  String get alertsCoverageUncovered => 'Rien en commande';

  @override
  String get alertsCoverageOnOrder => 'En commande';

  @override
  String get alertsSortUrgency => 'Urgence';

  @override
  String get alertsSortShortfall => 'Manque';

  @override
  String get alertsSortName => 'Nom';

  @override
  String get alertsNoSupplier => 'Sans fournisseur';

  @override
  String alertsLevel(String quantity, String threshold) {
    return '$quantity sur $threshold';
  }

  @override
  String get alertsSelectAll => 'Tout sélectionner';

  @override
  String alertsShortfallShort(String quantity) {
    return 'manque $quantity';
  }

  @override
  String get alertsOrder => 'Commander';

  @override
  String alertsSelectionSummary(int items, int suppliers) {
    String _temp0 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items produits',
      one: '1 produit',
    );
    String _temp1 = intl.Intl.pluralLogic(
      suppliers,
      locale: localeName,
      other: '$suppliers fournisseurs',
      one: '1 fournisseur',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get alertsSelectionClear => 'Annuler la sélection';

  @override
  String get alertsColumnItem => 'Produit';

  @override
  String get alertsColumnStock => 'Stock';

  @override
  String get alertsColumnThreshold => 'Seuil';

  @override
  String get alertsColumnShortfall => 'Manque';

  @override
  String get alertsColumnOnOrder => 'En commande';

  @override
  String get alertsColumnStatus => 'Statut';

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
  String get notificationsFilterKind => 'Type';

  @override
  String get notificationsKindStock => 'Stock';

  @override
  String get notificationsKindPrice => 'Prix';

  @override
  String get notificationsKindAdjustment => 'Ajustements';

  @override
  String get notificationsKindDelivery => 'Livraisons';

  @override
  String get notificationsToday => 'Aujourd\'hui';

  @override
  String get notificationsYesterday => 'Hier';

  @override
  String get notificationsMarkRead => 'Marquer comme lue';

  @override
  String get notificationsMarkedOneRead => 'Notification marquée comme lue.';

  @override
  String get notificationsNoneOfKind => 'Aucune notification de ce type';

  @override
  String get notificationsNoneOfKindBody =>
      'Changez le filtre pour voir les autres notifications.';

  @override
  String get reportsTitle => 'Rapports';

  @override
  String get reportsSubtitle =>
      'Valeur de votre stock, consommation et comparaison des prix.';

  @override
  String get reportsValuation => 'Valorisation du stock';

  @override
  String get reportsValuationBody =>
      'Combien vaut ce que vous avez en réserve, par catégorie et par produit.';

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
      'Estimation annuelle si chaque produit était commandé au meilleur prix disponible.';

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
  String get valuationByItem => 'Produits les plus valorisés';

  @override
  String get valuationBasis =>
      'Valorisé au prix du fournisseur par défaut de chaque produit.';

  @override
  String get valuationColumnCategory => 'Catégorie';

  @override
  String get valuationColumnItems => 'Produits';

  @override
  String get valuationColumnValue => 'Valeur';

  @override
  String get valuationColumnShare => 'Part';

  @override
  String get comparisonTitle => 'Comparaison des prix';

  @override
  String get comparisonSubtitle =>
      'Sélectionnez un produit pour comparer les prix de tous ses fournisseurs.';

  @override
  String get comparisonPickItem => 'Produit à comparer';

  @override
  String get comparisonColumnSupplier => 'Fournisseur';

  @override
  String get comparisonColumnPrice => 'Prix';

  @override
  String get comparisonColumnDifference => 'Écart';

  @override
  String get comparisonColumnUpdated => 'Mis à jour';

  @override
  String get comparisonSingleSupplier => 'Un seul fournisseur pour ce produit';

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
      'Recevez une alerte dès qu\'un produit passe sous son seuil.';

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
      'Démonstration : les données restent sur cet appareil. Connectez le compte de votre restaurant (Paramètres → Compte) pour les partager entre appareils.';

  @override
  String get searchTitle => 'Recherche';

  @override
  String get searchHint => 'Produit, code-barres, fournisseur…';

  @override
  String get searchPrompt => 'Que cherchez-vous ?';

  @override
  String get searchPromptBody =>
      'Recherchez parmi vos produits, fournisseurs et catégories.';

  @override
  String get searchSectionItems => 'Produits';

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
  String get settingsTabStoreHint => 'Nom, adresse, horaires et paie';

  @override
  String get settingsTabAccountHint => 'Profil, sécurité et établissements';

  @override
  String get settingsTabNotificationsHint => 'Les alertes que vous recevez';

  @override
  String get settingsTabSyncHint => 'Connexion et données locales';

  @override
  String get settingsTabSyncAttention =>
      'Hors ligne ou modifications en attente';

  @override
  String get movementsTabHistory => 'Historique';

  @override
  String get loadingItems => 'Chargement des produits…';

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
  String get orderColumnItem => 'Produit';

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
  String get shortReceive => 'Réceptionner';

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
  String get orderTimelineCreated => 'Créée';

  @override
  String get orderTimelineSent => 'Envoyée';

  @override
  String orderTimelineReceipt(int number) {
    return 'Réception $number';
  }

  @override
  String get orderTimelineDone => 'Terminée';

  @override
  String get orderTimelineCancelled => 'Annulée';

  @override
  String get orderStepSupplier => 'Fournisseur';

  @override
  String get orderStepLines => 'Produits';

  @override
  String get orderSupplierPrompt => 'Choisissez un fournisseur';

  @override
  String get orderSupplierPromptBody =>
      'Une commande part chez un seul fournisseur. Ce choix filtre les produits proposés et remplit automatiquement les prix.';

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
    return '$_temp0 Les produits et les prix dépendent du fournisseur choisi.';
  }

  @override
  String get orderChangeSupplierAction => 'Changer et vider';

  @override
  String get orderAddLine => 'Ajouter un produit';

  @override
  String get orderLinePickerLabel => 'Produit';

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
  String get orderLinesEmptyTitle => 'Aucun produit';

  @override
  String orderLinesEmptyBody(String supplier) {
    return 'Ajoutez les produits à commander chez $supplier.';
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
      'Produits de ce fournisseur à réapprovisionner.';

  @override
  String get orderSuggestedAddAll => 'Tout ajouter';

  @override
  String get orderSuggestedAdd => 'Ajouter';

  @override
  String orderSuggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits ajoutés.',
      one: '1 produit ajouté.',
    );
    return '$_temp0';
  }

  @override
  String get orderSuggestedEmpty =>
      'Aucun produit de ce fournisseur n\'est en stock faible.';

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
  String itemRangeInline(String minimum, String maximum) {
    return 'min $minimum · max $maximum';
  }

  @override
  String get itemStockValueLabel => 'Valeur du stock';

  @override
  String get itemStockValueUnknown => 'Coût inconnu';

  @override
  String get stockGaugeOverMaximum => 'Au-dessus du stock maximum';

  @override
  String get itemStockRangeLabel => 'Stock min/max';

  @override
  String itemTopUpSuggestion(String quantity) {
    return 'Pour remonter au maximum : $quantity';
  }

  @override
  String get itemDetailsTitle => 'Détails';

  @override
  String get itemDetailsSubtitle => 'Fiche du produit';

  @override
  String get itemOpenOrdersTitle => 'Commandes en cours';

  @override
  String get itemNoOpenOrders => 'Aucune commande en cours pour ce produit.';

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
  String receiptOrderedOf(String quantity) {
    return 'commandé $quantity';
  }

  @override
  String get receiptShortBadge => 'Reste dû';

  @override
  String get receiptClosedShortBadge => 'Soldée';

  @override
  String get receiveUnorderedBadge => 'Non commandé';

  @override
  String get receiveAddUnordered => 'Ajouter un produit non commandé';

  @override
  String get receiveUnorderedAdded =>
      'Produit non commandé ajouté à la réception.';

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
  String get dashboardStaleOrdersBody =>
      'Une commande laissée ouverte gonfle la quantité « en commande » et fausse l\'alerte de double commande.';

  @override
  String alertsOnOrder(String quantity) {
    return '$quantity en route';
  }

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
      'Remet les produits, les stocks, les commandes et les prix dans leur état d\'origine. Les modifications faites pendant la démonstration ne sont conservées que le temps de la session.';

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
      other: '$count produits sont classés dans cette catégorie.',
      one: '1 produit est classé dans cette catégorie.',
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
      other: '$count produits sont mesurés dans cette unité.',
      one: '1 produit est mesuré dans cette unité.',
    );
    return '$_temp0 Changez leur unité avant de la supprimer.';
  }

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
      other: 'Ce produit figure sur $count commandes en cours.',
      one: 'Ce produit figure sur 1 commande en cours.',
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
  String get employeesTitle => 'Personnel';

  @override
  String get employeesSubtitle =>
      'Le personnel de cet établissement — coordonnées, rémunération et rôle.';

  @override
  String get employeesAdd => 'Ajouter un employé';

  @override
  String get employeesSearchHint => 'Rechercher (nom, e-mail)';

  @override
  String get employeeSelectorHint => 'Rechercher ou sélectionner un employé…';

  @override
  String get employeesShowArchived => 'Afficher les personnels retirés';

  @override
  String get employeeStatusActive => 'Actif';

  @override
  String get employeeCardHourlyRate => 'Salaire horaire';

  @override
  String get employeeCardHiredOn => 'Embauché le';

  @override
  String get employeeCardRetiredOn => 'Retiré le';

  @override
  String get employeeCardActions => 'Actions';

  @override
  String get employeesArchivedPill => 'Retiré';

  @override
  String get employeesEmpty => 'Aucun employé';

  @override
  String get employeesEmptyBody =>
      'Ajoutez les membres de votre personnel pour suivre leur pointage et leur paie.';

  @override
  String get employeesKpiActive => 'Personnel actif';

  @override
  String get employeesKpiManagers => 'Gérants';

  @override
  String get employeesKpiAverageRate => 'Tarif moyen';

  @override
  String get employeesKpiMaxRate => 'Tarif max';

  @override
  String get employeesKpiHiredThisMonth => 'Embauches ce mois';

  @override
  String get employeesColumnName => 'Employé';

  @override
  String get employeesColumnRole => 'Rôle';

  @override
  String get employeesColumnPay => 'Tarif';

  @override
  String get employeesColumnActions => 'Actions';

  @override
  String get employeeActionAttendance => 'Historique pointage';

  @override
  String get employeeActionPayroll => 'Historique paiement';

  @override
  String get employeesColumnHired => 'Embauché le';

  @override
  String get employeeWizardStepInfo => 'Informations personnelles';

  @override
  String get employeeWizardStepPayRole => 'Tarif et rôle';

  @override
  String get employeeFormDescription =>
      'Renseignez la fiche en deux étapes : les informations personnelles, puis le tarif et le rôle.';

  @override
  String employeeFormEditDescription(String name) {
    return 'Modifiez la fiche de $name. Chaque étape peut être enregistrée directement.';
  }

  @override
  String get employeeFormFirstNameHint => 'Ex. Nora';

  @override
  String get employeeFormLastNameHint => 'Ex. Benali';

  @override
  String get employeeFormPhoneHint => '+32 470 12 34 56';

  @override
  String get employeeFormEmailHint => 'prenom.nom@exemple.be';

  @override
  String get employeeFormPayHint => 'Ex. 15,50';

  @override
  String get employeeFormPayInvalid => 'Saisissez un taux horaire positif.';

  @override
  String get employeeFormPhoto => 'Photo';

  @override
  String get employeeFormPhotoHelp =>
      'Facultatif · cliquez sur le cercle pour choisir un JPG ou PNG';

  @override
  String get employeeFormPayHelp =>
      'Payé à l\'heure réellement travaillée, pauses déduites.';

  @override
  String get employeeFormAccessStaff =>
      'Un employé n\'a pas accès à l\'application : il pointe au tableau avec son numéro PIN.';

  @override
  String get employeeFormAccessSignIn =>
      'Se connecte à l\'application avec son adresse e-mail et son numéro PIN.';

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
  String get employeeFormPin => 'Numéro PIN';

  @override
  String get employeeFormPhone => 'Téléphone';

  @override
  String get employeeFormEmail => 'Adresse e-mail';

  @override
  String get employeePinTaken => 'Ce numéro PIN est déjà utilisé.';

  @override
  String get employeeEmailTaken => 'Cette adresse e-mail est déjà utilisée.';

  @override
  String get employeeFormRole => 'Rôle et accès';

  @override
  String get employeeFormPayHourly => 'Tarif horaire (€/h)';

  @override
  String get employeeCreated => 'Employé ajouté';

  @override
  String get employeeUpdated => 'Employé modifié';

  @override
  String employeeArchiveTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get employeeArchiveBody =>
      'Cette personne n\'apparaîtra plus dans le personnel actif. Son historique de pointage et de paie reste conservé.';

  @override
  String employeeArchiveWarnInService(String name) {
    return '$name est en service : sa journée restera ouverte jusqu\'à la fermeture de la journée de service.';
  }

  @override
  String employeeArchiveWarnUnpaid(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours terminés ne sont pas encore payés',
      one: '1 jour terminé n\'est pas encore payé',
    );
    return '$_temp0 ($amount). Ils resteront payables dans Paiement.';
  }

  @override
  String get employeeArchiveRefusedSelf =>
      'Vous ne pouvez pas vous retirer vous-même.';

  @override
  String get employeeArchiveRefusedLastOwner =>
      'Impossible de retirer le dernier propriétaire : lui seul peut payer et voir tous les établissements.';

  @override
  String get employeeArchiveFailed =>
      'Cette personne n\'a pas été retirée. Réessayez.';

  @override
  String get employeeArchiveConfirm => 'Retirer';

  @override
  String get employeeArchived => 'Employé retiré';

  @override
  String get employeeRestore => 'Restaurer';

  @override
  String get employeeRestored => 'Employé restauré';

  @override
  String get attendanceStatusNotClockedIn => 'Non pointé';

  @override
  String get attendanceStatusWorking => 'En service';

  @override
  String get attendanceStatusOnBreak => 'En pause';

  @override
  String get attendanceStatusDone => 'Terminé';

  @override
  String get attendanceBreakOverrun => 'Pause dépassée';

  @override
  String get attendanceAnomalyMissingPunch => 'Oubli de pointage';

  @override
  String attendanceAnomalyRetardDetail(String duration) {
    return 'Retard de $duration';
  }

  @override
  String attendanceAnomalyBreakDetail(String duration) {
    return 'Pause dépassée de $duration';
  }

  @override
  String get attendanceAnomalyMissingPunchDetail =>
      'Journée non clôturée — la sortie n\'a jamais été pointée.';

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
  String get timeclockViewDetail => 'Voir détails';

  @override
  String timeclockStartDayPrompt(String date) {
    return 'Vous n\'avez pas encore commencé votre journée du $date. Pointez pour la démarrer.';
  }

  @override
  String timeclockBusinessDayOpen(String date, String time) {
    return 'Journée du $date · ouverte à $time';
  }

  @override
  String timeclockBusinessDayOverdue(int hours) {
    return 'Ouverte depuis plus de $hours h. Pensez à la fermer : tant qu\'elle reste ouverte, chaque nouveau pointage y est rattaché.';
  }

  @override
  String timeclockBusinessDayClosed(String date, String time) {
    return 'Journée du $date fermée à $time';
  }

  @override
  String get timeclockBusinessDayClosedBody => 'Le pointage reprendra demain.';

  @override
  String get timeclockDayClosed => 'Journée fermée';

  @override
  String get timeclockActionRefused =>
      'Action non enregistrée : le pointage a changé entre-temps ou la journée est fermée.';

  @override
  String get timeclockNoBusinessDay => 'Aucune journée ouverte';

  @override
  String timeclockNoBusinessDayBody(String time) {
    return 'Avant $time, un pointage n\'ouvre pas la journée tout seul. Elle s\'ouvrira au premier pointage à partir de $time, ou tout de suite avec « Ouvrir la journée ».';
  }

  @override
  String get timeclockOpenDay => 'Ouvrir la journée';

  @override
  String get timeclockDayNotOpen => 'Journée non ouverte';

  @override
  String timeclockOpenDayDone(String date) {
    return 'Journée du $date ouverte.';
  }

  @override
  String get timeclockOpenDayFailed =>
      'La journée n\'a pas été ouverte : une journée existe déjà pour cette date.';

  @override
  String get timeclockCloseDay => 'Fermer la journée';

  @override
  String timeclockCloseDayTitle(String date) {
    return 'Fermer la journée du $date';
  }

  @override
  String get timeclockCloseDayStillIn =>
      'Ces employés sont encore en service. Indiquez l\'heure de sortie de chacun :';

  @override
  String get timeclockCloseDayAllOut => 'Tout le monde a terminé son service.';

  @override
  String get timeclockCloseDayFinal =>
      'Une fois fermée, la journée ne peut plus être rouverte.';

  @override
  String timeclockCloseDayExit(String time) {
    return 'Sortie à $time';
  }

  @override
  String timeclockCloseDayExitBeforeStart(String time) {
    return 'Avant son arrivée ($time)';
  }

  @override
  String timeclockCloseDayExitBeforePause(String time) {
    return 'Avant le début de sa pause ($time)';
  }

  @override
  String timeclockCloseDayDone(String date) {
    return 'Journée du $date fermée.';
  }

  @override
  String get timeclockCloseDayFailed =>
      'La journée n\'a pas été fermée : le pointage a changé entre-temps. Réessayez.';

  @override
  String timeclockSessionTitle(int number) {
    return 'Session N° $number';
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
  String timeclockLogDepartureSetBy(String name) {
    return 'Départ · saisi par $name';
  }

  @override
  String get timeclockLogDepartureSetByUnknown =>
      'Départ · saisi par un responsable';

  @override
  String get attendanceCorrectExit => 'Corriger la sortie';

  @override
  String get attendanceCorrectExitPick => 'Choisir l\'heure';

  @override
  String attendanceCorrectExitBody(String date, String time) {
    return 'La sortie du $date n\'a jamais été pointée (arrivée à $time). Indiquez l\'heure à laquelle le service s\'est terminé :';
  }

  @override
  String get attendanceCorrectExitFuture =>
      'Cette heure n\'est pas encore passée';

  @override
  String attendanceCorrectExitNextDay(String date) {
    return 'Le lendemain, $date';
  }

  @override
  String get attendanceCorrectExitSigned =>
      'L\'heure saisie est enregistrée à votre nom.';

  @override
  String attendanceCorrectExitDone(String date) {
    return 'Sortie du $date corrigée.';
  }

  @override
  String get attendanceCorrectExitFailed =>
      'La sortie n\'a pas été corrigée : le pointage a changé entre-temps. Réessayez.';

  @override
  String get attendanceDuplicateHeading => 'Pointage en double';

  @override
  String get attendanceDuplicateHint =>
      'Deux arrivées ont été pointées pour ce jour. Supprimez celle qui est en trop : ses heures ne compteront plus.';

  @override
  String attendanceDeleteDuplicate(String times) {
    return 'Supprimer ce pointage en double ($times)';
  }

  @override
  String get attendanceDeleteDuplicateTitle =>
      'Supprimer ce pointage en double ?';

  @override
  String attendanceDeleteDuplicateMessage(String times) {
    return 'Le pointage $times sera retiré de la journée, avec ses pauses. Ses heures ne seront plus comptées.';
  }

  @override
  String get attendanceDeleteDuplicateConfirm => 'Supprimer';

  @override
  String attendanceDeleteDuplicateDone(String times) {
    return 'Pointage $times supprimé.';
  }

  @override
  String get attendanceDeleteDuplicateFailed =>
      'Le pointage n\'a pas été supprimé : la journée a changé entre-temps (payée, ou un seul pointage restant). Réessayez.';

  @override
  String get payrollDoublePaymentTitle => 'Paiement en double';

  @override
  String payrollDoublePaymentMessage(String amount) {
    return 'Ce paiement, fait sur une autre tablette en même temps, a aussi payé des jours déjà payés. Ces jours restent sur le premier paiement. Trop-versé : $amount.';
  }

  @override
  String get identityPromptDeleteDuplicateSubtitle =>
      'Saisissez votre numéro PIN pour supprimer ce pointage en double';

  @override
  String get storeSettingsHours => 'Pauses';

  @override
  String get storeSettingsBusinessDay => 'Journée de service';

  @override
  String storeSettingsAutoOpen(String time) {
    return 'Ouverture automatique à partir de $time';
  }

  @override
  String get storeSettingsAutoOpenHelp =>
      'Avant cette heure, un pointage n\'ouvre pas la journée tout seul ; un gérant peut toujours l\'ouvrir depuis le tableau de pointage. À 00:00, la journée s\'ouvre au premier pointage, à toute heure.';

  @override
  String get storeSettingsMaxBreak => 'Pause max (minutes)';

  @override
  String get storeSettingsHoursHelp =>
      'Une pause plus longue que le maximum est signalée « Pause dépassée ».';

  @override
  String paginatorRange(int first, int last, int total) {
    return '$first–$last sur $total';
  }

  @override
  String get paginatorPrevious => 'Page précédente';

  @override
  String get paginatorNext => 'Page suivante';

  @override
  String get paginatorPageSize => 'Lignes par page :';

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
  String get historyFilterFrom => 'Début';

  @override
  String get historyFilterTo => 'Fin';

  @override
  String attendanceFilterDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get attendanceStatDays => 'Jours pointés';

  @override
  String get attendanceStatWorked => 'Heures travaillées';

  @override
  String get attendanceStatLateBreaks => 'Pauses dépassées';

  @override
  String get attendanceColumnDate => 'Date';

  @override
  String get attendanceColumnEmployee => 'Employé';

  @override
  String get attendanceColumnArrival => 'Arrivée';

  @override
  String get attendanceColumnDeparture => 'Départ';

  @override
  String get attendanceColumnWorked => 'Durée travail';

  @override
  String get attendanceColumnStatus => 'Statut';

  @override
  String get attendanceDayIntro =>
      'Pointages, temps travaillé et pauses de la journée.';

  @override
  String get attendanceDaySummary => 'Résumé de la journée';

  @override
  String get attendanceTotalWorked => 'Durée totale travaillée';

  @override
  String attendancePausesCount(int count) {
    return 'Pauses ($count)';
  }

  @override
  String get attendanceColumnFlags => 'Alertes';

  @override
  String get attendanceViewDetail => 'Voir le détail';

  @override
  String attendanceBreakSummary(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pauses · $duration',
      one: '1 pause · $duration',
    );
    return '$_temp0';
  }

  @override
  String get attendanceCardBreakLabel => 'Pause';

  @override
  String get payrollHistoryTitle => 'Historique de paiement';

  @override
  String get payrollHistorySubtitle =>
      'L\'historique de paiement d\'un employé, jour par jour.';

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
  String get payrollColumnEmployee => 'Employé';

  @override
  String get payrollColumnDate => 'Date';

  @override
  String get payrollColumnWorked => 'Durée travaillée';

  @override
  String get payrollColumnAmount => 'Montant';

  @override
  String get payrollColumnStatus => 'Statut';

  @override
  String get payrollColumnPaidAt => 'Payé le';

  @override
  String get payrollDetailPayNow => 'Payer ce jour';

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
  String get payrollPreviewOutdated =>
      'Les jours à payer ont changé depuis l\'aperçu : rien n\'a été payé. Vérifiez le nouveau montant puis payez à nouveau.';

  @override
  String get payrollPayFailed =>
      'Le paiement n\'a pas été enregistré. Réessayez.';

  @override
  String get payrollColumnBreaks => 'Pauses';

  @override
  String get payrollDayIntro => 'Pointages et montant de la journée.';

  @override
  String get payrollDetailRate => 'Tarif horaire';

  @override
  String payrollRatePerHour(String rate) {
    return '$rate/h';
  }

  @override
  String payrollDetailAmount(String rate, String hours) {
    return 'Montant ($rate × $hours)';
  }

  @override
  String get paymentStatusPaid => 'Payé';

  @override
  String get paymentStatusUnpaid => 'Non payé';

  @override
  String get loginPin => 'Numéro PIN';

  @override
  String get loginPinHint => 'AB.12.34-567.89';

  @override
  String get loginErrorBadCredentials => 'E-mail ou numéro PIN incorrect.';

  @override
  String get loginErrorNoAccess =>
      'Ce compte n\'a pas accès à l\'application. Le pointage se fait au tableau de bord partagé.';

  @override
  String get loginErrorArchived =>
      'Ce compte a été retiré de l\'équipe et n\'a plus accès à l\'application.';

  @override
  String get storeSettingsReadOnlyNotice =>
      'Seul le propriétaire peut modifier les paramètres de l\'établissement.';

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
  String get orderStepProducts => 'Produits';

  @override
  String get orderStepReview => 'Récapitulatif';

  @override
  String get orderContinue => 'Continuer';

  @override
  String get orderEditProducts => 'Modifier les produits';

  @override
  String get orderPickProducts => 'Choisir des produits';

  @override
  String get orderActionDuplicate => 'Dupliquer';

  @override
  String orderDuplicated(String reference) {
    return 'Nouveau brouillon $reference créé';
  }

  @override
  String get ordersTabAll => 'Toutes';

  @override
  String get ordersTabDrafts => 'Brouillons';

  @override
  String get ordersTabSent => 'Envoyées';

  @override
  String get ordersTabPartial => 'Partielles';

  @override
  String get ordersTabDone => 'Terminées';

  @override
  String get tableColReference => 'Référence';

  @override
  String get tableColLines => 'Lignes';

  @override
  String get tableColAmount => 'Montant';

  @override
  String get tableColReceived => 'Reçu';

  @override
  String get navPurchases => 'Achats';

  @override
  String get navReceptions => 'Réceptions';

  @override
  String get receptionsTitle => 'Réceptions';

  @override
  String get receptionsSubtitle => 'Ce qui doit arriver, et ce qui est arrivé.';

  @override
  String get receptionsTabPending => 'À réceptionner';

  @override
  String get receptionsTabHistory => 'Historique';

  @override
  String get receptionsPendingEmpty => 'Rien à réceptionner';

  @override
  String get receptionsPendingEmptyBody =>
      'Toutes les commandes envoyées ont été réceptionnées.';

  @override
  String get receptionsHistoryEmpty => 'Aucune réception pour le moment';

  @override
  String get receptionsHistoryEmptyBody =>
      'Les livraisons réceptionnées apparaîtront ici.';

  @override
  String receptionsSentOn(String date) {
    return 'Envoyée le $date';
  }

  @override
  String receptionsLinesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits à recevoir',
      one: '1 produit à recevoir',
    );
    return '$_temp0';
  }

  @override
  String get receptionsLate => 'En retard';

  @override
  String get receptionsReceive => 'Réceptionner';

  @override
  String get receptionsConform => 'Conforme';

  @override
  String receptionsDiscrepancies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count écarts',
      one: '1 écart',
    );
    return '$_temp0';
  }

  @override
  String get tableColReceipt => 'Bon';

  @override
  String get tableColOrder => 'Commande';

  @override
  String get tableColSupplier => 'Fournisseur';

  @override
  String get tableColReceivedBy => 'Reçu par';

  @override
  String get tableColDiscrepancies => 'Écarts';

  @override
  String get orderDocAction => 'Bon de commande (PDF)';

  @override
  String get orderDocActionShort => 'PDF';

  @override
  String get orderDocTitle => 'BON DE COMMANDE';

  @override
  String get orderDocDraft => 'BROUILLON — NON ENVOYÉ';

  @override
  String get orderDocDeliverTo => 'Livrer à';

  @override
  String get orderDocDate => 'Date';

  @override
  String get orderDocColumnQuantity => 'Quantité';

  @override
  String get orderDocColumnUnitPrice => 'Prix unitaire';

  @override
  String get orderDocColumnTotal => 'Total';

  @override
  String get orderDocTotalLabel => 'Total de la commande';

  @override
  String get orderDocClosing =>
      'Merci de confirmer la commande et la date de livraison.';

  @override
  String orderDocFooter(String date) {
    return 'Document généré le $date — ne constitue pas une facture.';
  }

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
  String get receiptDocColumnItem => 'Produit';

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
  String get identityPromptTitle => 'Confirmation d\'identité';

  @override
  String get identityPromptField => 'Numéro PIN';

  @override
  String get identityPromptValidate => 'Valider';

  @override
  String get identityPromptWrong => 'Numéro incorrect. Réessayez.';

  @override
  String identityPromptPointageSubtitle(String action, String name) {
    return '$action · saisissez le numéro PIN de $name';
  }

  @override
  String identityPromptOpenDaySubtitle(String date) {
    return 'Saisissez votre numéro PIN pour ouvrir la journée du $date';
  }

  @override
  String identityPromptCloseDaySubtitle(String date) {
    return 'Saisissez votre numéro PIN pour fermer la journée du $date';
  }

  @override
  String identityPromptCorrectExitSubtitle(String date) {
    return 'Saisissez votre numéro PIN pour corriger la sortie du $date';
  }

  @override
  String identityPromptPayrollSubtitle(String name) {
    return 'Saisissez votre numéro PIN pour valider le paiement de $name';
  }

  @override
  String get navCalendar => 'Calendrier';

  @override
  String get calendarTitle => 'Calendrier';

  @override
  String get calendarSubtitle => 'Soyez prévenu avant les jours chargés.';

  @override
  String get calendarWeekdaysTitle => 'Chaque semaine';

  @override
  String get calendarDatesTitle => 'Jours spéciaux';

  @override
  String get calendarDatesBody => 'Touchez un jour pour l\'ajouter.';

  @override
  String get calendarLegendWeekly => 'Chaque semaine';

  @override
  String get calendarLegendSpecial => 'Spécial';

  @override
  String get calendarPreviousMonth => 'Mois précédent';

  @override
  String get calendarNextMonth => 'Mois suivant';

  @override
  String get calendarReminderTitle => 'Me prévenir avant';

  @override
  String calendarReminderDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours avant',
      one: '1 jour avant',
    );
    return '$_temp0';
  }

  @override
  String calendarPeriodRange(String start, String end) {
    return 'du $start au $end';
  }

  @override
  String get busyWhenOngoing => 'en cours';

  @override
  String get busyWhenTomorrow => 'demain';

  @override
  String busyWhenInDays(int days) {
    return 'dans $days jours';
  }

  @override
  String get alertsBusyTab => 'Jours chargés';

  @override
  String alertsBusyBannerTitle(String when) {
    return 'Jours chargés $when';
  }

  @override
  String alertsBusyBannerBody(int count, String period) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$period : $count produits sont sous le minimum de forte affluence.',
      one: '$period : 1 produit est sous le minimum de forte affluence.',
      zero: '$period : tout le stock est prêt.',
    );
    return '$_temp0';
  }

  @override
  String get alertsBusyShow => 'Voir la liste';

  @override
  String get alertsBusyEmpty => 'Tout le stock est prêt pour les jours chargés';

  @override
  String get alertsBusyEmptyBody =>
      'Chaque produit atteint son minimum de forte affluence.';

  @override
  String get notificationsKindBusyDays => 'Jours chargés';

  @override
  String get notificationsKindPersonnel => 'Personnel';

  @override
  String get notificationPrefBusyDays => 'Jours chargés à venir';

  @override
  String get notificationPrefBusyDaysBody =>
      'Soyez prévenu avant les jours de forte affluence du calendrier, avec les produits à commander.';

  @override
  String get calendarHeroNextLabel => 'Prochains jours chargés';

  @override
  String get calendarHeroOngoingLabel => 'Jours chargés en cours';

  @override
  String get calendarHeroNoneTitle => 'Aucun jour chargé';

  @override
  String get calendarHeroNoneBody => 'Choisissez des jours ci-dessous.';

  @override
  String get calendarHeroReminderActive => 'Rappel actif';

  @override
  String calendarHeroReminderOn(String date) {
    return 'Rappel $date';
  }

  @override
  String calendarHeroReminderSince(String date) {
    return 'Rappel depuis $date';
  }

  @override
  String calendarHeroShortCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count à commander',
      zero: 'Stock prêt',
    );
    return '$_temp0';
  }

  @override
  String get calendarHeroShowProducts => 'Voir';

  @override
  String calendarCountdownUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jours',
      one: 'jour',
    );
    return '$_temp0';
  }

  @override
  String get calendarCountdownNow => 'En cours';

  @override
  String get calendarToday => 'Aujourd\'hui';

  @override
  String get calendarLegendReminder => 'Rappel';

  @override
  String calendarReminderShort(int days) {
    return '$days j';
  }

  @override
  String get calendarUpcomingTitle => 'À venir';

  @override
  String get calendarUpcomingEmpty => 'Aucun jour spécial.';

  @override
  String calendarUpcomingMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+ $count autres',
      one: '+ 1 autre',
    );
    return '$_temp0';
  }

  @override
  String get calendarRemoveDate => 'Retirer ce jour';

  @override
  String get calendarRelativeToday => 'aujourd\'hui';

  @override
  String get welcomeTitle => 'Bienvenue';

  @override
  String get welcomeSubtitle => 'Connectez-vous au compte de votre restaurant.';

  @override
  String get accountEmail => 'Adresse e-mail';

  @override
  String get accountPassword => 'Mot de passe';

  @override
  String get accountPasswordHint => '8 caractères minimum';

  @override
  String get accountSignIn => 'Se connecter';

  @override
  String get accountCreate => 'Créer un compte';

  @override
  String get accountForgotLink => 'Mot de passe oublié ?';

  @override
  String get welcomeTryDemo => 'Essayer la démo';

  @override
  String get welcomeDemoHint =>
      'Un restaurant fictif, sur cet appareil seulement. Rien n\'est envoyé.';

  @override
  String get welcomeOr => 'ou';

  @override
  String get accountDemoWipeWarning =>
      'Les données de démonstration de cet appareil seront effacées.';

  @override
  String get accountServerMissing =>
      'Aucun serveur n\'est configuré dans cette version. La démo reste disponible.';

  @override
  String get signUpTitle => 'Créer un compte';

  @override
  String get signUpSubtitle =>
      'Le compte du propriétaire ou d\'un gérant du restaurant.';

  @override
  String get signUpPasswordConfirm => 'Confirmer le mot de passe';

  @override
  String get signUpPasswordMismatch =>
      'Les deux mots de passe ne correspondent pas.';

  @override
  String get signUpPasswordTooShort =>
      'Le mot de passe doit faire au moins 8 caractères.';

  @override
  String get signUpSubmit => 'Créer le compte';

  @override
  String get signUpHaveAccount => 'Déjà un compte ? Se connecter';

  @override
  String get setupTitle => 'Votre restaurant';

  @override
  String get setupSubtitle =>
      'Créez votre restaurant, ou rejoignez-en un avec le code du propriétaire.';

  @override
  String get setupCreateTab => 'Créer';

  @override
  String get setupJoinTab => 'Rejoindre';

  @override
  String get setupRestaurantName => 'Nom du restaurant';

  @override
  String get setupCity => 'Ville';

  @override
  String get setupPhone => 'Téléphone';

  @override
  String get setupFirstName => 'Prénom';

  @override
  String get setupLastName => 'Nom';

  @override
  String get setupPin => 'Votre PIN';

  @override
  String get setupPinHint =>
      'Avec votre adresse e-mail, il vous connecte aux tablettes du restaurant.';

  @override
  String get setupCreateSubmit => 'Créer le restaurant';

  @override
  String get setupJoinCode => 'Code d\'invitation';

  @override
  String get setupJoinCodeHint => '8 caractères, donnés par le propriétaire';

  @override
  String get setupJoinSubmit => 'Rejoindre le restaurant';

  @override
  String setupSignedInAs(String email) {
    return 'Connecté en tant que $email';
  }

  @override
  String get setupNotSignedIn =>
      'Connectez-vous d\'abord au compte du restaurant.';

  @override
  String get setupFieldsRequired => 'Remplissez tous les champs.';

  @override
  String get forgotAccountTitle => 'Mot de passe oublié';

  @override
  String get forgotAccountSubtitle =>
      'Recevez un lien pour choisir un nouveau mot de passe.';

  @override
  String get forgotAccountSubmit => 'Envoyer le lien';

  @override
  String get forgotAccountSent =>
      'Si un compte existe pour cette adresse, un e-mail vient de partir.';

  @override
  String get forgotAccountBack => 'Retour à la connexion';

  @override
  String get waitingTitle => 'Presque prêt';

  @override
  String get accountErrorUnavailable => 'Aucun serveur n\'est configuré.';

  @override
  String get accountErrorNetwork =>
      'Le serveur est injoignable. Vérifiez la connexion et réessayez.';

  @override
  String get accountErrorBadCredentials =>
      'Adresse e-mail ou mot de passe incorrect.';

  @override
  String get accountErrorEmailTaken =>
      'Un compte existe déjà avec cette adresse.';

  @override
  String get accountErrorWeakPassword =>
      'Mot de passe trop faible : 8 caractères minimum.';

  @override
  String get accountErrorConfirmEmail =>
      'Confirmez votre adresse e-mail avec le lien reçu, puis connectez-vous.';

  @override
  String get accountErrorInvalidCode => 'Code invalide ou expiré.';

  @override
  String get accountErrorAlreadyMember =>
      'Ce compte appartient déjà à un restaurant.';

  @override
  String get accountErrorNotAllowed => 'Seul le propriétaire peut faire cela.';

  @override
  String get accountErrorUnknown => 'Une erreur est survenue. Réessayez.';

  @override
  String get accountSectionTitle => 'Compte du restaurant';

  @override
  String get accountSectionDemo =>
      'Cet appareil utilise la démo. Connectez le compte de votre restaurant pour travailler sur plusieurs appareils.';

  @override
  String get accountConnect => 'Connecter un compte';

  @override
  String get accountRoleOwner => 'Propriétaire';

  @override
  String get accountRoleManager => 'Gérant';

  @override
  String get accountInvite => 'Inviter un gérant';

  @override
  String get accountInviteTitle => 'Code d\'invitation';

  @override
  String get accountInviteBody =>
      'Donnez ce code au gérant : il l\'entre après avoir créé son compte. Valable 7 jours, une seule fois.';

  @override
  String get accountDevices => 'Appareils';

  @override
  String get accountDeviceThis => 'Cet appareil';

  @override
  String accountDeviceLastSeen(String date) {
    return 'Vu le $date';
  }

  @override
  String get accountDeviceRemove => 'Retirer';

  @override
  String get accountDeviceRemoveConfirm =>
      'Retirer cet appareil ? Il ne pourra plus envoyer de modifications.';

  @override
  String get accountDevicesUnavailable =>
      'La liste des appareils demande une connexion au serveur.';

  @override
  String get accountSignOut => 'Se déconnecter du compte';

  @override
  String get accountSignOutTitle => 'Se déconnecter du compte ?';

  @override
  String get accountSignOutBody =>
      'Toutes les données de cet appareil seront effacées. Celles déjà envoyées restent sur le serveur.';

  @override
  String accountSignOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count modifications n\'ont pas encore été envoyées et seront perdues.',
      one: '1 modification n\'a pas encore été envoyée et sera perdue.',
    );
    return '$_temp0';
  }

  @override
  String get signUpDone => 'Compte créé.';

  @override
  String get accountErrorSessionExpired =>
      'La session du compte a expiré. Reconnectez-vous.';

  @override
  String get syncStateIdle => 'À jour';

  @override
  String get syncStateSyncing => 'Synchronisation…';

  @override
  String get syncStateOffline => 'Hors ligne — nouvel essai automatique';

  @override
  String get syncStateError => 'Synchronisation arrêtée';

  @override
  String get syncStateDisabled => 'Démonstration — rien n\'est envoyé';

  @override
  String get syncLastSyncedNever => 'Jamais';

  @override
  String get syncDone => 'Tout est envoyé.';

  @override
  String syncDoneWithRejections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Envoyé. $count modifications ont été refusées.',
      one: 'Envoyé. 1 modification a été refusée.',
    );
    return '$_temp0';
  }

  @override
  String get syncProblemOffline =>
      'Le serveur est injoignable. Les modifications restent sur l\'appareil et partiront au retour de la connexion.';

  @override
  String get syncProblemSessionExpired =>
      'La session du compte a expiré. Reconnectez-vous pour reprendre l\'envoi.';

  @override
  String get syncProblemDeviceRemoved =>
      'Le propriétaire a retiré cet appareil du restaurant. Les modifications restent sur l\'appareil.';

  @override
  String get syncProblemFailed =>
      'Le serveur a refusé l\'envoi. Nouvel essai automatique.';

  @override
  String get syncReconnect => 'Se reconnecter';

  @override
  String get syncReconnectTitle => 'Reconnecter le compte';

  @override
  String syncReconnectBody(String email) {
    return 'Mot de passe de $email';
  }

  @override
  String get syncRejectedTitle => 'À vérifier';

  @override
  String get syncRejectedDismiss => 'Compris';

  @override
  String get syncReasonDeleted => 'Supprimé entre-temps sur un autre appareil.';

  @override
  String get syncReasonStatusBackwards =>
      'Le statut de la commande ne peut pas revenir en arrière.';

  @override
  String get syncReasonStatusClosed => 'La commande était déjà clôturée.';

  @override
  String get syncReasonAlreadyPaid => 'Cette période de paie était déjà payée.';

  @override
  String get syncReasonDayAlreadyPaid =>
      'Ce jour avait déjà été payé sur une autre tablette : il reste sur ce premier paiement (voir le signalement « Paiement en double »).';

  @override
  String get syncReasonPaidDayFrozen =>
      'Ce jour est déjà payé : la modification n\'a pas été appliquée.';

  @override
  String get syncReasonNoAccess => 'Pas d\'accès à cet établissement.';

  @override
  String get syncReasonOwnerOnly =>
      'Seul le propriétaire peut modifier un établissement.';

  @override
  String get syncReasonStoreChanged =>
      'Cette donnée ne peut pas changer d\'établissement.';

  @override
  String get syncReasonInvalid =>
      'Le serveur n\'a pas accepté cette modification.';

  @override
  String syncTableName(String table) {
    String _temp0 = intl.Intl.selectLogic(table, {
      'stores': 'Établissement',
      'categories': 'Catégorie',
      'units': 'Unité',
      'items': 'Article',
      'suppliers': 'Fournisseur',
      'supplier_prices': 'Prix fournisseur',
      'price_history': 'Historique de prix',
      'stock_movements': 'Mouvement de stock',
      'purchase_orders': 'Commande',
      'purchase_order_lines': 'Ligne de commande',
      'goods_receipts': 'Réception',
      'goods_receipt_lines': 'Ligne de réception',
      'notifications': 'Notification',
      'employees': 'Employé',
      'employee_credentials': 'Accès employé',
      'payroll_periods': 'Période de paie',
      'attendances': 'Pointage',
      'attendance_sessions': 'Pointage',
      'attendance_pauses': 'Pause',
      'busy_dates': 'Jour chargé',
      'business_days': 'Journée de service',
      'other': 'Donnée',
    });
    return '$_temp0';
  }

  @override
  String waitingDownloading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Téléchargement des données… $count éléments',
      one: 'Téléchargement des données… 1 élément',
      zero: 'Téléchargement des données…',
    );
    return '$_temp0';
  }

  @override
  String get waitingRetry => 'Réessayer maintenant';

  @override
  String waitingBodyNow(String restaurant) {
    return 'Cet appareil est relié à $restaurant. Ses données arrivent du serveur ; l\'application s\'ouvrira dès qu\'elles seront là.';
  }

  @override
  String catalogDuplicate(String name) {
    return '« $name » existe en double, souvent parce qu\'il a été créé sur deux tablettes hors ligne.';
  }

  @override
  String get catalogMerge => 'Fusionner';

  @override
  String catalogMergeTitle(String name) {
    return 'Fusionner « $name » ?';
  }

  @override
  String catalogMergeBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles seront déplacés, puis les doublons supprimés.',
      one: '1 article sera déplacé, puis les doublons supprimés.',
      zero: 'Les doublons, vides, seront supprimés.',
    );
    return '$_temp0';
  }

  @override
  String get catalogMerged => 'Doublons fusionnés.';

  @override
  String get attendanceAnomalyDoubleClockIn => 'Double pointage';

  @override
  String get attendanceAnomalyDoubleClockInDetail =>
      'Deux tablettes ont pointé cette journée en même temps. Vérifiez les heures qui se chevauchent avant la paie.';

  @override
  String get syncReasonReceiveConflict =>
      'Cette donnée reçue n\'a pas pu être enregistrée sur cet appareil.';

  @override
  String syncResolvedDoubleClockIn(String name, String date) {
    return 'Deux pointages de $name le $date ont été regroupés. À vérifier dans l\'historique.';
  }

  @override
  String syncResolvedDoubleBusinessDay(String date) {
    return 'La journée du $date avait été ouverte sur deux tablettes ; une seule a été gardée. Aucun pointage n\'a bougé.';
  }

  @override
  String get syncResolvedDuplicateLink =>
      'Un fournisseur était lié deux fois au même article : le lien le plus récent a été gardé.';

  @override
  String get existingDataTitle => 'Données déjà sur cet appareil';

  @override
  String existingDataAccountEmpty(String restaurant, String stores) {
    return 'Le compte « $restaurant » est encore vide. Cet appareil contient déjà : $stores. Vous pouvez envoyer ces données vers le compte.';
  }

  @override
  String existingDataAccountFull(String restaurant, String stores) {
    return 'Le compte « $restaurant » contient déjà des données. Celles de cet appareil ($stores) seront enregistrées dans un fichier de sauvegarde, puis remplacées par celles du compte.';
  }

  @override
  String get existingDataSend => 'Envoyer mes données';

  @override
  String get existingDataBackupAndContinue => 'Sauvegarder et continuer';

  @override
  String get existingDataStartEmpty => 'Commencer vide';

  @override
  String get existingDataUse => 'Utiliser ces données';

  @override
  String existingDataOnDevice(String stores) {
    return 'Cet appareil contient déjà : $stores. Créez le restaurant avec ces données, ou commencez vide (elles seront sauvegardées dans un fichier).';
  }

  @override
  String existingDataJoinNotice(String stores) {
    return 'Cet appareil contient déjà : $stores. Elles seront sauvegardées dans un fichier, puis remplacées par les données du restaurant rejoint.';
  }

  @override
  String get existingDataSent => 'Vos données partent vers le compte.';

  @override
  String existingDataBackedUp(String path) {
    return 'Sauvegarde enregistrée : $path';
  }

  @override
  String get syncDeviceLabel => 'Cet appareil';

  @override
  String get syncAccountLabel => 'Compte';

  @override
  String get syncRestaurantLabel => 'Restaurant';

  @override
  String get syncPhotosPending => 'Photos en attente d\'envoi';

  @override
  String get offlineBannerServer => 'Serveur injoignable';
}
