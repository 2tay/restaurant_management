import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// The notification centre.
///
/// Low stock, price changes and large adjustments in one feed, because they are
/// the three things that happen without anyone doing them. Unread entries carry
/// a dot and a tinted background — a bold font alone is too subtle at arm's
/// length.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Marking one read is a write, and this list is watching the table it
    // writes to — so the badge on the bell and the row on screen change in the
    // same frame.
    final asyncAll = ref.watch(notificationsProvider(widget.storeId));
    final all = asyncAll.value ?? const <NotificationItem>[];
    final unreadCount = all.where((n) => !n.isRead).length;

    final shown = _unreadOnly ? all.where((n) => !n.isRead).toList() : all;

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
      scrollable: false,
      actions: [
        if (unreadCount > 0)
          SecondaryButton(
            label: l10n.notificationsMarkAllRead,
            icon: LucideIcons.checkCheck,
            onPressed: _markAllRead,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(l10n.notificationsFilterAll),
                selected: !_unreadOnly,
                onSelected: (_) => setState(() => _unreadOnly = false),
              ),
              ChoiceChip(
                label: Text(l10n.notificationsFilterUnread),
                selected: _unreadOnly,
                onSelected: (_) => setState(() => _unreadOnly = true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: AsyncContent<List<NotificationItem>>(
              value: asyncAll,
              onRetry: () =>
                  ref.invalidate(notificationsProvider(widget.storeId)),
              // Only once the query has answered. Drawing "aucune notification"
              // over a list that is still arriving says something untrue, and
              // says it in the one place on the screen a user would trust.
              builder: (context, _) => shown.isEmpty
                  ? EmptyState(
                      icon: LucideIcons.bellOff,
                      title: l10n.notificationsEmpty,
                      message: l10n.notificationsEmptyBody,
                    )
                  : ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final notification = shown[index];
                        return _NotificationCard(
                          notification: notification,
                          isRead: notification.isRead,
                          onTap: () => _open(notification),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

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

  Future<void> _open(NotificationItem notification) async {
    await ref.read(accountRepositoryProvider).markRead(notification.id);
    if (!mounted) return;

    // Deep-links to whatever the notification is about, so it is actionable
    // rather than merely informative.
    if (notification.relatedItemId != null) {
      context.pushScreen(
        Routes.toItem(widget.storeId, notification.relatedItemId!),
      );
    } else if (notification.relatedSupplierId != null) {
      context.pushScreen(
        Routes.toSupplier(widget.storeId, notification.relatedSupplierId!),
      );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  final NotificationItem notification;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, colors) = _appearance(notification.kind);

    return AppCard(
      onTap: onTap,
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
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.relative(notification.createdAt),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (!isRead)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary600,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  (IconData, StockStatusColors) _appearance(NotificationKind kind) =>
      switch (kind) {
        NotificationKind.lowStock => (
          LucideIcons.triangleAlert,
          AppColors.lowStock,
        ),
        NotificationKind.outOfStock => (
          LucideIcons.circleX,
          AppColors.outOfStock,
        ),
        NotificationKind.priceChange => (
          LucideIcons.trendingUp,
          AppColors.lowStock,
        ),
        NotificationKind.largeAdjustment => (
          LucideIcons.clipboardCheck,
          AppColors.outOfStock,
        ),
        NotificationKind.delivery => (LucideIcons.truck, AppColors.inStock),
      };
}
