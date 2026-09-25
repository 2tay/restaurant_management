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
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../documents/order_document_button.dart';
import '../../documents/receipt_document_button.dart';
import '../widgets/order_actions.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/order_summary_card.dart';
import '../widgets/order_visuals.dart';

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
    // pushed above it, and the query behind this watches every table they
    // touch — so the page is right when the user comes back to it.
    final detail = ref.watch(orderDetailProvider(widget.orderId));
    final view = detail.value;

    if (view == null) {
      return ShellPage(
        title: l10n.ordersTitle,
        child: detail.isLoading
            ? const SkeletonList(rows: 4, rowHeight: 110)
            : ErrorState(
                message: l10n.errorStateBody,
                onRetry: () =>
                    context.goSection(Routes.toOrders(widget.storeId)),
              ),
      );
    }

    final order = view.order;
    final supplierName = view.supplierName;
    final receipts = view.receipts;

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
        // Every status: a draft to check before sending, a sent order to
        // forward again, a finished one for the records.
        OrderDocumentButton(order: order),
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
          _Header(
            order: order,
            receiptCount: receipts.length,
            receiptDates: [for (final r in receipts) r.receipt.receivedAt],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (order.status == PurchaseOrderStatus.sent ||
              order.status == PurchaseOrderStatus.partial) ...[
            _LockedNotice(message: l10n.orderLockedNotice),
            const SizedBox(height: AppSpacing.xl),
          ],

          if (_tab == _tabLines)
            _LinesTable(lines: view.lines)
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

      // Final. Nothing left to do but read it — or order the same again.
      case PurchaseOrderStatus.received:
      case PurchaseOrderStatus.cancelled:
        return [
          PrimaryButton(
            label: l10n.orderActionDuplicate,
            icon: LucideIcons.copy,
            onPressed: () =>
                duplicateOrder(context, ref, widget.storeId, order),
          ),
        ];
    }
  }

  Future<void> _confirmSend(PurchaseOrder order, String supplierName) =>
      confirmSendOrder(context, ref, order, supplierName);

  Future<void> _confirmDelete(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: order.reference,
      extraWarning: l10n.orderDeleteWarning,
    );
    if (!confirmed || !mounted) return;

    await ref.read(orderRepositoryProvider).deleteDraft(order.id);

    if (!mounted) return;
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

    await ref.read(orderRepositoryProvider).cancel(order.id);

    if (!mounted) return;
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

    await ref.read(orderRepositoryProvider).closeShort(order.id);

    if (!mounted) return;
    AppSnackBar.success(context, l10n.orderClosed);
  }
}

/// The figures and dates at the top of the order.
class _Header extends StatelessWidget {
  const _Header({
    required this.order,
    required this.receiptCount,
    required this.receiptDates,
  });

  final PurchaseOrder order;
  final int receiptCount;

  /// When each delivery arrived, oldest first — the timeline's middle.
  final List<DateTime> receiptDates;

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
          _Timeline(order: order, receiptDates: receiptDates),
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
}

/// What happened to the order, in order: created, sent, each delivery,
/// finished or cancelled — each with its date. The steps still to come are
/// not drawn; the order's status says what is next.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.order, required this.receiptDates});

  final PurchaseOrder order;
  final List<DateTime> receiptDates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final events = <(String, DateTime, bool)>[
      (l10n.orderTimelineCreated, order.createdAt, false),
      if (order.sentAt != null) (l10n.orderTimelineSent, order.sentAt!, false),
      for (final (i, at) in receiptDates.indexed)
        (l10n.orderTimelineReceipt(i + 1), at, false),
      if (order.closedAt != null)
        (
          order.status == PurchaseOrderStatus.cancelled
              ? l10n.orderTimelineCancelled
              : l10n.orderTimelineDone,
          order.closedAt!,
          true,
        ),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, (label, at, last)) in events.indexed) ...[
          if (i > 0)
            const Icon(
              LucideIcons.chevronRight,
              size: AppSizing.iconSm,
              color: AppColors.textDisabled,
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: last ? AppColors.primary600 : AppColors.neutral400,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  '$label · ${Formatters.date(at)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
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

/// What was ordered, line by line.
///
/// A table where there is room for one. Below [_stacksBelow] the six columns
/// would have to be panned sideways, so each line becomes a stacked row in
/// the same frame: product and total on top, quantities underneath, where it
/// stands along the bottom.
class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.lines});

  final List<OrderLineView> lines;

  static const double _stacksBelow = 640;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final figure = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _stacksBelow) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, line) in lines.indexed) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.hairline),
                  _StackedLine(view: line),
                ],
              ],
            ),
          );
        }

        return AppTable<OrderLineView>(
          rows: lines,
          shrinkWrap: true,
          rowHeight: 56,
          columns: [
            AppTableColumn(label: l10n.orderColumnItem, flex: 3),
            AppTableColumn(
              label: l10n.orderColumnOrdered,
              width: 120,
              numeric: true,
            ),
            AppTableColumn(
              label: l10n.orderColumnReceived,
              width: 120,
              numeric: true,
            ),
            AppTableColumn(
              label: l10n.orderColumnUnitPrice,
              width: 124,
              numeric: true,
              minTableWidth: 900,
            ),
            AppTableColumn(
              label: l10n.orderColumnLineTotal,
              width: 124,
              numeric: true,
            ),
            AppTableColumn(label: l10n.tableColStatus, width: 200),
          ],
          cell: (context, view, column) {
            final line = view.line;
            final unit = view.unitAbbreviation;
            return switch (column) {
              0 => Text(
                view.itemName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              1 => Text(
                Formatters.quantityWithUnit(line.quantityOrdered, unit),
                style: figure,
                maxLines: 1,
              ),
              2 => Text(
                Formatters.quantityWithUnit(line.quantityReceived, unit),
                style: line.quantityReceived > 0
                    ? figure?.copyWith(fontWeight: FontWeight.w600)
                    : figure?.copyWith(color: AppColors.textSecondary),
                maxLines: 1,
              ),
              3 => Text(
                Formatters.price(line.unitPrice),
                style: figure,
                maxLines: 1,
              ),
              4 => Text(
                Formatters.price(lineTotal(line)),
                style: figure?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
              ),
              _ => _LineState(
                line: line,
                outstanding: lineOutstanding(line),
                unit: unit,
              ),
            };
          },
        );
      },
    );
  }
}

