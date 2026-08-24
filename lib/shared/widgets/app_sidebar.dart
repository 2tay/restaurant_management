import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/navigation.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';

/// One entry in the navigation rail.
///
/// Exactly one of [pathBuilder] or [flyout] is set. Most destinations
/// navigate directly; the ones with a [flyout] open a small popup instead —
/// see the "Employés" entry below.
class _Destination {
  const _Destination({
    required this.icon,
    required this.label,
    required this.matchSegment,
    this.pathBuilder,
    this.flyout,
  }) : assert(
         (pathBuilder == null) != (flyout == null),
         'a destination navigates directly or opens a flyout, not both',
       );

  final IconData icon;
  final String Function(AppLocalizations l10n) label;

  /// The path segment that marks this section as active. A detail screen deep
  /// inside a section keeps its rail entry highlighted, which is what stops the
  /// user losing their place after three taps.
  final String matchSegment;

  final String Function(String storeId)? pathBuilder;

  /// Set only on a destination that opens a popup instead of navigating
  /// directly — see assumption 4 in the employees brief: growing the rail by
  /// a full row per sub-page risks the same regression `router_test.dart`
  /// already caught once on a small tablet, so a flyout keeps the rail's
  /// destination count fixed.
  final List<_FlyoutItem>? flyout;
}

/// One item inside a destination's flyout popup.
class _FlyoutItem {
  const _FlyoutItem({
    required this.label,
    required this.pathBuilder,
    required this.icon,
  });

  final String Function(AppLocalizations l10n) label;
  final String Function(String storeId) pathBuilder;
  final IconData icon;
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
      icon: LucideIcons.clipboardList,
      label: _labelOrders,
      pathBuilder: Routes.toOrders,
      matchSegment: 'orders',
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
      icon: LucideIcons.idCard,
      label: _labelEmployees,
      matchSegment: 'employees',
      flyout: [
        _FlyoutItem(
          label: _labelPersonnel,
          pathBuilder: Routes.toEmployees,
          icon: LucideIcons.idCard,
        ),
        _FlyoutItem(
          label: _labelPointage,
          pathBuilder: Routes.toTimeclock,
          icon: LucideIcons.clock,
        ),
      ],
    ),
    _Destination(
      icon: LucideIcons.settings,
      label: _labelSettings,
      pathBuilder: Routes.toStoreSettings,
      matchSegment: 'settings',
    ),
  ];

  /// One anchor per destination, so a flyout can be positioned against the
  /// rail item that opened it. Static and matched 1:1 with [_destinations]:
  /// the rail persists for the life of the shell, so these never need to be
  /// recreated per build.
  static final List<GlobalKey> _destinationKeys = List.generate(
    _destinations.length,
    (_) => GlobalKey(),
  );

  // Torn-off label getters. Written as top-level functions so the destination
  // list can stay const while still resolving through AppLocalizations.
  static String _labelDashboard(AppLocalizations l) => l.navDashboard;
  static String _labelInventory(AppLocalizations l) => l.navInventory;
  static String _labelMovements(AppLocalizations l) => l.navStockMovement;
  static String _labelOrders(AppLocalizations l) => l.navOrders;
  static String _labelSuppliers(AppLocalizations l) => l.navSuppliers;
  static String _labelCatalog(AppLocalizations l) => l.navCatalog;
  static String _labelAlerts(AppLocalizations l) => l.navAlerts;
  static String _labelReports(AppLocalizations l) => l.navReports;
  static String _labelTeam(AppLocalizations l) => l.navTeam;
  static String _labelEmployees(AppLocalizations l) => l.navEmployees;
  static String _labelPersonnel(AppLocalizations l) =>
      l.employeesFlyoutPersonnel;
  static String _labelPointage(AppLocalizations l) => l.employeesFlyoutPointage;
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
        // Ten destinations at 48dp plus the header no longer fit the 600dp
        // height of a small tablet in landscape. Scrolling is the honest fix:
        // shrinking the entries to make them fit would put the rail under the
        // touch-target floor, and dropping one would hide a section.
        scrollable: true,
        extended: extended,
        selectedIndex: _selectedIndex(location),
        onDestinationSelected: (index) {
          final destination = _destinations[index];
          final flyout = destination.flyout;
          if (flyout != null) {
            _showFlyout(context, index, flyout);
          } else {
            context.goSection(destination.pathBuilder!(storeId));
          }
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
          for (var i = 0; i < _destinations.length; i++)
            NavigationRailDestination(
              // Keyed so a flyout destination can find its own on-screen
              // position when it opens its popup — see [_showFlyout].
              icon: KeyedSubtree(
                key: _destinationKeys[i],
                child: Icon(_destinations[i].icon),
              ),
              // Ellipsis rather than wrap: a two-line rail entry would break
              // the vertical rhythm and make the list harder to scan.
              label: Text(
                _destinations[i].label(l10n),
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

  /// Opens a small popup anchored to the rail item at [index], offering its
  /// [items] — the mechanism assumption 4 in the employees brief calls for:
  /// one rail entry that fans out into a couple of destinations instead of
  /// the rail growing a row per sub-page.
  Future<void> _showFlyout(
    BuildContext context,
    int index,
    List<_FlyoutItem> items,
  ) async {
    final l10n = AppLocalizations.of(context);
    final anchor =
        _destinationKeys[index].currentContext?.findRenderObject()
            as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (anchor == null || overlay == null) return;

    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final item in items)
          PopupMenuItem<String>(
            value: item.pathBuilder(storeId),
            child: Row(
              children: [
                Icon(item.icon, size: AppSizing.iconMd),
                const SizedBox(width: AppSpacing.sm),
                Text(item.label(l10n)),
              ],
            ),
          ),
      ],
    );

    if (selected != null && context.mounted) {
      context.goSection(selected);
    }
  }
}
