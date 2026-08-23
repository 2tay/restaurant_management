import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../dev/theme_gallery_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/onboarding_page.dart';
import '../features/catalog/presentation/pages/categories_page.dart';
import '../features/catalog/presentation/pages/units_page.dart';
import '../features/inventory/presentation/pages/add_edit_item_page.dart';
import '../features/inventory/presentation/pages/inventory_list_page.dart';
import '../features/inventory/presentation/pages/item_detail_page.dart';
import '../features/inventory/presentation/pages/item_price_history_page.dart';
import '../features/inventory/presentation/pages/link_supplier_to_item_page.dart';
import '../features/stores/presentation/pages/add_store_page.dart';
import '../features/stock_movement/presentation/pages/stock_adjustment_page.dart';
import '../features/stock_movement/presentation/pages/stock_history_page.dart';
import '../features/stock_movement/presentation/pages/stock_in_page.dart';
import '../features/stock_movement/presentation/pages/stock_out_page.dart';
import '../features/stores/presentation/pages/store_selector_page.dart';
import '../mock_data/mock_data.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/placeholder_page.dart';
import 'routes.dart';

/// The application router.
///
/// Two route groups:
///
/// - **Outside the shell** — login, password reset, onboarding and the store
///   selector. These have no navigation rail, because there is no store context
///   to navigate within yet.
/// - **Inside the [ShellRoute]** — everything store-scoped, under
///   `/store/:storeId/`. The shell resolves the store once and hands it to
///   [AppScaffold], so the rail and top bar persist across navigations.
///
/// Screens still to be built resolve to [PlaceholderPage]; Stage 5 swaps them
/// out one at a time.

/// Pulls the store id out of a store-scoped route.
///
/// The `!` is safe: every route using this sits under `/store/:storeId/`, so
/// go_router cannot match it without the parameter present.
String _storeId(GoRouterState state) => state.pathParameters['storeId']!;

