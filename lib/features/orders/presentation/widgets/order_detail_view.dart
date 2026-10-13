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
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../documents/receipt_document_button.dart';
import 'order_status_badge.dart';
import 'order_panel_parts.dart';
import 'order_summary_card.dart';
import 'order_visuals.dart';
import 'receipt_detail_view.dart';

/// The body of one commande: what was ordered, what has arrived, and the trail
/// of réceptions behind it.
///
/// Extracted from `OrderDetailPage` the way `ItemDetailView` was extracted for
/// the catalogue's split pane. The page keeps its own header and its full row
/// of actions; a panel builds the same content with a header of its own. One
/// definition of what a commande shows.
///
/// **A panel carries no destructive action.** Supprimer, Annuler and Clôturer
/// stay on the page. A panel is opened to glance at a commande on the way to
/// something else, and a list you are half-way through is the worst possible
/// place to cancel an order from. What the panel does offer is the thing that
/// brought you: the bon de commande, and Réceptionner.
class OrderDetailBody extends ConsumerWidget {
  const OrderDetailBody({
    required this.storeId,
    required this.orderId,
    required this.tab,
    this.onTabChanged,
    this.panel,
    super.key,
  });

  final String storeId;
  final String orderId;

  /// Which tab is open. Owned by the surface, because the page shows its tabs
  /// in `ShellPage`'s header and a panel shows them in its own.
  final String tab;
  final ValueChanged<String>? onTabChanged;

  /// Non-null inside a panel, which has no page header to carry the title and
  /// the actions — so the view draws its own.
  final PanelController? panel;

  static const String tabLines = 'lines';
  static const String tabReceipts = 'receipts';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(orderDetailProvider(orderId));
    final view = detail.value;

    if (view == null) {
      return detail.isLoading
          ? const SkeletonList(rows: 4, rowHeight: 110)
          : ErrorState(
              message: l10n.errorStateBody,
              onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
            );
    }

    final order = view.order;
    final receipts = view.receipts;

    if (panel != null) return _panel(context, view);

    final body = Column(
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

        if (tab == tabLines)
          _LinesTable(lines: view.lines)
        else
          _Receipts(
            storeId: storeId,
            receipts: receipts,
            emptyMessage: l10n.orderReceiptsEmpty,
            // A réception here is a detail *of* the commande: you check what
            // arrived and then go back to the lines. `openReceiptPanel`
            // opens a panel from the page and walks this one forward when
            // the commande is itself in a panel — the branch used to live
            // here, and the helper is where it belongs.
            onOpen: (receiptId) => openReceiptPanel(
              context,
              storeId: storeId,
              receiptId: receiptId,
            ),
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
    );

    return body;
  }

  /// The commande as a panel: a pinned header and footer, the hero card and
  /// tabs, and the open tab stretched down to the footer. Figures and colours
  /// carry it; the sentences the page spells out are tooltips here.
  Widget _panel(BuildContext context, OrderDetailView view) {
    final l10n = AppLocalizations.of(context);
    final order = view.order;
    final receipts = view.receipts;
    final receiptDates = [for (final r in receipts) r.receipt.receivedAt];
    final showReceipts = tab == tabReceipts;

    Widget content(bool pinned) {
      if (!showReceipts) {
        return OrderPanelLines(
          order: order,
          lines: view.lines,
          pinned: pinned,
          showProgress:
              order.status != PurchaseOrderStatus.draft &&
              order.status != PurchaseOrderStatus.cancelled,
        );
      }
      final list = _Receipts(
        storeId: storeId,
        receipts: receipts,
        emptyMessage: l10n.orderReceiptsEmpty,
        onOpen: (receiptId) =>
            openReceiptPanel(context, storeId: storeId, receiptId: receiptId),
      );
      return pinned ? SingleChildScrollView(child: list) : list;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PanelFillLayout(
            top: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OrderPanelHeader(
                  panel: panel!,
                  order: order,
                  supplierName: view.supplierName,
                ),
                const SizedBox(height: AppSpacing.lg),
                OrderPanelHero(order: order, receiptDates: receiptDates),
                if (order.note != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  PanelNote(note: order.note!),
                ],
                const SizedBox(height: AppSpacing.lg),
                OrderPanelTabs(
                  current: showReceipts ? tabReceipts : tabLines,
                  onSelected: onTabChanged,
                  tabs: [
                    OrderPanelTab(
                      id: tabLines,
                      label: l10n.orderPanelTabItems,
                      shortLabel: l10n.orderTabLines,
                      count: view.lines.length,
                    ),
                    OrderPanelTab(
                      id: tabReceipts,
                      label: l10n.orderTabReceipts,
                      count: receipts.length,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
            fill: content,
          ),
        ),
        OrderPanelFooter(
          order: order,
          onReceive: orderCanReceive(order)
              ? () =>
                    context.pushScreen(Routes.toReceiveOrder(storeId, order.id))
              : null,
        ),
      ],
    );
  }
}

/// A commande as a panel, which keeps its own open tab.
class OrderDetailPanel extends StatefulWidget {
  const OrderDetailPanel({
    required this.storeId,
    required this.orderId,
    required this.panel,
    super.key,
  });

  final String storeId;
  final String orderId;
  final PanelController panel;

