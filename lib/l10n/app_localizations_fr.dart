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
}
