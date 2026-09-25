import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'order_status_badge.dart';
import 'order_visuals.dart';

/// One commande in the orders list.
///
/// Ordered so the eye lands on the supplier first — that is how people refer to
/// an order out loud ("the Boucherie one") — with the reference, date and line
/// count underneath for when they have the paperwork in hand.
///
/// Two layouts from one set of parts. With room, everything sits on one line
/// in fixed columns so amounts and statuses line up from row to row. Narrower
/// — a phone, a portrait tablet, a detail pane — the row becomes a small card:
/// identity and amount on top, progress in the middle, status and the next
/// action along the bottom.
class OrderRow extends StatelessWidget {
  const OrderRow({
    required this.view,
    required this.stalePartialDays,
    this.onTap,
    this.selected = false,
    this.action,
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

  /// The next thing to do with this order — Envoyer, Réceptionner,
  /// Dupliquer. At the end of the row with room; along its bottom otherwise.
  final Widget? action;

  /// Below this the one-line layout's fixed columns leave the supplier name
  /// too little room — more of it with an action button on the end.
  double get _wideFrom => action == null ? 760 : 940;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      selected: selected,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _wideFrom
            ? _wide(context)
            : _narrow(context),
      ),
    );
  }

  bool get _showsProgress =>
      view.order.status == PurchaseOrderStatus.sent ||
      view.order.status == PurchaseOrderStatus.partial;

  Widget _wide(BuildContext context) {
    final order = view.order;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SupplierMonogram(name: view.supplierName),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Identity(view: view, stale: _stale),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 140,
            child: _showsProgress
                ? ReceivedProgress(share: orderReceivedShare(order))
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 116,
            child: Align(
              alignment: Alignment.centerRight,
              child: _Amount(order: order),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 128,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OrderStatusBadge(status: order.status),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }

  Widget _narrow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = view.order;
    final status = OrderStatusBadge(status: order.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SupplierMonogram(name: view.supplierName, size: 40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Identity(view: view, stale: _stale),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Amount(order: order),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Where the order stands, and how far along its delivery is.
              Row(
                children: [
                  Flexible(child: status),
                  if (_showsProgress) ...[
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: ReceivedProgress(
                        share: orderReceivedShare(order),
                        label: l10n.tableColReceived,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // The next step as a footer band across the whole card: a full-width
        // target for a thumb, and never squeezed against the status beside it.
        if (action != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.neutral50,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: SizedBox(width: double.infinity, child: action),
          ),
      ],
    );
  }

  bool get _stale => orderIsStale(view.order, stalePartialDays);
}

/// Supplier on top; reference, date and line count underneath.
class _Identity extends StatelessWidget {
  const _Identity({required this.view, required this.stale});

  final OrderRowView view;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final order = view.order;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          view.supplierName,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          children: [
            MetaItem(icon: LucideIcons.hash, label: order.reference),
            MetaItem(
              icon: LucideIcons.calendar,
              label: Formatters.date(order.sentAt ?? order.createdAt),
            ),
            MetaItem(
              icon: LucideIcons.listChecks,
              label: l10n.ordersColumnLines(order.lines.length),
            ),
            // Flagged here as well as on the dashboard: somebody scanning the
            // list should not have to do the date arithmetic themselves.
            if (stale)
              Tooltip(
                message: l10n.dashboardStaleOrdersBody,
                child: MetaItem(
                  icon: LucideIcons.clock,
                  label: l10n.receptionsLate,
                  color: AppColors.lowStock.foreground,
                  emphasis: true,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.order});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    return Text(
      Formatters.price(orderTotal(order)),
      style: AppTypography.numeric.copyWith(fontWeight: FontWeight.w700),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
    );
  }
}
