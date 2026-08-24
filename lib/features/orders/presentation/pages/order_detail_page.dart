import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/order_summary_card.dart';

/// One commande: what was ordered, what has arrived, and what can still be done
/// to it.
///
/// The action row is driven entirely by status. Actions that a status does not
/// allow are absent rather than disabled — a greyed-out "Réceptionner" on a
/// cancelled order invites the user to work out why, and there is no answer
/// they need.
class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({
    required this.storeId,
    required this.orderId,
    super.key,
  });

  final String storeId;
  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  static const String _tabLines = 'lines';
  static const String _tabReceipts = 'receipts';

  String _tab = _tabLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Receiving, sending and closing all happen from here or from a screen
    // pushed above it, so this has to redraw when any of them lands.
    ref.watch(mockDataRevisionProvider);

    final order = MockQueries.orderById(widget.orderId);

    if (order == null) {
      return ShellPage(
        title: l10n.ordersTitle,
        child: ErrorState(
          message: l10n.errorStateBody,
          onRetry: () => context.goSection(Routes.toOrders(widget.storeId)),
        ),
      );
    }

    final supplierName = MockQueries.supplierNameOf(order.supplierId);
    final receipts = MockQueries.receiptsForOrder(order.id);

    return ShellPage(
      back: BackDestination(
        label: l10n.ordersTitle,
        path: Routes.toOrders(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.ordersTitle, Routes.toOrders(widget.storeId)),
        Crumb(order.reference),
      ],
      title: l10n.orderDetailTitle(order.reference),
      subtitle: supplierName,
      actions: [
        OrderStatusBadge(status: order.status),
        ..._actionsFor(context, l10n, order, supplierName),
      ],
      tabs: SectionTabs(
        currentPath: _tab,
        onSelected: (value) => setState(() => _tab = value),
        tabs: [
          SectionTab(label: l10n.orderTabLines, path: _tabLines),
          SectionTab(label: l10n.orderTabReceipts, path: _tabReceipts),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(order: order, receiptCount: receipts.length),
          const SizedBox(height: AppSpacing.xl),

          if (order.status == PurchaseOrderStatus.sent ||
              order.status == PurchaseOrderStatus.partial) ...[
            _LockedNotice(message: l10n.orderLockedNotice),
            const SizedBox(height: AppSpacing.xl),
          ],

          if (_tab == _tabLines)
            _LinesTable(order: order)
          else
            _Receipts(
              storeId: widget.storeId,
              receipts: receipts,
              emptyMessage: l10n.orderReceiptsEmpty,
            ),

          if (order.note != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: l10n.orderNoteLabel),
            AppCard(
              child: Text(
                order.note!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions, by status
  // ---------------------------------------------------------------------------

  List<Widget> _actionsFor(
    BuildContext context,
    AppLocalizations l10n,
    PurchaseOrder order,
    String supplierName,
  ) {
    switch (order.status) {
      case PurchaseOrderStatus.draft:
        return [
          DestructiveButton(
            label: l10n.orderActionDelete,
            icon: LucideIcons.trash2,
            filled: false,
            onPressed: () => _confirmDelete(order),
          ),
          SecondaryButton(
            label: l10n.orderActionEdit,
            icon: LucideIcons.pencil,
            onPressed: () => context.pushScreen(
              Routes.toEditOrder(widget.storeId, order.id),
            ),
          ),
          PrimaryButton(
            label: l10n.orderActionSend,
            icon: LucideIcons.send,
            onPressed: () => _confirmSend(order, supplierName),
          ),
        ];

      case PurchaseOrderStatus.sent:
        return [
          if (orderCanCancel(order))
            DestructiveButton(
              label: l10n.orderActionCancel,
              icon: LucideIcons.ban,
              filled: false,
              onPressed: () => _confirmCancel(order),
            ),
          PrimaryButton(
            label: l10n.orderActionReceive,
            icon: LucideIcons.packageCheck,
            onPressed: () => context.pushScreen(
              Routes.toReceiveOrder(widget.storeId, order.id),
            ),
          ),
        ];

      case PurchaseOrderStatus.partial:
        return [
          SecondaryButton(
            label: l10n.orderActionCloseShort,
            icon: LucideIcons.packageX,
            onPressed: () => _confirmClose(order),
          ),
          PrimaryButton(
            label: l10n.orderActionReceive,
            icon: LucideIcons.packageCheck,
            onPressed: () => context.pushScreen(
              Routes.toReceiveOrder(widget.storeId, order.id),
            ),
          ),
        ];

      // Final. Nothing left to do but read it.
      case PurchaseOrderStatus.received:
      case PurchaseOrderStatus.cancelled:
        return const [];
    }
  }

  Future<void> _confirmSend(PurchaseOrder order, String supplierName) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.orderSendConfirmTitle(supplierName),
      message: l10n.orderSendConfirmBody,
      confirmLabel: l10n.orderSendConfirmAction,
      isDestructive: false,
    );
    if (!confirmed || !mounted) return;

    OrderMutations.send(order.id);
    AppSnackBar.success(context, l10n.orderSent(supplierName));
  }

  Future<void> _confirmDelete(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: order.reference,
      extraWarning: l10n.orderDeleteWarning,
    );
    if (!confirmed || !mounted) return;

    OrderMutations.deleteDraft(order.id);
    AppSnackBar.success(context, l10n.orderDeleted);
    context.goSection(Routes.toOrders(widget.storeId));
  }

  Future<void> _confirmCancel(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.orderCancelConfirmTitle(order.reference),
      message: l10n.orderCancelConfirmBody,
      confirmLabel: l10n.orderCancelConfirmAction,
    );
    if (!confirmed || !mounted) return;

    OrderMutations.cancel(order.id);
    AppSnackBar.success(context, l10n.orderCancelled);
  }

  Future<void> _confirmClose(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);
    final outstanding = order.lines.where((l) => !lineIsSettled(l)).length;

    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.orderCloseConfirmTitle(order.reference),
      message: l10n.orderCloseConfirmBody(outstanding),
      confirmLabel: l10n.orderCloseConfirmAction,
    );
    if (!confirmed || !mounted) return;

    OrderMutations.closeShort(order.id);
    AppSnackBar.success(context, l10n.orderClosed);
  }
}

