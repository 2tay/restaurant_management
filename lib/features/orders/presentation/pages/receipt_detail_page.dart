import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../documents/receipt_document_button.dart';
import '../widgets/order_summary_card.dart';

/// One delivery, as recorded.
///
/// Read-only, and deliberately has no edit or delete action anywhere on it. A
/// confirmed receipt is what the stock movements point back to; changing it
/// after the fact would silently rewrite history that somebody may already have
/// acted on. Corrections go through a stock adjustment instead, which leaves
/// both the original and the correction visible.
///
/// Reachable from the order it belongs to and from any stock movement it
/// generated, which is what closes the trail: quantity → movement → receipt →
/// order → supplier.
class ReceiptDetailPage extends ConsumerWidget {
  const ReceiptDetailPage({
    required this.storeId,
    required this.receiptId,
    super.key,
  });

  final String storeId;
  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(receiptDetailProvider(receiptId));
    final view = detail.value;

    if (view == null) {
      return ShellPage(
        title: l10n.ordersTitle,
        child: detail.isLoading
            ? const SkeletonList(rows: 3, rowHeight: 110)
            : ErrorState(
                message: l10n.errorStateBody,
                onRetry: () => context.goSection(Routes.toOrders(storeId)),
              ),
      );
    }

    final receipt = view.receipt;
    final reference = view.orderReference;
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

    return ShellPage(
      back: BackDestination(
        label: reference,
        path: Routes.toOrder(storeId, receipt.orderId),
      ),
      crumbs: [
        Crumb(l10n.ordersTitle, Routes.toOrders(storeId)),
        Crumb(reference, Routes.toOrder(storeId, receipt.orderId)),
        Crumb(l10n.orderTabReceipts),
      ],
      title: l10n.receiptDetailTitle(Formatters.dateLong(receipt.receivedAt)),
      // The document reference is on screen because the phone call that follows
      // an emailed bon de réception starts with the supplier quoting it back.
      subtitle:
          '${view.reference} · '
          '${l10n.receiptReceivedBy(receipt.receivedByName)}',
      actions: [
        SecondaryButton(
          label: l10n.receiptOrderReference(reference),
          icon: LucideIcons.clipboardList,
          onPressed: () =>
              context.pushScreen(Routes.toOrder(storeId, receipt.orderId)),
        ),
        // The primary action on a read-only screen. There is nothing to edit
        // here, and getting the record out of the app and to the supplier is
        // the only thing anybody comes to this page to do.
        ReceiptDocumentButton(receipt: receipt),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          DataTableWrapper(
            minWidth: 900,
            columns: [
              DataColumn(label: Text(l10n.orderColumnItem)),
              DataColumn(label: Text(l10n.receiveColumnOrdered), numeric: true),
              DataColumn(
                label: Text(l10n.receiveColumnReceived),
                numeric: true,
              ),
              DataColumn(label: Text(l10n.orderColumnUnitPrice), numeric: true),
              DataColumn(label: Text(l10n.receiptColumnNote)),
            ],
            rows: [for (final line in view.lines) _row(context, l10n, line)],
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
      ),
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
