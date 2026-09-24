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

/// Which kinds the feed is narrowed to.
///
/// Coarser than [NotificationKind] on purpose: low stock and rupture are the
/// same worry at two severities, and nobody looking for one wants the other
/// hidden.
enum NotificationFilter { all, stock, price, adjustment, delivery }

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Marking one read is a write, and this list is watching the table it
    // writes to — so the badge on the bell and the row on screen change in the
    // same frame.
    final asyncAll = ref.watch(notificationsProvider(widget.storeId));
    final all = asyncAll.value ?? const <NotificationItem>[];
    final unreadCount = all.where((n) => !n.isRead).length;

    final shown = all
        .where((n) => !_unreadOnly || !n.isRead)
        .where((n) => _matches(_kind, n.kind))
        .toList();

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
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Filters(
            all: all,
            kind: _kind,
            unreadOnly: _unreadOnly,
            onKind: (value) => setState(() => _kind = value),
            onUnreadOnly: (value) => setState(() => _unreadOnly = value),
          ),
          const SizedBox(height: AppSpacing.lg),
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
    final groups = <({String label, List<NotificationItem> items})>[];
    DateTime? currentDay;
    for (final notification in shown) {
      final day = DateUtils.dateOnly(notification.createdAt);
      if (currentDay == null || day != currentDay) {
        currentDay = day;
        groups.add((label: _dayLabel(l10n, day), items: []));
      }
      groups.last.items.add(notification);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, group) in groups.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: group.label, count: group.items.length),
          const SizedBox(height: AppSpacing.sm),
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
    final today = DateUtils.dateOnly(DateTime.now());
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
              kind == NotificationKind.outOfStock,
        NotificationFilter.price => kind == NotificationKind.priceChange,
        NotificationFilter.adjustment =>
          kind == NotificationKind.largeAdjustment,
        NotificationFilter.delivery => kind == NotificationKind.delivery,
      };

  Future<void> _markAllRead() async {
    final l10n = AppLocalizations.of(context);
    final changed = await ref
        .read(accountRepositoryProvider)
        .markAllRead(widget.storeId);

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
        .markRead(notification.id);

    if (!mounted || !changed) return;
    AppSnackBar.success(context, l10n.notificationsMarkedOneRead);
  }

  Future<void> _open(NotificationItem notification) async {
    await ref.read(accountRepositoryProvider).markRead(notification.id);
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
    }
  }
}

// -----------------------------------------------------------------------------
// Filters.
// -----------------------------------------------------------------------------

/// The kind menu and the unread toggle, each carrying its own count.
///
/// Counts on the controls rather than only in the list: "Prix (3)" tells you
/// whether the filter is worth applying before you apply it and find nothing.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.all,
    required this.kind,
    required this.unreadOnly,
    required this.onKind,
    required this.onUnreadOnly,
  });

  final List<NotificationItem> all;
  final NotificationFilter kind;
  final bool unreadOnly;
  final ValueChanged<NotificationFilter> onKind;
  final ValueChanged<bool> onUnreadOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = all.where((n) => !n.isRead).length;

    int count(NotificationFilter filter) => all
        .where((n) => _NotificationsPageState._matches(filter, n.kind))
        .length;

    String labelled(String label, NotificationFilter filter) {
      final n = count(filter);
      return n == 0 ? label : '$label ($n)';
    }

    final entries = {
      NotificationFilter.all: labelled(
        l10n.notificationsFilterAll,
        NotificationFilter.all,
      ),
      NotificationFilter.stock: labelled(
        l10n.notificationsKindStock,
        NotificationFilter.stock,
      ),
      NotificationFilter.price: labelled(
        l10n.notificationsKindPrice,
        NotificationFilter.price,
      ),
      NotificationFilter.adjustment: labelled(
        l10n.notificationsKindAdjustment,
        NotificationFilter.adjustment,
      ),
      NotificationFilter.delivery: labelled(
        l10n.notificationsKindDelivery,
        NotificationFilter.delivery,
      ),
    };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterMenu<NotificationFilter>(
          label: l10n.notificationsFilterKind,
          // The default names nothing: a pill reading "Type : Toutes" says only
          // that no choice has been made.
          selectedLabel: kind == NotificationFilter.all ? null : entries[kind],
          entries: entries,
          onSelected: onKind,
        ),
        FilterMenu<bool>(
          label: l10n.notificationsFilterUnread,
          selectedLabel: unreadOnly ? l10n.notificationsFilterUnread : null,
          entries: {
            false: l10n.notificationsFilterAll,
            true: unread == 0
                ? l10n.notificationsFilterUnread
                : '${l10n.notificationsFilterUnread} ($unread)',
          },
          onSelected: onUnreadOnly,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// One entry.
// -----------------------------------------------------------------------------

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
    final isRead = notification.isRead;
    final (icon, colors, kindLabel) = _appearance(l10n, notification.kind);

    final card = AppCard(
      onTap: onTap,
      // The unread marker is the accent edge itself rather than a 10dp dot:
      // the same information, readable from further away, and it leaves the
      // right-hand end of the row free for the action.
      accentColor: isRead ? null : colors.solid,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.container,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSizing.iconMd, color: colors.foreground),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(notification.body, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                // The kind in words beside the time, so the medallion's colour
                // is never the only thing saying what this is.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LabelChip(
                      label: kindLabel,
                      background: colors.container,
                      foreground: colors.foreground,
                      dense: true,
                    ),
                    Text(
                      Formatters.relative(notification.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // On a phone the row is already tight; there the swipe is the way to
          // clear one, and this button would cost the message a word a line.
          if (onMarkRead != null && !context.isPhone) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: onMarkRead,
              tooltip: l10n.notificationsMarkRead,
              icon: const Icon(LucideIcons.check, size: AppSizing.iconSm),
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );

    if (onMarkRead == null) return card;

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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
      child: card,
    );
  }

  /// Icon, colour and name per kind.
  ///
  /// Four kinds used to share two colours, which cancelled the colour coding
  /// altogether — a price change and a low stock warning looked identical.
  /// Price and adjustment now take the neutral informational tint: neither is
  /// a stock level, and neither is bad news on its own.
  (IconData, StockStatusColors, String) _appearance(
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
  };
}
