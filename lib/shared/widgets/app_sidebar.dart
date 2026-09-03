import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/navigation.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/employee_status.dart';
import '../../core/utils/permissions.dart';
import '../../core/utils/responsive.dart';
import '../../data/current_employee.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'employee_avatar.dart';
import 'employee_role_badge.dart';

/// The persistent navigation sidebar — the app's only chrome now that there is
/// no top bar.
///
/// 280dp on a 10" tablet in landscape: wide enough that no French destination
/// label is ever truncated (the rebuild brief). It carries, top to bottom, the
/// logo with the search and notification shortcuts, the store selector, the
/// navigation itself, and the signed-in user's menu.
///
/// Below [AppBreakpoints.sidebarCollapse] it drops to an 88dp icon strip — a
/// 7" tablet, a 10" in portrait, or a narrow landscape tablet. The Gestion
/// Employée accordion cannot draw an indented sub-row there, so it falls back
/// to a popup.
class AppSidebar extends ConsumerStatefulWidget {
  const AppSidebar({required this.store, super.key});

  final Store store;

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  /// Whether the Gestion Employée entry is expanded in place. A location already
  /// inside the family forces it open — you cannot fold away the section you are
  /// standing in — but it can still be opened manually from elsewhere.
  bool _employeesExpanded = false;

  String get _storeId => widget.store.id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final collapsed = context.isSidebarCollapsed;
    final location = GoRouterState.of(context).uri.path;
    final role = ref.watch(currentEmployeeProvider)?.role ?? EmployeeRole.staff;

    return Container(
      width: collapsed
          ? AppSizing.sidebarWidthCollapsed
          : AppSizing.sidebarWidthExpanded,
      decoration: const BoxDecoration(
        color: AppColors.steel800,
        border: Border(right: BorderSide(color: AppColors.steel700)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarHeader(storeId: _storeId, collapsed: collapsed),
          const _SidebarDivider(),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? AppSpacing.sm : AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: _StoreSelector(store: widget.store, collapsed: collapsed),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? AppSpacing.sm : AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: _NavList(
                storeId: _storeId,
                collapsed: collapsed,
                location: location,
                role: role,
                employeesExpanded: _employeesExpanded,
                onToggleEmployees: () =>
                    setState(() => _employeesExpanded = !_employeesExpanded),
              ),
            ),
          ),
          const _SidebarDivider(),
          _SidebarProfile(
            storeId: _storeId,
            collapsed: collapsed,
            l10n: l10n,
          ),
        ],
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.steel700);
}

// -----------------------------------------------------------------------------
// Header — logo, and the search / notification shortcuts.
// -----------------------------------------------------------------------------

class _SidebarHeader extends ConsumerWidget {
  const _SidebarHeader({required this.storeId, required this.collapsed});

  final String storeId;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unread = ref.watch(unreadCountProvider(storeId)).value ?? 0;

    final logo = Icon(
      LucideIcons.chefHat,
      color: AppColors.white,
      size: collapsed ? AppSizing.iconMd : AppSizing.iconLg,
    );

    final search = _HeaderIconButton(
      icon: LucideIcons.search,
      tooltip: l10n.actionSearch,
      onPressed: () => context.pushScreen(Routes.toSearch(storeId)),
    );

