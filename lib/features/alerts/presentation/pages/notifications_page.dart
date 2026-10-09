import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../inventory/presentation/widgets/product_drawer.dart';
import '../alerts_filter.dart';

/// Which kinds the feed is narrowed to.
///
/// Coarser than [NotificationKind] on purpose: low stock and rupture are the
/// same worry at two severities, and nobody looking for one wants the other
/// hidden.
enum NotificationFilter {
  all,
  stock,
  price,
  adjustment,
  delivery,
  pointage,
  personnel,
}

/// The notification centre.
///
/// Low stock, price changes, large adjustments and deliveries in one feed,
/// because they are the things that happen without anyone doing them. Since the
/// engine landed these are real events rather than a seeded list, so the feed
/// grows and has to stay legible as it does: entries are grouped under the day
/// they happened, and narrowed by kind.
///
/// Unread entries carry a filled left edge and a heavier title — a bold font
/// alone is too subtle at arm's length.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _unreadOnly = false;
  NotificationFilter _kind = NotificationFilter.all;
  bool _newestFirst = true;

  /// Days folded away by their header's chevron. Kept by date rather than by
  /// position, so a new notification arriving does not fold a different day.
  final Set<DateTime> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Marking one read is a write, and this list is watching the table it
    // writes to — so the badge on the bell and the row on screen change in the
    // same frame.
    final asyncAll = ref.watch(notificationsProvider(widget.storeId));
    final all = asyncAll.value ?? const <NotificationItem>[];
    final unreadCount = all.where((n) => !n.isRead).length;

    // The feed arrives newest first; the other order is the same list read
    // backwards.
    final filtered = all
        .where((n) => !_unreadOnly || !n.isRead)
        .where((n) => _matches(_kind, n.kind));
    final shown = _newestFirst
        ? filtered.toList()
        : filtered.toList().reversed.toList();

    return ShellPage(
      tabs: SectionTabs(
        currentPath: Routes.toNotifications(widget.storeId),
        tabs: [
          SectionTab(
            label: l10n.alertsTitle,
            path: Routes.toAlerts(widget.storeId),
          ),
          SectionTab(
            label: l10n.notificationsTitle,
            path: Routes.toNotifications(widget.storeId),
          ),
        ],
      ),
      title: l10n.notificationsTitle,
      subtitle: l10n.notificationsUnread(unreadCount),
      // Information, not description — kept on a phone.
      keepSubtitle: true,
      actions: [
        if (unreadCount > 0)
          SecondaryButton(
            label: l10n.notificationsMarkAllRead,
            shortLabel: l10n.shortMarkAllRead,
            icon: LucideIcons.checkCheck,
            onPressed: _markAllRead,
          ),
        _IconAction(
          icon: LucideIcons.slidersHorizontal,
          tooltip: l10n.notificationsPreferences,
          onPressed: () =>
              context.goSection(Routes.toNotificationSettings(widget.storeId)),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            all: all,
            kind: _kind,
            unreadOnly: _unreadOnly,
            newestFirst: _newestFirst,
            onKind: (value) => setState(() => _kind = value),
            onUnreadOnly: (value) => setState(() => _unreadOnly = value),
            onNewestFirst: (value) => setState(() => _newestFirst = value),
          ),
          SizedBox(height: context.isPhone ? AppSpacing.md : AppSpacing.lg),
          // Part of the page: the whole page scrolls, title included.
          Builder(
            builder: (context) => AsyncContent<List<NotificationItem>>(
              value: asyncAll,
              onRetry: () =>
                  ref.invalidate(notificationsProvider(widget.storeId)),
              // Only once the query has answered. Drawing "aucune notification"
              // over a list that is still arriving says something untrue, and
              // says it in the one place on the screen a user would trust.
              builder: (context, _) => _body(all, shown),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(List<NotificationItem> all, List<NotificationItem> shown) {
    final l10n = AppLocalizations.of(context);

    if (shown.isEmpty) {
      // "Nothing has happened" and "nothing matches what you asked for" are
      // different situations, and offering to clear a filter that is not set
      // would be nonsense.
      final filtered = _unreadOnly || _kind != NotificationFilter.all;
      if (!filtered || all.isEmpty) {
        return EmptyState(
          icon: LucideIcons.bellOff,
          title: l10n.notificationsEmpty,
          message: l10n.notificationsEmptyBody,
        );
      }
      return EmptyState(
        icon: LucideIcons.filterX,
        title: l10n.notificationsNoneOfKind,
        message: l10n.notificationsNoneOfKindBody,
        actionLabel: l10n.inventoryClearFilters,
        onAction: () => setState(() {
          _unreadOnly = false;
          _kind = NotificationFilter.all;
        }),
      );
    }

    // Grouped by the day they happened. The feed is in date order already, so
    // one pass over it is enough — no sorting, and no map to lose the order.
    final groups =
        <({DateTime day, String label, List<NotificationItem> items})>[];
    DateTime? currentDay;
    for (final notification in shown) {
      final day = DateUtils.dateOnly(notification.createdAt);
      if (currentDay == null || day != currentDay) {
        currentDay = day;
        groups.add((day: day, label: _dayLabel(l10n, day), items: []));
      }
      groups.last.items.add(notification);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, group) in groups.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.lg),
          _DayHeader(
            label: group.label,
            // The date written out only where the label is relative: under
            // « 6 octobre 2026 » it would say the same thing twice.
            date: group.label == Formatters.dateLong(group.day)
                ? null
                : Formatters.dateLong(group.day),
            count: group.items.length,
            collapsed: _collapsed.contains(group.day),
            onToggle: () => setState(() {
              if (!_collapsed.remove(group.day)) _collapsed.add(group.day);
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!_collapsed.contains(group.day))
            ListView.separated(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: group.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final notification = group.items[i];
                return _NotificationCard(
                  notification: notification,
                  onTap: () => _open(notification),
                  onMarkRead: notification.isRead
                      ? null
                      : () => _markOneRead(notification),
                );
              },
            ),
        ],
      ],
    );
  }

  /// "Aujourd'hui", "Hier", or the date written out.
  String _dayLabel(AppLocalizations l10n, DateTime day) {
    final today = DateUtils.dateOnly(clock.now());
    final difference = today.difference(day).inDays;
    if (difference == 0) return l10n.notificationsToday;
    if (difference == 1) return l10n.notificationsYesterday;
    return Formatters.dateLong(day);
  }

  static bool _matches(NotificationFilter filter, NotificationKind kind) =>
      switch (filter) {
        NotificationFilter.all => true,
        NotificationFilter.stock =>
          kind == NotificationKind.lowStock ||
              kind == NotificationKind.outOfStock ||
              kind == NotificationKind.busyDays,
        NotificationFilter.price => kind == NotificationKind.priceChange,
        NotificationFilter.adjustment =>
          kind == NotificationKind.largeAdjustment,
        NotificationFilter.delivery => kind == NotificationKind.delivery,
        NotificationFilter.pointage =>
          kind == NotificationKind.clockIn || kind == NotificationKind.clockOut,
        NotificationFilter.personnel => kind == NotificationKind.personnel,
      };

  /// Whose "read" this page shows and writes: a signalement is read
  /// separately by a manager and by the owner.
  NotificationViewer? get _viewer => ref.read(notificationViewerProvider);

  Future<void> _markAllRead() async {
    final l10n = AppLocalizations.of(context);
    final changed = await ref
        .read(accountRepositoryProvider)
        .markAllRead(widget.storeId, viewer: _viewer);

    // Says how many rather than a bare acknowledgement, and stays quiet when
    // there was nothing to do.
    if (!mounted || changed == 0) return;
    AppSnackBar.success(context, l10n.notificationsMarkedRead(changed));
  }

  /// Clears one entry without going anywhere.
  ///
  /// Before this the only way to mark something read was to open the page it
  /// was about, which forced a navigation on somebody who just wanted the
  /// badge to stop counting something they had already dealt with.
  Future<void> _markOneRead(NotificationItem notification) async {
    final l10n = AppLocalizations.of(context);
    final changed = await ref
        .read(accountRepositoryProvider)
        .markRead(notification.id, viewer: _viewer);

    if (!mounted || !changed) return;
    AppSnackBar.success(context, l10n.notificationsMarkedOneRead);
  }

  Future<void> _open(NotificationItem notification) async {
    await ref
        .read(accountRepositoryProvider)
        .markRead(notification.id, viewer: _viewer);
    if (!mounted) return;

    // Opens whatever the notification is about, so it is actionable rather
    // than merely informative.
    //
    // A product opens as a panel over the feed, so clearing a run of
    // notifications does not mean navigating away and back for each one. A
    // supplier still navigates: there is no supplier panel, and a notification
    // that led nowhere would be worse than one that changes screen.
    if (notification.relatedItemId != null) {
      await openProductDrawer(
        context,
        storeId: widget.storeId,
        itemId: notification.relatedItemId!,
      );
    } else if (notification.relatedSupplierId != null) {
      context.pushScreen(
        Routes.toSupplier(widget.storeId, notification.relatedSupplierId!),
      );
    } else if (notification.relatedEmployeeId != null) {
      // A signalement: where it is checked — the employee's payroll for a
      // payment, their pointage history otherwise. An arrivée or a départ
      // opens that history too.
      context.goSection(
        notification.relatedTarget == 'payroll'
            ? Routes.toPayroll(
                widget.storeId,
                employeeId: notification.relatedEmployeeId,
              )
            : Routes.toAttendanceHistory(
                widget.storeId,
                employeeId: notification.relatedEmployeeId,
              ),
      );
    } else if (notification.kind == NotificationKind.busyDays) {
      // Straight to the list the reminder is about.
      ref.read(alertsFilterProvider.notifier).setSeverity(AlertSeverity.busy);
      context.goSection(Routes.toAlerts(widget.storeId));
    }
  }
}