  @override
  State<OrderDetailPanel> createState() => _OrderDetailPanelState();
}

class _OrderDetailPanelState extends State<OrderDetailPanel> {
  String _tab = OrderDetailBody.tabLines;

  @override
  Widget build(BuildContext context) {
    return OrderDetailBody(
      storeId: widget.storeId,
      orderId: widget.orderId,
      tab: _tab,
      onTabChanged: (value) => setState(() => _tab = value),
      panel: widget.panel,
    );
  }
}

/// Opens a commande as a panel over whatever asked for it.
///
/// Already inside a panel — a commande reached from a product, say — it walks
/// that panel forward instead of stacking a second one. Call sites do not have
/// to know which; they ask for the commande and this decides.
Future<void> openOrderPanel(
  BuildContext context, {
  required String storeId,
  required String orderId,
}) {
  PanelBuilder build() =>
      (context, panel) =>
          OrderDetailPanel(storeId: storeId, orderId: orderId, panel: panel);

  final current = PanelController.maybeOf(context);
  if (current != null) {
    current.open(build());
    return Future.value();
  }
  return showDetailPanel(
    context,
    builder: build(),
    width: orderPanelWidth(context),
  );
}

/// How wide a commande or réception panel opens: the usual 560 on a
/// desktop, most of the screen on a tablet — where 560 would leave a strip of
/// list nobody can use beside it. A phone gets a bottom sheet regardless.
double orderPanelWidth(BuildContext context) {
  final screen = MediaQuery.sizeOf(context).width;
  if (screen >= AppBreakpoints.expanded) return 600;
  return (screen * 0.86).clamp(560.0, 720.0);
}

/// Opens a réception as a panel, walking forward when already in one.
Future<void> openReceiptPanel(
  BuildContext context, {
  required String storeId,
  required String receiptId,
}) {
  PanelBuilder build() =>
      (context, panel) => ReceiptDetailBody(
        storeId: storeId,
        receiptId: receiptId,
        panel: panel,
      );

  final current = PanelController.maybeOf(context);
  if (current != null) {
    current.open(build());
    return Future.value();
  }
  return showDetailPanel(
    context,
    builder: build(),
    width: orderPanelWidth(context),
  );
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
              _ => OrderLineState(
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
            child: OrderLineState(
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
class OrderLineState extends StatelessWidget {
  const OrderLineState({
    required this.line,
    required this.outstanding,
    required this.unit,
    super.key,
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
    required this.onOpen,
  });

  final String storeId;
  final List<ReceiptRowView> receipts;
  final String emptyMessage;

  /// What opening a réception does here — a panel walks to it, a page
  /// navigates. The card itself does not need to know which.
  final ValueChanged<String> onOpen;

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
        // Oldest first, so the position is the number after the slash.
        for (final (i, view) in receipts.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ReceiptCard(
              storeId: storeId,
              view: view,
              sequence: i + 1,
              onOpen: () => onOpen(view.receipt.id),
            ),
          ),
      ],
    );
  }
}

/// One delivery against the commande, read at a glance: its number in a
/// medallion tinted by whether it matched, the bon's reference, when and who,
/// and on the right what it was worth with the verdict under it.
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.storeId,
    required this.view,
    required this.sequence,
    required this.onOpen,
  });

  final String storeId;
  final ReceiptRowView view;

  /// 1 for the first delivery — the `/1` of its reference.
  final int sequence;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final receipt = view.receipt;
    final discrepancies = receiptDiscrepancyCount(receipt);
    final conform = discrepancies == 0;
    final verdict = conform ? AppColors.inStock : AppColors.lowStock;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    return AppCard(
      // Keyed by the réception it shows: it keeps the list stable when one is
      // added, and it is what lets a test point at a receipt card rather than
      // at whichever card happens to come first.
      key: ValueKey('receipt-${receipt.id}'),
      // Inside a panel this walks forward instead of stacking a second one —
      // the réception replaces what the panel shows and grows a back arrow.
      // On the page there is no panel, so it navigates as it always did.
      onTap: onOpen,
      accentColor: conform ? null : verdict.solid,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: verdict.container,
              borderRadius: AppRadius.mdAll,
            ),
            child: Text(
              '#$sequence',
              style: theme.textTheme.titleSmall?.copyWith(
                color: verdict.foreground,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The reference leads rather than the date: it is what staff
                // and the supplier actually name a delivery by.
                Text(
                  view.reference,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MetaItem(
                      icon: LucideIcons.calendarClock,
                      label: Formatters.dateTime(receipt.receivedAt),
                    ),
                    EmployeeNameTag(
                      name: receipt.receivedByName,
                      employeeId: receipt.receivedByEmployeeId,
                      style: muted,
                      avatarSize: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.price(receiptValue(receipt)),
                style: AppTypography.numeric.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Tooltip(
                message: conform
                    ? l10n.receptionsConform
                    : l10n.receptionsDiscrepancies(discrepancies),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      conform
                          ? LucideIcons.circleCheck
                          : LucideIcons.triangleAlert,
                      size: 14,
                      color: verdict.foreground,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      conform
                          ? '${receipt.lines.length}'
                          : '$discrepancies / ${receipt.lines.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: verdict.foreground,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          // Straight from the list: the partial delivery somebody needs to
          // send on is usually one of several on the order.
          ReceiptDocumentButton(receipt: receipt, compact: true),
        ],
      ),
    );
  }
}