    final notifications = _HeaderIconButton(
      icon: LucideIcons.bell,
      tooltip: l10n.topBarNotifications,
      badgeCount: unread,
      onPressed: () => context.goSection(Routes.toNotifications(storeId)),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            logo,
            const SizedBox(height: AppSpacing.sm),
            search,
            notifications,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          logo,
          const Spacer(),
          search,
          notifications,
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon, size: AppSizing.iconMd),
          color: AppColors.neutral300,
          hoverColor: AppColors.steel700,
        ),
        if (badgeCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: AppColors.steel800, width: 1.5),
              ),
              child: Text(
                '$badgeCount',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Store selector.
// -----------------------------------------------------------------------------

/// The store selector, in the sidebar's steel chrome.
///
/// Only the owner spans stores, so only the owner gets a menu — a manager or
/// staff member sees their store's name and nothing to tap.
class _StoreSelector extends ConsumerWidget {
  const _StoreSelector({required this.store, required this.collapsed});

  final Store store;
  final bool collapsed;

  static const String _allStoresValue = '__all__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final employee = ref.watch(currentEmployeeProvider);
    final canSwitch =
        employee != null && can(employee.role, Capability.spanAllStores);

    final face = Container(
      height: AppSizing.minTapTarget,
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 0 : AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.steel700,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.store,
            size: AppSizing.iconMd,
            color: AppColors.neutral300,
          ),
          if (!collapsed) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                store.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (canSwitch)
              const Icon(
                LucideIcons.chevronsUpDown,
                size: AppSizing.iconSm,
                color: AppColors.neutral300,
              ),
          ],
        ],
      ),
    );

    if (!canSwitch) {
      return collapsed ? Tooltip(message: store.name, child: face) : face;
    }

    final stores = ref.watch(storesProvider).value ?? [store];

    return PopupMenuButton<String>(
      tooltip: l10n.storeSwitcherChange,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (value) {
        if (value == _allStoresValue) {
          context.goSection(Routes.stores);
        } else {
          context.goSection(Routes.toDashboard(value));
        }
      },
      itemBuilder: (context) => [
        for (final s in stores)
          PopupMenuItem<String>(
            value: s.id,
            child: Row(
              children: [
                Icon(
                  s.id == store.id
                      ? LucideIcons.circleCheck
                      : LucideIcons.store,
                  size: AppSizing.iconMd,
                  color: s.id == store.id
                      ? AppColors.primary600
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.name, style: theme.textTheme.bodyLarge),
                    Text(s.city, style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: _allStoresValue,
          child: Row(
            children: [
              const Icon(LucideIcons.layoutGrid, size: AppSizing.iconMd),
              const SizedBox(width: AppSpacing.md),
              Text(l10n.storeSwitcherChange),
            ],
          ),
        ),
      ],
      child: collapsed ? Tooltip(message: store.name, child: face) : face,
    );
  }
}

// -----------------------------------------------------------------------------
// Navigation.
// -----------------------------------------------------------------------------

/// One navigable destination. Exactly one of [pathBuilder] or [children] is set.
class _Destination {
  const _Destination({
    required this.icon,
    required this.label,
    required this.matchSegment,
    this.pathBuilder,
    this.children,
  });

  final IconData icon;
  final String Function(AppLocalizations l10n) label;

  /// The path segment that keeps this entry highlighted for every screen inside
  /// the section, detail pages included.
  final String matchSegment;

  final String Function(String storeId)? pathBuilder;

  /// Set only on Gestion Employée — the one entry that expands rather than
  /// navigating.
  final List<_ChildDestination>? children;
}

/// One sub-destination under the Gestion Employée accordion.
class _ChildDestination {
  const _ChildDestination({
    required this.label,
    required this.pathBuilder,
    required this.icon,
    required this.isActive,
    required this.capability,
  });

  final String Function(AppLocalizations l10n) label;
  final String Function(String storeId) pathBuilder;
  final IconData icon;
  final Capability capability;
  final bool Function(String location) isActive;
}

bool _isTimeclockActive(String location) =>
    location.contains('/employees/timeclock');
bool _isAttendanceHistoryActive(String location) =>
    location.contains('/employees/attendance-history');
bool _isPayrollActive(String location) =>
    location.contains('/employees/payroll');
bool _isPersonnelActive(String location) =>
    location.contains('/employees') &&
    !_isTimeclockActive(location) &&
    !_isAttendanceHistoryActive(location) &&
    !_isPayrollActive(location);

const List<_Destination> _destinations = [
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
    icon: LucideIcons.idCard,
    label: _labelEmployees,
    matchSegment: 'employees',
    children: [
      _ChildDestination(
        label: _labelPersonnel,
        pathBuilder: Routes.toEmployees,
        icon: LucideIcons.idCard,
        isActive: _isPersonnelActive,
        capability: Capability.manageEmployees,
      ),
      _ChildDestination(
        label: _labelTimeclock,
        pathBuilder: Routes.toTimeclock,
        icon: LucideIcons.clock,
        isActive: _isTimeclockActive,
        capability: Capability.viewTimeclock,
      ),
      _ChildDestination(
        label: _labelAttendanceHistory,
        pathBuilder: Routes.toAttendanceHistory,
        icon: LucideIcons.history,
        isActive: _isAttendanceHistoryActive,
        capability: Capability.viewAttendanceHistory,
      ),
      _ChildDestination(
        label: _labelPayroll,
        pathBuilder: Routes.toPayroll,
        icon: LucideIcons.banknote,
        isActive: _isPayrollActive,
        capability: Capability.managePayroll,
      ),
    ],
  ),
  // "Paramètres" is not a rail destination — it lives in the user menu at the
  // bottom of the sidebar, alongside "Mes établissements" and "Se déconnecter".
];

