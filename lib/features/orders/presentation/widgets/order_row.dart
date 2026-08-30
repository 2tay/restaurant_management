import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import 'order_status_badge.dart';

/// One commande in the orders list.
///
/// Ordered so the eye lands on the supplier first — that is how people refer to
/// an order out loud ("the Boucherie one") — with the reference underneath for
/// when they have the paperwork in hand.
class OrderRow extends StatelessWidget {
  const OrderRow({
    required this.view,
    required this.stalePartialDays,
    this.onTap,
    this.selected = false,
    super.key,
  });

  final OrderRowView view;

  /// The establishment's threshold for flagging a partial commande as stale.
  ///
  /// Passed in rather than read here. It is a column on the establishment now,
  /// so reading it inside the row would be a query per row on the busiest list
  /// in the app — and every row on one screen shares the same answer.
  final int stalePartialDays;

  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final order = view.order;
    final colors = OrderStatusBadge.colorsFor(order.status);
    final stale = orderIsStale(order, stalePartialDays);

    return AppCard(
      onTap: onTap,
      selected: selected,
      accentColor: colors.solid,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.supplierName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  order.reference,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.date(order.sentAt ?? order.createdAt),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.ordersColumnLines(order.lines.length),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Flagged here as well as on the dashboard: somebody scanning the
          // list should not have to do the date arithmetic themselves.
          if (stale) ...[
            Tooltip(
              message: l10n.dashboardStaleOrdersBody,
              child: const Icon(
                LucideIcons.clock,
                size: AppSizing.iconMd,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],

          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                Formatters.price(orderTotal(order)),
                style: AppTypography.numeric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          SizedBox(width: 132, child: OrderStatusBadge(status: order.status)),
        ],
      ),
    );
  }
}
