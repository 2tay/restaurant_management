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
}