String _labelDashboard(AppLocalizations l) => l.navDashboard;
String _labelInventory(AppLocalizations l) => l.navInventory;
String _labelMovements(AppLocalizations l) => l.navStockMovement;
String _labelOrders(AppLocalizations l) => l.navOrders;
String _labelSuppliers(AppLocalizations l) => l.navSuppliers;
String _labelCatalog(AppLocalizations l) => l.navCatalog;
String _labelAlerts(AppLocalizations l) => l.navAlerts;
String _labelReports(AppLocalizations l) => l.navReports;
String _labelEmployees(AppLocalizations l) => l.navEmployees;
String _labelPersonnel(AppLocalizations l) => l.employeesNavPersonnel;
String _labelTimeclock(AppLocalizations l) => l.employeesNavTimeclock;
String _labelAttendanceHistory(AppLocalizations l) =>
    l.employeesNavAttendanceHistory;
String _labelPayroll(AppLocalizations l) => l.employeesNavPayroll;

class _NavList extends StatelessWidget {
  const _NavList({
    required this.storeId,
    required this.collapsed,
    required this.location,
    required this.role,
    required this.employeesExpanded,
    required this.onToggleEmployees,
  });

  final String storeId;
  final bool collapsed;
  final String location;
  final EmployeeRole role;
  final bool employeesExpanded;
  final VoidCallback onToggleEmployees;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tiles = <Widget>[];

    for (final destination in _destinations) {
      if (destination.children == null) {
        final active = location.contains('/${destination.matchSegment}');
        tiles.add(
          SidebarNavTile(
            icon: destination.icon,
            label: destination.label(l10n),
            active: active,
            collapsed: collapsed,
            onTap: () =>
                context.goSection(destination.pathBuilder!(storeId)),
          ),
        );
        continue;
      }

      // Gestion Employée — an accordion, filtered to the children this role can
      // reach, and hidden entirely when that leaves none.
      final children = destination.children!
          .where((child) => can(role, child.capability))
          .toList();
      if (children.isEmpty) continue;

      final onFamily = location.contains('/${destination.matchSegment}');
      final expanded = !collapsed && (employeesExpanded || onFamily);

      tiles.add(
        SidebarNavTile(
          icon: destination.icon,
          label: destination.label(l10n),
          active: onFamily,
          collapsed: collapsed,
          onTap: collapsed
              ? () => _showFlyout(context, children)
              : onToggleEmployees,
          trailing: collapsed
              ? null
              : AnimatedRotation(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  turns: expanded ? 0.5 : 0,
                  child: const Icon(
                    LucideIcons.chevronDown,
                    size: AppSizing.iconSm,
                  ),
                ),
        ),
      );

      if (expanded) {
        for (var i = 0; i < children.length; i++) {
          final child = children[i];
          tiles.add(
            _ChildNavTile(
              icon: child.icon,
              label: child.label(l10n),
              active: child.isActive(location),
              isLast: i == children.length - 1,
              onTap: () => context.goSection(child.pathBuilder(storeId)),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tile in tiles) ...[
          tile,
          const SizedBox(height: AppSpacing.xxs),
        ],
      ],
    );
  }

  Future<void> _showFlyout(
    BuildContext context,
    List<_ChildDestination> items,
  ) async {
    final l10n = AppLocalizations.of(context);
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
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

    if (selected != null && context.mounted) context.goSection(selected);
  }
}

/// One navigation row in the sidebar — icon, label, and a teal highlight when
/// it is the section the user is in. Reused for every destination; the Gestion
/// Employée row passes a [trailing] chevron.
///
/// Public so the navigation suite can read which row is [active].
class SidebarNavTile extends StatelessWidget {
  const SidebarNavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppColors.white : AppColors.neutral300;

