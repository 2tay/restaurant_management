import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/export_dialog.dart';

/// What the stock on hand is worth.
///
/// States its basis on screen: each item is valued at its **default** supplier's
/// price. With several prices per item the total would otherwise be ambiguous,
/// and an unexplained number in a financial report is a number nobody trusts.
class StockValuationReportPage extends ConsumerWidget {
  const StockValuationReportPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Valuation is quantity times price, and both move.
    // Every figure below is one query. The two breakdowns each carry their
    // rows' share of the total, computed in the same pass that summed it.
    final valuation = ref.watch(stockValuationProvider(storeId)).value ?? 0;
    final byCategory =
        ref.watch(valuationByCategoryProvider(storeId)).value ??
        const <ValuationRow>[];
    final byItem =
        ref.watch(valuationByItemProvider(storeId)).value ??
        const <ValuationRow>[];

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ShellPage(
      back: BackDestination(
        label: l10n.reportsTitle,
        path: Routes.toReports(storeId),
      ),
      crumbs: [
        Crumb(l10n.reportsTitle, Routes.toReports(storeId)),
        Crumb(l10n.valuationTitle),
      ],
      title: l10n.valuationTitle,
      subtitle: l10n.valuationBasis,
      actions: [
        SecondaryButton(
          label: l10n.actionExport,
          icon: LucideIcons.download,
          onPressed: () => ExportDialog.show(context),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.wallet,
                    size: 26,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.valuationTotal,
                        style: theme.textTheme.labelMedium,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.price(
                            valuation,
                          ),
                          style: theme.textTheme.displaySmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Says which of the two prices this total is built on.
                      // Without it, an owner who watched a supplier put their
                      // price up and saw this figure not move would reasonably
                      // conclude the report was broken.
                      Text(
                        l10n.valuationAtCost,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.valuationByCategory),
          DataTableWrapper(
            minWidth: 720,
            columns: [
              DataColumn(label: Text(l10n.valuationColumnCategory)),
              DataColumn(label: Text(l10n.valuationColumnItems), numeric: true),
              DataColumn(label: Text(l10n.valuationColumnValue), numeric: true),
              DataColumn(label: Text(l10n.valuationColumnShare)),
            ],
            rows: [
              for (final row in byCategory)
                _row(context, row),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.valuationByItem),
          DataTableWrapper(
            minWidth: 720,
            columns: [
              DataColumn(label: Text(l10n.supplierPricingColumnProduct)),
              DataColumn(label: Text(l10n.itemQuantityLabel), numeric: true),
              DataColumn(label: Text(l10n.valuationColumnValue), numeric: true),
              DataColumn(label: Text(l10n.valuationColumnShare)),
            ],
            rows: [
              for (final row in byItem)
                _row(context, row),
            ],
          ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, ValuationRow row) {
    return DataRow(
      cells: [
        DataCell(Text(row.label)),
        DataCell(NumericCell('${row.itemCount}')),
        DataCell(NumericCell(Formatters.price(row.totalValue))),
        DataCell(_ShareBar(share: row.shareOfTotal)),
      ],
    );
  }
}

/// A share-of-total bar with its percentage beside it.
///
/// The bar makes the ranking scannable; the number makes it precise. Either
/// alone leaves the reader doing work.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.neutral100,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary600),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(Formatters.percent(share), style: AppTypography.numericSmall),
      ],
    );
  }
}
