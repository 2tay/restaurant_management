import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/export_dialog.dart';

/// One item, every supplier's price side by side.
///
/// The app's headline feature. It exists because a restaurant with three
/// suppliers for chicken has no way, in any other tool they own, to see that
/// they have been buying from the dearest one for six months.
///
/// Opens on an item where the store is actually overpaying rather than on the
/// alphabetically first one — a report that opens on "you already have the best
/// price" teaches the user it has nothing to say.
class PriceComparisonReportPage extends ConsumerStatefulWidget {
  const PriceComparisonReportPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<PriceComparisonReportPage> createState() =>
      _PriceComparisonReportPageState();
}

class _PriceComparisonReportPageState
    extends ConsumerState<PriceComparisonReportPage> {
  String? _itemId;

  @override
  void initState() {
    super.initState();
    _itemId = _mostInterestingItem();
  }

  /// The item with the largest gap between its default and cheapest supplier,
  /// falling back to any multi-supplier item, then to the first item.
  String? _mostInterestingItem() {
    final items = MockQueries.itemsForStore(widget.storeId);
    if (items.isEmpty) return null;

    Item? best;
    var bestGap = 0.0;

    for (final item in items) {
      final gap = MockQueries.overpayPerUnit(item.id);
      if (gap > bestGap) {
        bestGap = gap;
        best = item;
      }
    }
    if (best != null) return best.id;

    for (final item in items) {
      if (MockQueries.pricesForItem(item.id).length > 1) return item.id;
    }
    return items.first.id;
  }

  @override
  Widget build(BuildContext context) {
    // Prices captured at receiving feed straight into this comparison.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);

    final items = MockQueries.itemsForStore(widget.storeId);
    final item = _itemId == null ? null : MockQueries.itemById(_itemId!);
    final prices = item == null
        ? <SupplierPrice>[]
        : MockQueries.pricesForItem(item.id);
    final cheapest = prices.isEmpty ? null : prices.first;
    final unit = item == null
        ? ''
        : MockQueries.unitAbbreviationOf(item.unitId);

    return ShellPage(
      back: BackDestination(
        label: l10n.reportsTitle,
        path: Routes.toReports(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.reportsTitle, Routes.toReports(widget.storeId)),
        Crumb(l10n.comparisonTitle),
      ],
      title: l10n.comparisonTitle,
      subtitle: l10n.comparisonSubtitle,
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AppCard(
              child: AppDropdown<String>(
                label: l10n.comparisonPickItem,
                value: _itemId,
                options: [
                  for (final i in items)
                    DropdownOption(
                      value: i.id,
                      label: i.name,
                      secondaryLabel: l10n.suppliersProductCount(
                        MockQueries.pricesForItem(i.id).length,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _itemId = value),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (item == null)
            AppCard(
              child: EmptyState(
                icon: LucideIcons.scale,
                title: l10n.emptyStateNoItemsTitle,
                message: l10n.emptyStateNoItemsBody,
              ),
            )
          else if (prices.length < 2)
            AppCard(
              child: EmptyState(
                icon: LucideIcons.scale,
                title: l10n.comparisonSingleSupplier,
                message: l10n.comparisonSingleSupplierBody,
                actionLabel: l10n.itemLinkSupplier,
                actionIcon: LucideIcons.plus,
                onAction: () => context.pushScreen(
                  Routes.toLinkSupplier(widget.storeId, item.id),
                ),
              ),
            )
          else ...[
            if (MockQueries.overpayPerUnit(item.id) > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _SavingCallout(
                  item: item,
                  unit: unit,
                  cheapest: cheapest!,
                ),
              ),
            DataTableWrapper(
              minWidth: 760,
              columns: [
                DataColumn(label: Text(l10n.comparisonColumnSupplier)),
                DataColumn(
                  label: Text(l10n.comparisonColumnPrice),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(l10n.comparisonColumnDifference),
                  numeric: true,
                ),
                DataColumn(label: Text(l10n.comparisonColumnUpdated)),
              ],
              rows: [
                for (final price in prices)
                  _row(context, l10n, price, cheapest!, unit, item.id),
              ],
            ),
          ],
        ],
      ),
    );
  }

  DataRow _row(
    BuildContext context,
    AppLocalizations l10n,
    SupplierPrice price,
    SupplierPrice cheapest,
    String unit,
    String itemId,
  ) {
    final isCheapest = price.id == cheapest.id;
    final gap = price.pricePerUnit - cheapest.pricePerUnit;

    return DataRow(
      // Tints the row the store is currently buying from, so the comparison is
      // "here is what you do" against "here is what is available".
      color: price.isDefault
          ? WidgetStatePropertyAll(
              isCheapest
                  ? AppColors.inStock.container
                  : AppColors.lowStock.container,
            )
          : null,
      onSelectChanged: (_) => context.pushScreen(
        Routes.toPriceHistory(widget.storeId, itemId, price.supplierId),
      ),
      cells: [
        DataCell(
          Row(
            children: [
              Flexible(
                child: Text(
                  MockQueries.supplierNameOf(price.supplierId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (price.isDefault) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  LucideIcons.star,
                  size: 14,
                  color: AppColors.onPrimaryContainer,
                ),
              ],
            ],
          ),
        ),
        DataCell(
          NumericCell(
            '${Formatters.price(price.pricePerUnit)} / $unit',
            emphasis: isCheapest,
          ),
        ),
        DataCell(
          isCheapest
              ? Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.itemCheapest,
                    style: AppTypography.numericSmall.copyWith(
                      color: AppColors.inStock.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : NumericCell(
                  '+${Formatters.price(gap)}',
                  style: AppTypography.numeric.copyWith(
                    color: AppColors.lowStock.foreground,
                  ),
                ),
        ),
        DataCell(Text(Formatters.date(price.effectiveDate))),
      ],
    );
  }
}

/// States the overpayment in euros per unit, and names the alternative.
class _SavingCallout extends StatelessWidget {
  const _SavingCallout({
    required this.item,
    required this.unit,
    required this.cheapest,
  });

  final Item item;
  final String unit;
  final SupplierPrice cheapest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gap = MockQueries.overpayPerUnit(item.id);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.lowStock.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.trendingUp,
            size: AppSizing.iconLg,
            color: AppColors.lowStock.foreground,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.itemOverpayWarning(
                Formatters.price(gap),
                unit,
                MockQueries.supplierNameOf(cheapest.supplierId),
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.lowStock.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
