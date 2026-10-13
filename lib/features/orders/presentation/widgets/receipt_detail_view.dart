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
import '../../../../shared/widgets/widgets.dart';
import '../../documents/receipt_document_button.dart';
import 'order_detail_view.dart';
import 'order_panel_parts.dart';
import 'order_visuals.dart';
import 'order_summary_card.dart';

/// The body of one recorded delivery.
///
/// Extracted from `ReceiptDetailPage` the way `ItemDetailView` was extracted
/// for the catalogue's split pane: the page keeps its own header and hands the
/// body here, and a panel builds the same view with a header of its own. One
/// definition of what a réception shows, so the two cannot drift.
///
/// Takes an **id**, not a receipt, and watches its own query — so a panel
/// opened over a list keeps showing the right thing while the list beneath it
/// changes.
class ReceiptDetailBody extends ConsumerWidget {
  const ReceiptDetailBody({
    required this.storeId,
    required this.receiptId,
    this.panel,
    super.key,
  });

  final String storeId;
  final String receiptId;

  /// Non-null inside a panel, which has no page header to carry the title and
  /// the actions — so the view draws its own. Null on the page, where
  /// `ShellPage` already has them.
  final PanelController? panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(receiptDetailProvider(receiptId));
    final view = detail.value;

    if (view == null) {
      return detail.isLoading
          ? const SkeletonList(rows: 3, rowHeight: 110)
          : ErrorState(
              message: l10n.errorStateBody,
              onRetry: () => ref.invalidate(receiptDetailProvider(receiptId)),
            );
    }

    if (panel != null) {
      return _ReceiptPanel(storeId: storeId, view: view, panel: panel!);
    }

    final receipt = view.receipt;
    final discrepancies = receipt.lines
        .where(
          (line) => isDiscrepancy(
            outcomeOf(
              ordered: line.quantityOrdered,
              received: line.quantityReceived,
              wasUnordered: line.wasUnordered,
            ),
          ),
        )
        .length;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Who checked it in, with their face when the receipt names them —
        // the person to ask when a figure below looks wrong.
        Align(
          alignment: Alignment.centerLeft,
          child: EmployeeNameTag(
            name: l10n.receiptReceivedBy(receipt.receivedByName),
            employeeId: receipt.receivedByEmployeeId,
            style: Theme.of(context).textTheme.bodyMedium,
            avatarSize: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OrderSummaryCard(
          figures: [
            OrderFigure(
              label: l10n.receiptValueLabel,
              value: Formatters.price(receiptValue(receipt)),
              emphasis: true,
            ),
            OrderFigure(
              label: l10n.receiveSummaryLines,
              value: '${receipt.lines.length}',
            ),
            OrderFigure(
              label: l10n.receiveSummaryDiscrepancies,
              value: '$discrepancies',
              accent: discrepancies == 0 ? null : AppColors.lowStock,
            ),
          ],
          footnote: Row(
            children: [
              const Icon(
                LucideIcons.lock,
                size: AppSizing.iconSm,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.receiptReadOnlyNotice,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(title: l10n.orderTabLines, count: receipt.lines.length),
        // A table of five columns wants 900dp and a panel has 560, so on the
        // page it stays a table and in a panel each line becomes a card.
        // Scrolling a table sideways inside a panel that is itself a narrow
        // column is two axes of movement to read one delivery.
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 700) {
              return DataTableWrapper(
                minWidth: 900,
                columns: [
                  DataColumn(label: Text(l10n.orderColumnItem)),
                  DataColumn(
                    label: Text(l10n.receiveColumnOrdered),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(l10n.receiveColumnReceived),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(l10n.orderColumnUnitPrice),
                    numeric: true,
                  ),
                  DataColumn(label: Text(l10n.receiptColumnNote)),
                ],
                rows: [
                  for (final line in view.lines) _row(context, l10n, line),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, line) in view.lines.indexed) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.xs),
                  _LineCard(view: line),
                ],
              ],
            );
          },
        ),

        if (receipt.note != null) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: l10n.receiveNoteLabel),
          AppCard(
            child: Text(
              receipt.note!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ],
    );

    return body;
  }

  DataRow _row(
    BuildContext context,
    AppLocalizations l10n,
    ReceiptLineView view,
  ) {
    final line = view.line;
    final unit = view.unitAbbreviation;
    final outcome = outcomeOf(
      ordered: line.quantityOrdered,
      received: line.quantityReceived,
      wasUnordered: line.wasUnordered,
    );

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Flexible(child: Text(view.itemName)),
              if (line.wasUnordered) ...[
                const SizedBox(width: AppSpacing.sm),
                _Flag(
                  label: l10n.receiveUnorderedBadge,
                  icon: LucideIcons.circlePlus,
                  colors: AppColors.lowStock,
                ),
              ],
            ],
          ),
        ),
        DataCell(
          NumericCell(
            line.wasUnordered
                ? '—'
                : Formatters.quantityWithUnit(line.quantityOrdered, unit),
          ),
        ),
        DataCell(
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              NumericCell(
                Formatters.quantityWithUnit(line.quantityReceived, unit),
                emphasis: true,
              ),
              if (outcome == ReceiptLineOutcome.short) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  line.closedShort ? LucideIcons.packageX : LucideIcons.clock,
                  size: AppSizing.iconSm,
                  color: AppColors.lowStock.foreground,
                ),
              ],
              if (outcome == ReceiptLineOutcome.over) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  LucideIcons.trendingUp,
                  size: AppSizing.iconSm,
                  color: AppColors.lowStock.foreground,
                ),
              ],
            ],
          ),
        ),
        DataCell(NumericCell(Formatters.price(line.actualUnitPrice))),
        DataCell(
          Text(
            line.note ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.label, required this.icon, required this.colors});

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