    final row = Row(
      mainAxisAlignment: collapsed
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizing.iconMd, color: foreground),
        if (!collapsed) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null)
            IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: trailing!,
            ),
        ],
      ],
    );

    final tile = Material(
      color: active ? AppColors.primary600 : Colors.transparent,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        hoverColor: AppColors.steel700,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: row,
        ),
      ),
    );

    // Only the icon shows when collapsed, so the label becomes a tooltip.
    return collapsed ? Tooltip(message: label, child: tile) : tile;
  }
}

/// A child row under the expanded Gestion Employée entry, with its own tree
/// connector so each row is correct on its own.
class _ChildNavTile extends StatelessWidget {
  const _ChildNavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.isLast,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool isLast;
  final VoidCallback onTap;

  static const double _connectorWidth = 22;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppColors.white : AppColors.neutral300;

    return Material(
      color: active ? AppColors.primary600 : Colors.transparent,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        hoverColor: AppColors.steel700,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: _connectorWidth,
                height: AppSizing.minTapTarget,
                child: CustomPaint(
                  painter: _TreeBranchPainter(
                    isLast: isLast,
                    color: AppColors.steel500,
                  ),
                ),
              ),
              Icon(icon, size: AppSizing.iconMd, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws one segment of the tree connecting the parent to its children — a
/// trunk with a branch stub, or, for the last child, a trunk that curves into
/// the icon. Stacked, they read as one continuous line.
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

// -----------------------------------------------------------------------------
// User profile.
// -----------------------------------------------------------------------------

class _SidebarProfile extends ConsumerWidget {
  const _SidebarProfile({
    required this.storeId,
    required this.collapsed,
    required this.l10n,
  });

  final String storeId;
  final bool collapsed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentEmployeeProvider);

    Future<void> onSelected(String value) async {
      switch (value) {
        case 'stores':
          context.goSection(Routes.stores);
        case 'settings':
          context.goSection(Routes.toStoreSettings(storeId));
        case 'logout':
          await ref.read(currentEmployeeProvider.notifier).signOut();
          if (context.mounted) context.goSection(Routes.login);
      }
    }

    final menuItems = <PopupMenuEntry<String>>[
      if (user != null) ...[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                employeeDisplayName(user),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.white,
                ),
              ),
              Text(
                user.email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.neutral400,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(color: AppColors.steel700),
      ],
      PopupMenuItem<String>(
        value: 'stores',
        child: _MenuRow(
          icon: LucideIcons.building2,
          label: l10n.sidebarMyStores,
        ),
      ),
      PopupMenuItem<String>(
        value: 'settings',
        child: _MenuRow(icon: LucideIcons.settings, label: l10n.navSettings),
      ),
      PopupMenuItem<String>(
        value: 'logout',
        child: _MenuRow(icon: LucideIcons.logOut, label: l10n.actionLogout),
      ),
    ];

    final avatar = user == null
        ? const _InitialsAvatar(initials: '')
        : EmployeeAvatar(employee: user, size: 32);

    return PopupMenuButton<String>(
      tooltip: l10n.topBarAccount,
      // Anchored at the tap, not `under`: this sits at the bottom of the
      // sidebar, so the menu has to open upward and Flutter places `over`
      // within the screen for us. Same steel ground and 280dp width as the
      // sidebar, so the menu reads as an extension of it.
      color: AppColors.steel800,
      constraints: const BoxConstraints.tightFor(
        width: AppSizing.sidebarWidthExpanded,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: onSelected,
      itemBuilder: (context) => menuItems,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? AppSpacing.sm : AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            avatar,
            if (!collapsed) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user == null ? '—' : employeeDisplayName(user),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    if (user != null)
                      Text(
                        employeeRoleLabel(l10n, user.role),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronsUpDown,
                size: AppSizing.iconSm,
                color: AppColors.neutral300,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One row of the user menu — light on the steel ground it shares with the
/// sidebar.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: AppSizing.iconMd, color: AppColors.neutral300),
      const SizedBox(width: AppSpacing.md),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.neutral100),
      ),
    ],
  );
}

/// The disc with initials, for the frame before the current user resolves —
/// mirrors [EmployeeAvatar]'s empty state so the sidebar geometry is fixed from
/// the first frame.
class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.steel600,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.white,
        ),
      ),
    );
  }
}
