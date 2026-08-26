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
/// Exactly one of [pathBuilder] or [children] is set. Most destinations
/// navigate directly; "Employés" instead expands in place to reveal its
/// [children] — see [_EmployeesParentLabel].
class _Destination {
  const _Destination({
    required this.icon,
    required this.label,
    required this.matchSegment,
    this.pathBuilder,
    this.children,
  }) : assert(
         (pathBuilder == null) != (children == null),
         'a destination navigates directly or expands into children, not both',
       );

  final IconData icon;
  final String Function(AppLocalizations l10n) label;

  /// The path segment that marks this section as active. A detail screen deep
  /// inside a section keeps its rail entry highlighted, which is what stops the
  /// user losing their place after three taps.
  final String matchSegment;

  final String Function(String storeId)? pathBuilder;

  /// Set only on a destination that expands into sub-destinations instead of
  /// navigating directly — see assumption 4 in the employees brief: growing
  /// the rail by a full row per sub-page risks the regression
  /// `router_test.dart` already caught once on a small tablet, so the rail's
  /// *base* destination count stays fixed at 10 and only grows, in place,
  /// while this one entry is expanded. On a collapsed (icon-only) rail there
  /// is no room for an indented sub-row, so this entry falls back to the
  /// popup [_AppSidebarState._showFlyout] instead.
  final List<_ChildDestination>? children;
}

/// One sub-destination revealed under an expanded parent, e.g. Personnel or
/// Pointage under Employés.
class _ChildDestination {
  const _ChildDestination({
    required this.label,
    required this.pathBuilder,
    required this.icon,
    required this.isActive,
  });

  final String Function(AppLocalizations l10n) label;
  final String Function(String storeId) pathBuilder;
  final IconData icon;

  /// Whether this specific child — as opposed to a sibling, or the parent's
  /// own broader [_Destination.matchSegment] — is the one the current
  /// location is on. Purely cosmetic (bold/teal text): the rail's own
  /// `selectedIndex` always resolves to the parent, matching how every other
  /// nested screen highlights its section rather than a sub-item.
  final bool Function(String location) isActive;
}

/// The persistent navigation rail.
///
/// A rail rather than bottom navigation: this is a tablet, and the brief calls
/// for it explicitly. It collapses to icons only below
/// [AppBreakpoints.railCollapse] so a 7" tablet, or a 10" held in portrait,
/// keeps enough width for the content area.
class AppSidebar extends StatefulWidget {
  const AppSidebar({required this.storeId, super.key});