/// One delivered line, for a column too narrow to be a table.
///
/// The five columns become two lines: what it is and what it cost on top,
/// what was ordered against what arrived underneath. The ordered figure is
/// only worth showing when it differs from what came — on a line that arrived
/// in full it is the same number twice.
class _LineCard extends StatelessWidget {
  const _LineCard({required this.view});

  final ReceiptLineView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final line = view.line;
    final unit = view.unitAbbreviation;
    final outcome = outcomeOf(
      ordered: line.quantityOrdered,
      received: line.quantityReceived,
      wasUnordered: line.wasUnordered,
    );
    final settled = !isDiscrepancy(outcome);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  view.itemName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Formatters.price(line.actualUnitPrice),
                style: AppTypography.numeric,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                Formatters.quantityWithUnit(line.quantityReceived, unit),
                style: AppTypography.numeric.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              // Only where the two disagree. On a line that arrived in full,
              // "commandé 6 kg · reçu 6 kg" is the same number twice.
              if (!settled && !line.wasUnordered)
                Text(
                  l10n.receiptOrderedOf(
                    Formatters.quantityWithUnit(line.quantityOrdered, unit),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              if (line.wasUnordered)
                _Flag(
                  label: l10n.receiveUnorderedBadge,
                  icon: LucideIcons.circlePlus,
                  colors: AppColors.lowStock,
                ),
              if (outcome == ReceiptLineOutcome.short)
                _Flag(
                  label: line.closedShort
                      ? l10n.receiptClosedShortBadge
                      : l10n.receiptShortBadge,
                  icon: line.closedShort
                      ? LucideIcons.packageX
                      : LucideIcons.clock,
                  colors: AppColors.lowStock,
                ),
              if (outcome == ReceiptLineOutcome.over)
                _Flag(
                  label: l10n.receiveOverBadge(
                    Formatters.quantityWithUnit(
                      line.quantityReceived - line.quantityOrdered,
                      unit,
                    ),
                  ),
                  icon: LucideIcons.trendingUp,
                  colors: AppColors.lowStock,
                ),
            ],
          ),
          if (line.note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              line.note!,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// A réception as a panel, built like the commande's so the two read the
/// same way: header, one summary card, tabs, the lines down to the footer,
/// and two buttons. Everything else is an icon with a tooltip.
class _ReceiptPanel extends ConsumerStatefulWidget {
  const _ReceiptPanel({
    required this.storeId,
    required this.view,
    required this.panel,
  });

  final String storeId;
  final ReceiptDetailView view;
  final PanelController panel;

  @override
  ConsumerState<_ReceiptPanel> createState() => _ReceiptPanelState();
}

class _ReceiptPanelState extends ConsumerState<_ReceiptPanel> {
  static const _tabAll = 'all';
  static const _tabIssues = 'issues';

  String _tab = _tabAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final view = widget.view;
    final panel = widget.panel;
    final storeId = widget.storeId;
    final receipt = view.receipt;
    final orderView = ref.watch(orderDetailProvider(receipt.orderId)).value;
    final order = orderView?.order;
    final supplierName = orderView?.supplierName ?? '—';

    final issues = [
      for (final line in view.lines)
        if (_isOff(line)) line,
    ];
    final conform = issues.isEmpty;
    final verdict = conform ? AppColors.inStock : AppColors.lowStock;
    final lines = _tab == _tabIssues && !conform
        ? issues
        : [...issues, ...view.lines.where((line) => !_isOff(line))];
    final canReceive = order != null && orderCanReceive(order);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The same header as the commande's.
        Row(
          children: [
            if (panel.canGoBack) ...[
              IconButton(
                onPressed: panel.back,
                tooltip: l10n.actionBack,
                icon: const Icon(LucideIcons.arrowLeft, size: AppSizing.iconMd),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            SupplierMonogram(name: supplierName, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    supplierName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Flexible(
                        child: PanelReferenceCopy(reference: view.reference),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(
                        colors: verdict,
                        icon: conform
                            ? LucideIcons.circleCheck
                            : LucideIcons.triangleAlert,
                        label: conform
                            ? l10n.receptionsConform
                            : l10n.receptionsDiscrepancies(issues.length),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            ReceiptDocumentButton(receipt: receipt, compact: true),
            IconButton(
              onPressed: panel.close,
              tooltip: l10n.actionClose,
              icon: const Icon(LucideIcons.x, size: AppSizing.iconMd),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: PanelFillLayout(
            top: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReceiptHero(view: view),
                if (receipt.note != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  PanelNote(note: receipt.note!),
                ],
                const SizedBox(height: AppSpacing.lg),
                OrderPanelTabs(
                  current: conform ? _tabAll : _tab,
                  onSelected: (value) => setState(() => _tab = value),
                  tabs: [
                    OrderPanelTab(
                      id: _tabAll,
                      label: l10n.orderTabLines,
                      count: view.lines.length,
                    ),
                    if (!conform)
                      OrderPanelTab(
                        id: _tabIssues,
                        label: l10n.receiptPanelFilterIssues,
                        count: issues.length,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
            fill: (pinned) => PanelListCard(
              pinned: pinned,
              itemCount: lines.length,
              itemBuilder: (context, i) => _ReceiptPanelLine(view: lines[i]),
              footer: Row(
                children: [
                  Icon(
                    LucideIcons.packageCheck,
                    size: AppSizing.iconSm,
                    color: verdict.foreground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${view.lines.length - issues.length} / '
                      '${view.lines.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    Formatters.price(receiptValue(receipt)),
                    style: AppTypography.numeric.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // The same footer as the commande's: secondary left, primary right.
        Container(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: l10n.receiptPanelOpenOrder,
                  icon: LucideIcons.fileText,
                  fullWidth: true,
                  onPressed: () => openOrderPanel(
                    context,
                    storeId: storeId,
                    orderId: receipt.orderId,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: canReceive
                    ? PrimaryButton(
                        label: l10n.receiptPanelReceiveRest,
                        icon: LucideIcons.packageCheck,
                        fullWidth: true,
                        onPressed: () => context.pushScreen(
                          Routes.toReceiveOrder(storeId, order.id),
                        ),
                      )
                    : ReceiptDocumentButton.footer(
                        receipt: receipt,
                        prominent: true,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static bool _isOff(ReceiptLineView line) => isDiscrepancy(
    outcomeOf(
      ordered: line.line.quantityOrdered,
      received: line.line.quantityReceived,
      wasUnordered: line.line.wasUnordered,
    ),
  );
}

/// The summary card, shaped like the commande's: the value large, then who
/// received it and when on one line.
class _ReceiptHero extends StatelessWidget {
  const _ReceiptHero({required this.view});

  final ReceiptDetailView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final receipt = view.receipt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.receiptValueLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.price(receiptValue(receipt)),
                        style: AppTypography.numericHero,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: l10n.receiptReadOnlyNotice,
                child: const Icon(
                  LucideIcons.lock,
                  size: AppSizing.iconSm,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: EmployeeNameTag(
                  name: receipt.receivedByName,
                  employeeId: receipt.receivedByEmployeeId,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  avatarSize: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              MetaItem(
                icon: LucideIcons.calendarClock,
                label: Formatters.dateTime(receipt.receivedAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One delivered line, drawn like the commande's: photo, name with a status
/// icon, "received / ordered", then the money. What went wrong is the icon's
/// tooltip, not a sentence.
class _ReceiptPanelLine extends StatelessWidget {
  const _ReceiptPanelLine({required this.view});

  final ReceiptLineView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final line = view.line;
    final unit = view.unitAbbreviation;
    final outcome = outcomeOf(
      ordered: line.quantityOrdered,
      received: line.quantityReceived,
      wasUnordered: line.wasUnordered,
    );
    final off = isDiscrepancy(outcome);
    final note = line.note;

    final (IconData icon, String tip) = line.wasUnordered
        ? (LucideIcons.circlePlus, l10n.receiveUnorderedBadge)
        : outcome == ReceiptLineOutcome.short
        ? (
            line.closedShort ? LucideIcons.packageX : LucideIcons.clock,
            line.closedShort
                ? l10n.receiptClosedShortBadge
                : l10n.receiptShortBadge,
          )
        : outcome == ReceiptLineOutcome.over
        ? (
            LucideIcons.trendingUp,
            l10n.receiveOverBadge(
              Formatters.quantityWithUnit(
                line.quantityReceived - line.quantityOrdered,
                unit,
              ),
            ),
          )
        : (LucideIcons.circleCheck, l10n.receptionsConform);
    final color = off
        ? AppColors.lowStock.foreground
        : AppColors.inStock.foreground;

    final quantity = off && !line.wasUnordered
        ? '${Formatters.quantity(line.quantityReceived)} / '
              '${Formatters.quantityWithUnit(line.quantityOrdered, unit)}'
        : Formatters.quantityWithUnit(line.quantityReceived, unit);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          ProductImage(
            imagePath: view.imagePath,
            size: 44,
            radius: 10,
            placeholder: ProductImagePlaceholder.disc,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        view.itemName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Tooltip(
                      message: tip,
                      child: Icon(icon, size: 14, color: color),
                    ),
                    if (note != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Tooltip(
                        message: note,
                        child: const Icon(
                          LucideIcons.messageSquare,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  quantity,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: off
                        ? AppColors.lowStock.foreground
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.price(line.quantityReceived * line.actualUnitPrice),
                style: AppTypography.numeric.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '× ${Formatters.price(line.actualUnitPrice)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