final GoRouter appRouter = GoRouter(
  // Phase 1 has no authentication, so the app opens on the login screen and
  // every button simply navigates onward. There is no redirect guard here on
  // purpose — adding one would be the start of the auth logic the brief defers.
  initialLocation: Routes.login,
  debugLogDiagnostics: false,
  routes: [
    // -------------------------------------------------------------------------
    // Auth and store selection — no shell
    // -------------------------------------------------------------------------
    GoRoute(path: Routes.login, builder: (context, state) => const LoginPage()),
    GoRoute(
      path: Routes.forgotPassword,
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: Routes.onboarding,
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: Routes.stores,
      builder: (context, state) => const StoreSelectorPage(),
    ),
    GoRoute(
      path: Routes.addStore,
      builder: (context, state) => const AddStorePage(),
    ),

    // Development only. Reachable at /dev/gallery, linked from nothing —
    // it is a reference for whoever is building screens, not a feature.
    GoRoute(
      path: Routes.devGallery,
      builder: (context, state) => const ThemeGalleryPage(),
    ),

    // -------------------------------------------------------------------------
    // Store-scoped — inside the shell
    // -------------------------------------------------------------------------
    ShellRoute(
      builder: (context, state, child) {
        // Falls back to the first store rather than throwing, so a stale link
        // or a hot reload mid-navigation shows the app instead of a red screen.
        final store = MockQueries.storeByIdOrFirst(
          state.pathParameters['storeId'],
        );
        return AppScaffold(store: store, child: child);
      },
      routes: [
        GoRoute(
          path: Routes.dashboard,
          builder: (context, state) => const PlaceholderPage(
            title: 'Tableau de bord',
            note: 'features/dashboard',
          ),
        ),

        // --- Inventory -------------------------------------------------------
        //
        // `new` is declared before `:itemId` because go_router matches in
        // order — otherwise "new" would be read as an item id.
        GoRoute(
          path: Routes.inventory,
          builder: (context, state) =>
              InventoryListPage(storeId: _storeId(state)),
        ),
        GoRoute(
          path: Routes.addItem,
          builder: (context, state) =>
              AddEditItemPage(storeId: _storeId(state)),
        ),
        GoRoute(
          path: Routes.itemDetail,
          builder: (context, state) => ItemDetailPage(
            storeId: _storeId(state),
            itemId: state.pathParameters['itemId']!,
          ),
        ),
        GoRoute(
          path: Routes.editItem,
          builder: (context, state) => AddEditItemPage(
            storeId: _storeId(state),
            itemId: state.pathParameters['itemId'],
          ),
        ),
        GoRoute(
          path: Routes.linkSupplier,
          builder: (context, state) => LinkSupplierToItemPage(
            storeId: _storeId(state),
            itemId: state.pathParameters['itemId']!,
          ),
        ),
        GoRoute(
          path: Routes.itemPriceHistory,
          builder: (context, state) => ItemPriceHistoryPage(
            storeId: _storeId(state),
            itemId: state.pathParameters['itemId']!,
            supplierId: state.pathParameters['supplierId']!,
          ),
        ),

        // --- Catalog ---------------------------------------------------------
        GoRoute(
          path: Routes.categories,
          builder: (context, state) => CategoriesPage(storeId: _storeId(state)),
        ),
        GoRoute(
          path: Routes.units,
          builder: (context, state) => UnitsPage(storeId: _storeId(state)),
        ),

        // --- Stock movement --------------------------------------------------
        GoRoute(
          path: Routes.movements,
          builder: (context, state) =>
              StockHistoryPage(storeId: _storeId(state)),
        ),
        GoRoute(
          path: Routes.stockIn,
          builder: (context, state) => StockInPage(storeId: _storeId(state)),
        ),
        GoRoute(
          path: Routes.stockOut,
          builder: (context, state) => StockOutPage(storeId: _storeId(state)),
        ),
        GoRoute(
          path: Routes.stockAdjustment,
          builder: (context, state) =>
              StockAdjustmentPage(storeId: _storeId(state)),
        ),

        // --- Alerts ----------------------------------------------------------
        GoRoute(
          path: Routes.alerts,
          builder: (context, state) => const PlaceholderPage(
            title: 'Alertes de stock',
            note: 'features/alerts',
          ),
        ),
        GoRoute(
          path: Routes.notifications,
          builder: (context, state) => const PlaceholderPage(
            title: 'Notifications',
            note: 'features/alerts',
          ),
        ),

        // --- Suppliers -------------------------------------------------------
        GoRoute(
          path: Routes.suppliers,
          builder: (context, state) => const PlaceholderPage(
            title: 'Fournisseurs',
            note: 'features/suppliers',
          ),
        ),
        GoRoute(
          path: Routes.addSupplier,
          builder: (context, state) => const PlaceholderPage(
            title: 'Ajouter un fournisseur',
            note: 'features/suppliers',
          ),
        ),
        GoRoute(
          path: Routes.supplierDetail,
          builder: (context, state) => const PlaceholderPage(
            title: 'Détail du fournisseur',
            note: 'features/suppliers',
          ),
        ),
        GoRoute(
          path: Routes.editSupplier,
          builder: (context, state) => const PlaceholderPage(
            title: 'Modifier le fournisseur',
            note: 'features/suppliers',
          ),
        ),
        GoRoute(
          path: Routes.supplierPricing,
          builder: (context, state) => const PlaceholderPage(
            title: 'Tarifs du fournisseur',
            note: 'features/suppliers',
          ),
        ),

        // --- Reports ---------------------------------------------------------
        GoRoute(
          path: Routes.reports,
          builder: (context, state) => const PlaceholderPage(
            title: 'Rapports',
            note: 'features/reports',
          ),
        ),
        GoRoute(
          path: Routes.valuationReport,
          builder: (context, state) => const PlaceholderPage(
            title: 'Valorisation du stock',
            note: 'features/reports',
          ),
        ),
        GoRoute(
          path: Routes.comparisonReport,
          builder: (context, state) => const PlaceholderPage(
            title: 'Comparaison des prix',
            note: 'features/reports',
          ),
        ),
        GoRoute(
          path: Routes.usageReport,
          builder: (context, state) => const PlaceholderPage(
            title: 'Consommation',
            note: 'features/reports',
          ),
        ),

        // --- Team ------------------------------------------------------------
        //
        // `new` and `roles` precede `:memberId` for the same ordering reason as
        // the inventory routes.
        GoRoute(
          path: Routes.team,
          builder: (context, state) =>
              const PlaceholderPage(title: 'Équipe', note: 'features/team'),
        ),
        GoRoute(
          path: Routes.addTeamMember,
          builder: (context, state) => const PlaceholderPage(
            title: 'Inviter un membre',
            note: 'features/team',
          ),
        ),
        GoRoute(
          path: Routes.roles,
          builder: (context, state) => const PlaceholderPage(
            title: 'Rôles et permissions',
            note: 'features/team',
          ),
        ),
        GoRoute(
          path: Routes.editTeamMember,
          builder: (context, state) => const PlaceholderPage(
            title: 'Modifier le membre',
            note: 'features/team',
          ),
        ),

        // --- Settings --------------------------------------------------------
        GoRoute(
          path: Routes.storeSettings,
          builder: (context, state) => const PlaceholderPage(
            title: "Paramètres de l'établissement",
            note: 'features/settings',
          ),
        ),
        GoRoute(
          path: Routes.accountSettings,
          builder: (context, state) => const PlaceholderPage(
            title: 'Paramètres du compte',
            note: 'features/settings',
          ),
        ),
        GoRoute(
          path: Routes.notificationSettings,
          builder: (context, state) => const PlaceholderPage(
            title: 'Préférences de notification',
            note: 'features/settings',
          ),
        ),
        GoRoute(
          path: Routes.syncStatus,
          builder: (context, state) => const PlaceholderPage(
            title: 'État de la synchronisation',
            note: 'features/settings',
          ),
        ),

        // --- Global search ---------------------------------------------------
        GoRoute(
          path: Routes.search,
          builder: (context, state) =>
              const PlaceholderPage(title: 'Recherche', note: 'shared/widgets'),
        ),
      ],
    ),
  ],

  // A 404 in a demo is worse than a 404 in production — there is nobody to file
  // a bug, only a client watching. Offer a way back.
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Page introuvable',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(state.uri.path, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(Routes.stores),
            child: const Text('Retour aux établissements'),
          ),
        ],
      ),
    ),
  ),
);