// -----------------------------------------------------------------------------
// Header action.
// -----------------------------------------------------------------------------

/// A square outlined icon button the height of the buttons beside it.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final side = context.isPhone ? 40.0 : AppSizing.minTapTarget;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: side,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.square(side),
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
          child: Icon(icon, size: AppSizing.iconSm),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Filters.
// -----------------------------------------------------------------------------

/// One bar: the kinds as tabs on the left, the unread toggle and the order on
/// the right — a single row on a wide screen, two lines below a tablet.
///
/// Counts sit on the tabs rather than only in the list: « Prix 3 » tells you
/// whether the filter is worth applying before you apply it and find nothing.
/// A kind with nothing in it is left out, unless it is the one selected — six
/// tabs where two are ever used is a lot of bar on a phone.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.all,
    required this.kind,
    required this.unreadOnly,
    required this.newestFirst,
    required this.onKind,
    required this.onUnreadOnly,
    required this.onNewestFirst,
  });

  final List<NotificationItem> all;
  final NotificationFilter kind;
  final bool unreadOnly;
  final bool newestFirst;
  final ValueChanged<NotificationFilter> onKind;
  final ValueChanged<bool> onUnreadOnly;
  final ValueChanged<bool> onNewestFirst;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = all.where((n) => !n.isRead).length;

    int count(NotificationFilter filter) => all
        .where((n) => _NotificationsPageState._matches(filter, n.kind))
        .length;

    final tabs = <(NotificationFilter, IconData, String)>[
      (NotificationFilter.all, LucideIcons.inbox, l10n.notificationsFilterAll),
      (
        NotificationFilter.stock,
        LucideIcons.package,
        l10n.notificationsKindStock,
      ),
      (
        NotificationFilter.price,
        LucideIcons.trendingUp,
        l10n.notificationsKindPrice,
      ),
      (
        NotificationFilter.adjustment,
        LucideIcons.clipboardCheck,
        l10n.notificationsKindAdjustment,
      ),
      (
        NotificationFilter.delivery,
        LucideIcons.truck,
        l10n.notificationsKindDelivery,
      ),
      (
        NotificationFilter.pointage,
        LucideIcons.clock,
        l10n.notificationsKindPointage,
      ),
      (
        NotificationFilter.personnel,
        LucideIcons.usersRound,
        l10n.notificationsKindPersonnel,
      ),
    ];

    final kindTabs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (filter, icon, label) in tabs)
            if (filter == NotificationFilter.all ||
                filter == kind ||
                count(filter) > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _FilterTab(
                  key: ValueKey('notifications-filter-${filter.name}'),
                  icon: icon,
                  label: label,
                  count: count(filter),
                  selected: filter == kind,
                  onTap: () => onKind(filter),
                ),
              ),
        ],
      ),
    );

    final unreadToggle = _FilterTab(
      key: const ValueKey('notifications-filter-unread'),
      icon: LucideIcons.mail,
      label: l10n.notificationsFilterUnread,
      count: unread,
      selected: unreadOnly,
      outlined: true,
      onTap: () => onUnreadOnly(!unreadOnly),
    );

    final sort = _SortMenu(newestFirst: newestFirst, onChanged: onNewestFirst);

    return Container(
      padding: EdgeInsets.all(context.isPhone ? AppSpacing.xs : AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.hairline),
      ),
      child: context.isSmallScreen || context.isLargeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                kindTabs,
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Flexible(child: unreadToggle),
                    const Spacer(),
                    const SizedBox(width: AppSpacing.sm),
                    sort,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: kindTabs),
                const SizedBox(width: AppSpacing.sm),
                unreadToggle,
                const SizedBox(width: AppSpacing.sm),
                sort,
              ],
            ),
    );
  }
}

