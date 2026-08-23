import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';

/// One entry in the navigation rail.
class _Destination {
  const _Destination({
    required this.icon,
    required this.label,
    required this.pathBuilder,
    required this.matchSegment,
  });

  final IconData icon;
  final String Function(AppLocalizations l10n) label;
  final String Function(String storeId) pathBuilder;

  /// The path segment that marks this section as active. A detail screen deep
  /// inside a section keeps its rail entry highlighted, which is what stops the
  /// user losing their place after three taps.
  final String matchSegment;
}

/// The persistent navigation rail.
///
/// A rail rather than bottom navigation: this is a tablet, and the brief calls
/// for it explicitly. It collapses to icons only below
/// [AppBreakpoints.railCollapse] so a 7" tablet, or a 10" held in portrait,
/// keeps enough width for the content area.
class AppSidebar extends StatelessWidget {
  const AppSidebar({required this.storeId, super.key});

  final String storeId;

  static const List<_Destination> _destinations = [
    _Destination(
      icon: LucideIcons.layoutDashboard,
      label: _labelDashboard,
      pathBuilder: Routes.toDashboard,
      matchSegment: 'dashboard',
    ),
    _Destination(
      icon: LucideIcons.boxes,
      label: _labelInventory,
      pathBuilder: Routes.toInventory,
      matchSegment: 'inventory',
    ),
    _Destination(
      icon: LucideIcons.arrowRightLeft,
      label: _labelMovements,
      pathBuilder: Routes.toMovements,
      matchSegment: 'movements',
    ),
    _Destination(
      icon: LucideIcons.truck,
      label: _labelSuppliers,
      pathBuilder: Routes.toSuppliers,
      matchSegment: 'suppliers',
    ),
    _Destination(
      icon: LucideIcons.tags,
      label: _labelCatalog,
      pathBuilder: Routes.toCategories,
      matchSegment: 'catalog',
    ),
    _Destination(
      icon: LucideIcons.triangleAlert,
      label: _labelAlerts,
      pathBuilder: Routes.toAlerts,
      matchSegment: 'alerts',
    ),
    _Destination(
      icon: LucideIcons.chartColumn,
      label: _labelReports,
      pathBuilder: Routes.toReports,
      matchSegment: 'reports',
    ),
    _Destination(
      icon: LucideIcons.users,
      label: _labelTeam,
      pathBuilder: Routes.toTeam,
      matchSegment: 'team',
    ),
    _Destination(
      icon: LucideIcons.settings,
      label: _labelSettings,
      pathBuilder: Routes.toStoreSettings,
      matchSegment: 'settings',
    ),
  ];

  // Torn-off label getters. Written as top-level functions so the destination
  // list can stay const while still resolving through AppLocalizations.
  static String _labelDashboard(AppLocalizations l) => l.navDashboard;
  static String _labelInventory(AppLocalizations l) => l.navInventory;
  static String _labelMovements(AppLocalizations l) => l.navStockMovement;
  static String _labelSuppliers(AppLocalizations l) => l.navSuppliers;
  static String _labelCatalog(AppLocalizations l) => l.navCatalog;
  static String _labelAlerts(AppLocalizations l) => l.navAlerts;
  static String _labelReports(AppLocalizations l) => l.navReports;
  static String _labelTeam(AppLocalizations l) => l.navTeam;
  static String _labelSettings(AppLocalizations l) => l.navSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).uri.path;
    final extended = !context.isRailCollapsed;

    // The SizedBox is load-bearing. `minExtendedWidth` is only a *minimum*:
    // left to itself the rail grows to fit its longest label, and the French
    // labels ("Mouvements de stock", "Catégories et unités") pushed it to 380px
    // — 148px stolen from the content area, which then overflowed the top bar.
    //
    // Pinning the width makes the layout independent of how long the labels
    // happen to be, which also means adding Dutch later cannot silently resize
    // the whole app.
    return SizedBox(
      width: extended
          ? AppSizing.railWidthExpanded
          : AppSizing.railWidthCollapsed,
      child: NavigationRail(
        extended: extended,
        selectedIndex: _selectedIndex(location),
        onDestinationSelected: (index) {
          context.go(_destinations[index].pathBuilder(storeId));
        },
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Icon(
            LucideIcons.chefHat,
            color: AppColors.white,
            size: extended ? AppSizing.iconLg : AppSizing.iconMd,
          ),
        ),
        destinations: [
          for (final destination in _destinations)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              // Ellipsis rather than wrap: a two-line rail entry would break
              // the vertical rhythm and make the list harder to scan.
              label: Text(
                destination.label(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            ),
        ],
      ),
    );
  }

  /// Falls back to the dashboard rather than to -1, so an unrecognised path
  /// leaves the rail in a sane state instead of with nothing highlighted.
  int _selectedIndex(String location) {
    for (var i = 0; i < _destinations.length; i++) {
      if (location.contains('/${_destinations[i].matchSegment}')) return i;
    }
    return 0;
  }
}