/// The figures and dates at the top of the order.
class _Header extends StatelessWidget {
  const _Header({required this.order, required this.receiptCount});

  final PurchaseOrder order;
  final int receiptCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // A shortfall only exists once somebody has closed lines short. Stating it
    // here is the point of recording it — it is the figure that answers "which
    // suppliers under-deliver?".
    var shortfall = 0.0;
    for (final line in order.lines) {
      shortfall += lineShortfall(line);
    }

    return OrderSummaryCard(
      figures: [
        OrderFigure(
          label: l10n.orderTotalLabel,
          value: Formatters.price(orderTotal(order)),
          emphasis: true,
        ),
        OrderFigure(label: l10n.orderTabLines, value: '${order.lines.length}'),
        OrderFigure(label: l10n.orderTabReceipts, value: '$receiptCount'),
      ],
      footnote: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dateLine(l10n),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (shortfall > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  LucideIcons.packageX,
                  size: AppSizing.iconSm,
                  color: AppColors.lowStock.foreground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.orderShortfallNotice(Formatters.quantity(shortfall)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.lowStock.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dateLine(AppLocalizations l10n) {
    if (order.closedAt != null) {
      return l10n.orderClosedOn(Formatters.dateLong(order.closedAt!));
    }
    if (order.sentAt != null) {
      return l10n.orderSentOn(Formatters.dateLong(order.sentAt!));
    }
    return l10n.orderCreatedOn(Formatters.dateLong(order.createdAt));
  }
}

class _LockedNotice extends StatelessWidget {
  const _LockedNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.offlineContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.lock,
            size: AppSizing.iconMd,
            color: AppColors.steel800,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.steel800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.order});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: 820,
      columns: [
        DataColumn(label: Text(l10n.orderColumnItem)),
        DataColumn(label: Text(l10n.orderColumnOrdered), numeric: true),
        DataColumn(label: Text(l10n.orderColumnReceived), numeric: true),
        DataColumn(label: Text(l10n.orderColumnUnitPrice), numeric: true),
        DataColumn(label: Text(l10n.orderColumnLineTotal), numeric: true),
        DataColumn(label: Text(l10n.orderTabReceipts)),
      ],
      rows: [for (final line in order.lines) _row(context, l10n, line)],
    );
  }

  DataRow _row(
    BuildContext context,
    AppLocalizations l10n,
    PurchaseOrderLine line,
  ) {
    final item = MockQueries.itemById(line.itemId);
    final unit = item == null
        ? ''
        : MockQueries.unitAbbreviationOf(item.unitId);
    final outstanding = lineOutstanding(line);

    return DataRow(
      cells: [
        DataCell(Text(item?.name ?? '—')),
        DataCell(
          NumericCell(Formatters.quantityWithUnit(line.quantityOrdered, unit)),
        ),
        DataCell(
          NumericCell(
            Formatters.quantityWithUnit(line.quantityReceived, unit),
            emphasis: line.quantityReceived > 0,
          ),
        ),
        DataCell(NumericCell(Formatters.price(line.unitPrice))),
        DataCell(NumericCell(Formatters.price(lineTotal(line)))),
        DataCell(_LineState(line: line, outstanding: outstanding, unit: unit)),
      ],
    );
  }
}

/// Where one line stands: outstanding, closed short, or complete.
class _LineState extends StatelessWidget {
  const _LineState({
    required this.line,
    required this.outstanding,
    required this.unit,
  });

  final PurchaseOrderLine line;
  final double outstanding;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (line.closedShort) {
      return _Pill(
        label: l10n.orderLineClosedShort,
        icon: LucideIcons.packageX,
        colors: AppColors.lowStock,
      );
    }
    if (outstanding > 0) {
      return _Pill(
        label: l10n.orderLineOutstanding(
          Formatters.quantityWithUnit(outstanding, unit),
        ),
        icon: LucideIcons.clock,
        colors: OrderStatusBadge.colorsFor(PurchaseOrderStatus.sent),
      );
    }
    return _Pill(
      label: l10n.orderStatusReceived,
      icon: LucideIcons.packageCheck,
      colors: AppColors.inStock,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.colors});

  final String label;
  final IconData icon;
  final StockStatusColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizing.iconSm, color: colors.foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.foreground),
          ),
        ],
      ),
    );
  }
}

class _Receipts extends StatelessWidget {
  const _Receipts({
    required this.storeId,
    required this.receipts,
    required this.emptyMessage,
  });

  final String storeId;
  final List<GoodsReceipt> receipts;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (receipts.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: LucideIcons.packageOpen,
          title: emptyMessage,
          message: l10n.ordersEmptyBody,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final receipt in receipts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              onTap: () =>
                  context.pushScreen(Routes.toReceipt(storeId, receipt.id)),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.inStock.container,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.packageCheck,
                      size: AppSizing.iconMd,
                      color: AppColors.inStock.foreground,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.dateTime(receipt.receivedAt),
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.receiptReceivedBy(receipt.receivedByName),
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    l10n.ordersColumnLines(receipt.lines.length),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text(
                    Formatters.price(receiptValue(receipt)),
                    style: AppTypography.numeric,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: AppSizing.iconSm,
                    color: AppColors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