/// A tab of the filter bar: icon, name and a count badge, filled when on.
class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.outlined = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  /// A toggle rather than one of the kinds: drawn with an outline at rest so
  /// it does not read as another tab of the same row.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected ? AppColors.white : AppColors.textPrimary;
    final background = selected
        ? AppColors.primary700
        : (outlined ? AppColors.surface : AppColors.surfaceVariant);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: outlined && !selected
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizing.toolbarControlHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _CountBadge(
                      count: count,
                      background: selected
                          ? AppColors.primary500
                          : AppColors.neutral100,
                      foreground: selected
                          ? AppColors.white
                          : AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small pill with a number in it.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    this.background = AppColors.neutral100,
    this.foreground = AppColors.textSecondary,
  });

  final int count;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// « Plus récentes » / « Plus anciennes ».
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.newestFirst, required this.onChanged});

  final bool newestFirst;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = newestFirst
        ? l10n.notificationsSortNewest
        : l10n.notificationsSortOldest;
    final compact = context.isPhone;

    PopupMenuItem<bool> item(bool value, IconData icon, String text) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(
                icon,
                size: AppSizing.iconSm,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(text)),
              if (value == newestFirst)
                const Icon(
                  LucideIcons.check,
                  size: AppSizing.iconSm,
                  color: AppColors.primary600,
                ),
            ],
          ),
        );

    return PopupMenuButton<bool>(
      tooltip: l10n.notificationsSortTooltip,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: onChanged,
      itemBuilder: (context) => [
        item(
          true,
          LucideIcons.arrowDownWideNarrow,
          l10n.notificationsSortNewest,
        ),
        item(
          false,
          LucideIcons.arrowUpNarrowWide,
          l10n.notificationsSortOldest,
        ),
      ],
      child: Container(
        height: AppSizing.toolbarControlHeight,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              compact ? LucideIcons.arrowDownUp : LucideIcons.clock,
              size: 16,
              color: AppColors.textSecondary,
            ),
            // On a phone the icon alone: the menu says the rest, and the room
            // goes to the unread toggle beside it.
            if (!compact) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Day heading.
// -----------------------------------------------------------------------------

/// The day, its count, the date in full when the day is a relative one, and a
/// chevron — the whole line folds the day away.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.date,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  final String label;

  /// The date in full, when [label] is a relative one.
  final String? date;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Tooltip(
      message: collapsed
          ? l10n.notificationsExpandDay
          : l10n.notificationsCollapseDay,
      child: InkWell(
        onTap: onToggle,
        borderRadius: AppRadius.smAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _CountBadge(count: count),
              const Spacer(),
              if (date != null)
                Text(
                  date!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(
                  collapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                  size: AppSizing.iconSm,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// One entry.
// -----------------------------------------------------------------------------

enum _CardAction { open, markRead }

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
  });

  final NotificationItem notification;
  final VoidCallback onTap;

  /// Null once it has been read.
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final phone = context.isPhone;
    final isRead = notification.isRead;
    final (icon, colors, kindLabel) = _appearance(l10n, notification.kind);

    // The busy-days reminder is the one entry that asks for something ahead
    // of time, so it stands out: tinted, outlined, with its action in words.
    final featured = notification.kind == NotificationKind.busyDays;

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notification.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          notification.body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // The kind in words beside the time, so the medallion's colour is
        // never the only thing saying what this is.
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LabelChip(
              label: kindLabel,
              background: colors.container,
              foreground: colors.foreground,
              dense: true,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.clock,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    _when(notification.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final card = AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(phone ? AppSpacing.md : AppSpacing.lg),
      // The unread marker is the accent edge itself rather than a dot: the
      // same information, readable from further away.
      accentColor: isRead ? null : colors.solid,
      borderColor: featured ? colors.solid.withValues(alpha: 0.4) : null,
      child: Row(
        children: [
          _Leading(
            notification: notification,
            icon: icon,
            colors: colors,
            size: phone ? 44 : 52,
          ),
          SizedBox(width: phone ? AppSpacing.md : AppSpacing.lg),
          Expanded(child: texts),
          const SizedBox(width: AppSpacing.xs),
          if (featured && !phone) ...[
            _OpenPill(label: l10n.notificationsOpen, onTap: onTap),
            const SizedBox(width: AppSpacing.xs),
          ],
          _CardMenu(onOpen: onTap, onMarkRead: onMarkRead),
          // The whole card opens; on a phone the chevron would only cost the
          // message width.
          if (!phone)
            const Icon(
              LucideIcons.chevronRight,
              size: AppSizing.iconSm,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );

    final framed = featured
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: colors.container.withValues(alpha: 0.4),
              borderRadius: AppRadius.mdAll,
            ),
            child: card,
          )
        : card;

    if (onMarkRead == null) return framed;

    // Swipe to clear, in the direction reading goes. `confirmDismiss` returning
    // false is deliberate: the row stays, because marking it read is what
    // changes it — the list then redraws it as read from the stream, rather
    // than this widget animating away a row that is still in the feed.
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onMarkRead!();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.check,
              size: AppSizing.iconSm,
              color: AppColors.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.notificationsMarkRead,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
      child: framed,
    );
  }

  /// The day is the heading's; the card says the time. Today also says how
  /// long ago, which is what matters within the day.
  static String _when(DateTime createdAt) {
    final time = Formatters.time(createdAt);
    final today = DateUtils.isSameDay(createdAt, clock.now());
    return today ? '${Formatters.relative(createdAt)} · $time' : time;
  }

  /// Icon, colour and name per kind.
  ///
  /// Four kinds used to share two colours, which cancelled the colour coding
  /// altogether — a price change and a low stock warning looked identical.
  /// Price and adjustment now take the neutral informational tint: neither is
  /// a stock level, and neither is bad news on its own.
  static (IconData, StockStatusColors, String) _appearance(
    AppLocalizations l10n,
    NotificationKind kind,
  ) => switch (kind) {
    NotificationKind.lowStock => (
      LucideIcons.triangleAlert,
      AppColors.lowStock,
      l10n.notificationsKindStock,
    ),
    NotificationKind.outOfStock => (
      LucideIcons.circleX,
      AppColors.outOfStock,
      l10n.notificationsKindStock,
    ),
    NotificationKind.priceChange => (
      LucideIcons.trendingUp,
      AppColors.info,
      l10n.notificationsKindPrice,
    ),
    NotificationKind.largeAdjustment => (
      LucideIcons.clipboardCheck,
      AppColors.info,
      l10n.notificationsKindAdjustment,
    ),
    NotificationKind.delivery => (
      LucideIcons.truck,
      AppColors.inStock,
      l10n.notificationsKindDelivery,
    ),
    NotificationKind.busyDays => (
      LucideIcons.calendarClock,
      AppColors.lowStock,
      l10n.notificationsKindBusyDays,
    ),
    NotificationKind.clockIn => (
      LucideIcons.logIn,
      AppColors.inStock,
      l10n.notificationsKindPointage,
    ),
    NotificationKind.clockOut => (
      LucideIcons.logOut,
      AppColors.info,
      l10n.notificationsKindPointage,
    ),
    NotificationKind.personnel => (
      LucideIcons.userRoundSearch,
      AppColors.lowStock,
      l10n.notificationsKindPersonnel,
    ),
  };
}

/// The product's photo with the kind as a small badge on its corner, or — for
/// anything without a photo — the kind's icon in a tinted disc.
class _Leading extends ConsumerWidget {
  const _Leading({
    required this.notification,
    required this.icon,
    required this.colors,
    required this.size,
  });

  final NotificationItem notification;
  final IconData icon;
  final StockStatusColors colors;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemId = notification.relatedItemId;
    final imagePath = itemId == null
        ? null
        : ref.watch(itemProvider(itemId)).value?.imagePath;

    if (imagePath == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.container,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.45, color: colors.foreground),
      );
    }

    final badge = size * 0.42;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ProductImage(imagePath: imagePath, size: size, radius: size / 2),
          Positioned(
            left: -badge * 0.25,
            top: -badge * 0.25,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: colors.solid,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Icon(icon, size: badge * 0.55, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Voir le détail », the featured card's action in words.
class _OpenPill extends StatelessWidget {
  const _OpenPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryContainer,
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// The three dots: open it, or mark it read without going anywhere.
///
/// Before the menu the only way to mark something read without opening it was
/// a button kept off phones, where the swipe alone — invisible — did it.
class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.onOpen, required this.onMarkRead});

  final VoidCallback onOpen;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    PopupMenuItem<_CardAction> item(
      _CardAction value,
      IconData icon,
      String label,
    ) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: AppSizing.iconSm, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Flexible(child: Text(label)),
        ],
      ),
    );

    return PopupMenuButton<_CardAction>(
      tooltip: l10n.itemMoreActions,
      icon: const Icon(LucideIcons.ellipsisVertical, size: AppSizing.iconSm),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (action) => switch (action) {
        _CardAction.open => onOpen(),
        _CardAction.markRead => onMarkRead?.call(),
      },
      itemBuilder: (context) => [
        item(
          _CardAction.open,
          LucideIcons.arrowUpRight,
          l10n.notificationsOpen,
        ),
        if (onMarkRead != null)
          item(
            _CardAction.markRead,
            LucideIcons.check,
            l10n.notificationsMarkRead,
          ),
      ],
    );
  }
}
