import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import 'order_summary_card.dart';
import 'panel_header.dart';

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

    if (panel == null) return body;

    return PanelScaffold(
      panel: panel!,
      title: l10n.receiptDetailTitle(Formatters.dateLong(receipt.receivedAt)),
      subtitle:
          '${view.reference} · '
          '${l10n.receiptReceivedBy(receipt.receivedByName)}',
      actions: [ReceiptDocumentButton(receipt: receipt)],
      child: body,
    );
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
