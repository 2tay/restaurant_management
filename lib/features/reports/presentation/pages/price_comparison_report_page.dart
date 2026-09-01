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
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
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

  /// Whether the screen has already chosen what to open on.
  ///
  /// The choice is a query — the article with the biggest gap between what the
  /// establishment pays and what it could — and `initState` cannot wait for
  /// one. Phase 1 answered it by scanning every article in the establishment
  /// from `initState`, which is a report query that had leaked into a widget.
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Prices captured at receiving feed straight into this comparison, and
    // both queries watch the tables receiving writes to.
    final rows =
        ref.watch(itemRowsProvider((
              storeId: widget.storeId,
              filter: ItemFilter.none,
            ))).value ??
        const <ItemRowView>[];

    if (!_opened && rows.isNotEmpty) {
      final suggested = ref.watch(
        largestOverpayItemProvider(widget.storeId),
      );
      if (suggested.hasValue) {
        _opened = true;
        // Falls back to the first article when nothing is overpaid, so the
        // screen opens on something rather than on an empty picker.
        _itemId = suggested.value ?? rows.first.item.id;
      }
    }

    ItemRowView? row;
    for (final candidate in rows) {
      if (candidate.item.id == _itemId) row = candidate;
    }

    final item = row?.item;
    final unit = row?.unitAbbreviation ?? '';
    final pricing = item == null
        ? null
        : ref.watch(itemPricingProvider(item.id)).value;
    final prices = pricing?.prices ?? const <SupplierPriceView>[];
    final cheapest = pricing?.cheapest;
    final overpay = pricing?.overpayPerUnit ?? 0;

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
                  for (final candidate in rows)
                    DropdownOption(
                      value: candidate.item.id,
                      label: candidate.item.name,
                      secondaryLabel: candidate.categoryName,
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
            if (overpay > 0 && cheapest != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _SavingCallout(
                  gap: overpay,
                  unit: unit,
                  cheapestSupplier: cheapest.supplierName,
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
                for (final view in prices)
                  _row(context, l10n, view, cheapest!, unit, item.id),
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
    SupplierPriceView view,
    SupplierPriceView cheapest,
    String unit,
    String itemId,
  ) {
    final price = view.price;
    final isCheapest = price.id == cheapest.price.id;
    final gap = price.pricePerUnit - cheapest.price.pricePerUnit;

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
                  view.supplierName,
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
    required this.gap,
    required this.unit,
    required this.cheapestSupplier,
  });

  final double gap;
  final String unit;
  final String cheapestSupplier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                cheapestSupplier,
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
