import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// The notification centre.
///
/// Low stock, price changes and large adjustments in one feed, because they are
/// the three things that happen without anyone doing them. Unread entries carry
/// a dot and a tinted background — a bold font alone is too subtle at arm's
/// length.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({required this.storeId, super.key});

  final String storeId;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _unreadOnly = false;

  /// Ids marked read in this session. Phase 1 persists nothing.
  final Set<String> _locallyRead = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final all = MockQueries.notificationsForStore(widget.storeId);
    final unreadCount = all
        .where((n) => !n.isRead && !_locallyRead.contains(n.id))
        .length;

    final shown = _unreadOnly
        ? all.where((n) => !n.isRead && !_locallyRead.contains(n.id)).toList()
        : all;

    return ShellPage(
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
            child: shown.isEmpty
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
                        isRead:
                            notification.isRead ||
                            _locallyRead.contains(notification.id),
                        onTap: () => _open(notification),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _markAllRead() {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _locallyRead.addAll(
        MockQueries.notificationsForStore(widget.storeId).map((n) => n.id),
      );
    });
    AppSnackBar.success(context, l10n.notificationsAllRead);
  }

  void _open(NotificationItem notification) {
    setState(() => _locallyRead.add(notification.id));

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