  final String storeId;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  /// Whether the Employés entry is expanded, showing its children in place.
  /// A location already inside the employees family forces this open (below)
  /// regardless of this flag — you cannot hide the section you are standing
  /// in — but the section can still be opened manually while elsewhere.
  bool _employeesExpanded = false;

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
      children: [
        _ChildDestination(
          label: _labelPersonnel,
          pathBuilder: Routes.toEmployees,
          icon: LucideIcons.idCard,
          isActive: _isPersonnelActive,
        ),
        _ChildDestination(
          label: _labelTimeclockBoard,
          pathBuilder: Routes.toTimeclock,
          icon: LucideIcons.clock,
          isActive: _isTimeclockBoardActive,
        ),
        _ChildDestination(
          label: _labelTimeclockHistory,
          pathBuilder: Routes.toTimeclockHistory,
          icon: LucideIcons.history,
          isActive: _isTimeclockHistoryActive,
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

  /// One anchor per base destination, so the collapsed-rail popup can be
  /// positioned against the rail item that opened it. Static and matched 1:1
  /// with [_destinations]: the rail persists for the life of the shell, so
  /// these never need to be recreated per build.
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
  static String _labelTimeclockBoard(AppLocalizations l) =>
      l.employeesFlyoutTimeclockBoard;
  static String _labelTimeclockHistory(AppLocalizations l) =>
      l.employeesFlyoutTimeclockHistory;
  static String _labelSettings(AppLocalizations l) => l.navSettings;

  // Historique carries its own path segment ('/timeclock-history'), which —
  // being a longer string — also contains '/timeclock'. So history is
  // checked first; the board is '/timeclock' minus that; Personnel is
  // everything else under '/employees' — the list, the detail screen,
  // add/edit.
  static bool _isTimeclockHistoryActive(String location) =>
      location.contains('/timeclock-history');
  static bool _isTimeclockBoardActive(String location) =>
      location.contains('/timeclock') &&
      !location.contains('/timeclock-history');
  static bool _isPersonnelActive(String location) =>
      location.contains('/employees') && !location.contains('/timeclock');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).uri.path;
    final extended = !context.isRailCollapsed;

    final railDestinations = <NavigationRailDestination>[];
    final railActions = <VoidCallback>[];
    int? selectedIndex;

    for (var baseIndex = 0; baseIndex < _destinations.length; baseIndex++) {
      final destination = _destinations[baseIndex];
      final children = destination.children;
      final isOnFamily = location.contains('/${destination.matchSegment}');
      if (isOnFamily) selectedIndex ??= railDestinations.length;

      if (children == null) {
        railDestinations.add(
          NavigationRailDestination(
            icon: KeyedSubtree(
              key: _destinationKeys[baseIndex],
              child: Icon(destination.icon),
            ),
            // Ellipsis rather than wrap: a two-line rail entry would break
            // the vertical rhythm and make the list harder to scan.
            label: Text(
              destination.label(l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          ),
        );
        railActions.add(
          () => context.goSection(destination.pathBuilder!(widget.storeId)),
        );
        continue;
      }

      // Employés. Collapsed rail: same popup flyout as before — there is no
      // room to draw an indented sub-row when only icons show. Extended
      // rail: an in-place accordion, per the concept the user asked for.
      final expanded = extended && (_employeesExpanded || isOnFamily);

      railDestinations.add(
        NavigationRailDestination(
          icon: KeyedSubtree(
            key: _destinationKeys[baseIndex],
            child: Icon(destination.icon),
          ),
          label: extended
              ? _EmployeesParentLabel(
                  label: destination.label(l10n),
                  isActive: isOnFamily,
                  isExpanded: expanded,
                )
              : Text(
                  destination.label(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        ),
      );
      railActions.add(() {
        if (!extended) {
          _showFlyout(context, baseIndex, children);
        } else {
          setState(() => _employeesExpanded = !expanded);
        }
      });

      if (expanded) {
        for (var i = 0; i < children.length; i++) {
          final child = children[i];
          railDestinations.add(
            NavigationRailDestination(
              icon: const SizedBox.shrink(),
              label: _EmployeesChildLabel(
                icon: child.icon,
                label: child.label(l10n),
                isActive: child.isActive(location),
                isLast: i == children.length - 1,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            ),
          );
          railActions.add(
            () => context.goSection(child.pathBuilder(widget.storeId)),
          );
        }
      }
    }

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
        // Ten-plus destinations at 48dp plus the header no longer fit the
        // 600dp height of a small tablet in landscape — and the Employés
        // accordion can add two more while expanded. Scrolling is the honest
        // fix: shrinking the entries to make them fit would put the rail
        // under the touch-target floor, and dropping one would hide a section.
        scrollable: true,
        extended: extended,
        selectedIndex: selectedIndex ?? 0,
        onDestinationSelected: (index) => railActions[index](),
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Icon(
            LucideIcons.chefHat,
            color: AppColors.white,
            size: extended ? AppSizing.iconLg : AppSizing.iconMd,
          ),
        ),
        destinations: railDestinations,
      ),
    );
  }

  /// Opens a small popup anchored to the rail item at [index], offering its
  /// [items] — the collapsed-rail fallback for the Employés entry (assumption
  /// 4 in the employees brief): there is no room to draw an indented sub-row
  /// when the rail shows icons only.
  Future<void> _showFlyout(
    BuildContext context,
    int index,
    List<_ChildDestination> items,
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
            value: item.pathBuilder(widget.storeId),
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

/// The "Employés" row on an extended rail: icon (drawn by the framework, in
/// its usual column), then this — the label plus a chevron that rotates as
/// the section opens, both sitting on a rounded highlight while expanded.
class _EmployeesParentLabel extends StatelessWidget {
  const _EmployeesParentLabel({
    required this.label,
    required this.isActive,
    required this.isExpanded,
  });

  final String label;
  final bool isActive;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final foreground = isActive ? AppColors.white : AppColors.neutral300;

    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.fast),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isExpanded ? AppColors.steel700 : Colors.transparent,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AnimatedRotation(
            duration: AppMotion.duration(context, AppMotion.fast),
            turns: isExpanded ? 0.5 : 0,
            child: Icon(
              LucideIcons.chevronDown,
              size: AppSizing.iconSm,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// One child row under the expanded Employés entry — Personnel or Pointage.
/// Draws its own tree connector rather than relying on the parent to draw one
/// continuous line, so each row stays correct on its own regardless of what
/// the rail lays out around it. See [_TreeBranchPainter].
class _EmployeesChildLabel extends StatelessWidget {
  const _EmployeesChildLabel({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isLast,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isLast;

  static const double _rowHeight = AppSizing.minTapTarget;
  static const double _connectorWidth = 22;

  @override
  Widget build(BuildContext context) {
    final foreground = isActive ? AppColors.white : AppColors.neutral300;

    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: _connectorWidth,
            height: _rowHeight,
            child: CustomPaint(
              painter: _TreeBranchPainter(
                isLast: isLast,
                color: AppColors.steel500,
              ),
            ),
          ),
          Icon(icon, size: AppSizing.iconMd, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws one segment of the tree connecting Employés to its children — a
/// trunk that runs the full row height with a branch stub into the icon, or,
/// for the last child, a trunk that stops and curves into the icon instead of
/// continuing past it. Two of these stacked (non-last, then last) read as one
/// continuous line with a rounded elbow at the bottom, the concept the user
/// asked for.
class _TreeBranchPainter extends CustomPainter {
  const _TreeBranchPainter({required this.isLast, required this.color});

  final bool isLast;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final trunkX = size.width * 0.4;
    final midY = size.height / 2;
    const cornerRadius = 6.0;

    if (isLast) {
      canvas.drawLine(
        Offset(trunkX, 0),
        Offset(trunkX, midY - cornerRadius),
        paint,
      );
      final elbow = Path()
        ..moveTo(trunkX, midY - cornerRadius)
        ..quadraticBezierTo(trunkX, midY, trunkX + cornerRadius, midY)
        ..lineTo(size.width, midY);
      canvas.drawPath(elbow, paint);
    } else {
      canvas.drawLine(Offset(trunkX, 0), Offset(trunkX, size.height), paint);
      canvas.drawLine(Offset(trunkX, midY), Offset(size.width, midY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) =>
      oldDelegate.isLast != isLast || oldDelegate.color != color;
}