/// One order line on a phone.
class _StackedLine extends StatelessWidget {
  const _StackedLine({required this.view});

  final OrderLineView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final line = view.line;
    final unit = view.unitAbbreviation;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  view.itemName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Formatters.price(lineTotal(line)),
                style: AppTypography.numeric.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              Text(
                '${l10n.orderColumnOrdered} '
                '${Formatters.quantityWithUnit(line.quantityOrdered, unit)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${l10n.orderColumnReceived} '
                '${Formatters.quantityWithUnit(line.quantityReceived, unit)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: line.quantityReceived > 0
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: line.quantityReceived > 0
                      ? FontWeight.w600
                      : null,
                ),
              ),
              Text(
                '× ${Formatters.price(line.unitPrice)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _LineState(
              line: line,
              outstanding: lineOutstanding(line),
              unit: unit,
            ),
          ),
        ],
      ),
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
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
  final List<ReceiptRowView> receipts;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
        for (final view in receipts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ReceiptCard(storeId: storeId, view: view),
          ),
      ],
    );
  }
}

/// One delivery against the commande.
///
/// One line with room; on a phone the value and the lines count move under
/// the reference so nothing is pushed off the edge.
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.storeId, required this.view});

  final String storeId;
  final ReceiptRowView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final receipt = view.receipt;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    final medallion = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.inStock.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Icon(
        LucideIcons.packageCheck,
        size: AppSizing.iconMd,
        color: AppColors.inStock.foreground,
      ),
    );

    // The document reference leads rather than the date: a three-delivery
    // order shows three rows that otherwise differ only by timestamp, and the
    // reference is what staff and the supplier actually name them by.
    final reference = Text(
      view.reference,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final meta = Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MetaItem(
          icon: LucideIcons.calendar,
          label: Formatters.dateTime(receipt.receivedAt),
        ),
        EmployeeNameTag(
          name: l10n.receiptReceivedBy(receipt.receivedByName),
          employeeId: receipt.receivedByEmployeeId,
          style: muted,
          avatarSize: 18,
        ),
      ],
    );

    final value = Text(
      Formatters.price(receiptValue(receipt)),
      style: AppTypography.numeric.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 1,
    );
    final lines = Text(
      l10n.ordersColumnLines(receipt.lines.length),
      style: muted,
      maxLines: 1,
    );

    // Straight from the list: the partial delivery somebody needs to send on
    // is usually one of several on the order, and making them open each one
    // to find it is how the feature ends up unused.
    final document = ReceiptDocumentButton(receipt: receipt, compact: true);

    return AppCard(
      onTap: () => context.pushScreen(Routes.toReceipt(storeId, receipt.id)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                medallion,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: reference),
                          const SizedBox(width: AppSpacing.sm),
                          value,
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      meta,
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(child: lines),
                          document,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              medallion,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    reference,
                    const SizedBox(height: AppSpacing.xxs),
                    meta,
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              lines,
              const SizedBox(width: AppSpacing.lg),
              value,
              const SizedBox(width: AppSpacing.sm),
              document,
              const Icon(
                LucideIcons.chevronRight,
                size: AppSizing.iconSm,
                color: AppColors.textDisabled,
              ),
            ],
          );
        },
      ),
    );
  }
}
