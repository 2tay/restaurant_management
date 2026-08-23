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

/// The editable price table for one supplier.
///
/// Changing a price here is what creates a price history entry — the screen
/// says so above the table, because a price edit that silently produces an
/// audit record is a surprise, and a price edit that produces nothing makes
/// the history screen a mystery.
class SupplierPricingPage extends ConsumerStatefulWidget {
  const SupplierPricingPage({
    required this.storeId,
    required this.supplierId,
    super.key,
  });

  final String storeId;
  final String supplierId;

  @override
  ConsumerState<SupplierPricingPage> createState() =>
      _SupplierPricingPageState();
}

class _SupplierPricingPageState extends ConsumerState<SupplierPricingPage> {
  /// Prices edited in this session, keyed by item id. Phase 1 persists nothing,
  /// so the table reflects local edits only until the screen is left.
  final Map<String, double> _edited = {};

  @override
  Widget build(BuildContext context) {
    // Receiving a delivery can change a price this screen is editing.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);
    final supplier = MockQueries.supplierById(widget.supplierId);

    if (supplier == null) {
      return ShellPage(
        title: l10n.supplierPricingTitle,
        child: ErrorState(
          onRetry: () => context.goSection(Routes.toSuppliers(widget.storeId)),
        ),
      );
    }

    final prices = MockQueries.pricesForSupplier(widget.supplierId);

    return ShellPage(
      back: BackDestination(
        label: supplier.name,
        path: Routes.toSupplier(widget.storeId, widget.supplierId),
      ),
      crumbs: [
        Crumb(l10n.suppliersTitle, Routes.toSuppliers(widget.storeId)),
        Crumb(
          supplier.name,
          Routes.toSupplier(widget.storeId, widget.supplierId),
        ),
        Crumb(l10n.supplierPricingTitle),
      ],
      title: l10n.supplierPricingTitle,
      subtitle: '${supplier.name} — ${l10n.supplierPricingSubtitle}',
      child: prices.isEmpty
          ? AppCard(
              child: EmptyState(
                icon: LucideIcons.scale,
                title: l10n.supplierProductsEmpty,
                message: l10n.itemNoSuppliersBody,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final price in prices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PriceEditRow(
                      price: price,
                      supplierId: widget.supplierId,
                      editedValue: _edited[price.itemId],
                      onChanged: (value) =>
                          setState(() => _edited[price.itemId] = value),
                      onCommit: (value) => _commit(price, value),
                      onViewHistory: () => context.pushScreen(
                        Routes.toPriceHistory(
                          widget.storeId,
                          price.itemId,
                          widget.supplierId,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _commit(SupplierPrice price, double value) {
    if ((value - price.pricePerUnit).abs() < 0.001) return;
    AppSnackBar.success(context, AppLocalizations.of(context).priceUpdated);
  }
}

/// One editable price line.
class _PriceEditRow extends StatefulWidget {
  const _PriceEditRow({
    required this.price,
    required this.supplierId,
    required this.editedValue,
    required this.onChanged,
    required this.onCommit,
    required this.onViewHistory,
  });

  final SupplierPrice price;
  final String supplierId;
  final double? editedValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;
  final VoidCallback onViewHistory;

  @override
  State<_PriceEditRow> createState() => _PriceEditRowState();
}

class _PriceEditRowState extends State<_PriceEditRow> {
  late final TextEditingController _controller = TextEditingController(
    text: Formatters.quantity(widget.editedValue ?? widget.price.pricePerUnit),
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Commit on blur rather than on every keystroke: a snackbar per character
    // would be unusable.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        final parsed = double.tryParse(
          _controller.text.replaceAll(',', '.').trim(),
        );
        if (parsed != null) widget.onCommit(parsed);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final item = MockQueries.itemById(widget.price.itemId);
    final unit = item == null
        ? ''
        : MockQueries.unitAbbreviationOf(item.unitId);

    final cheapest = MockQueries.cheapestPriceForItem(widget.price.itemId);
    final isCheapest = cheapest?.supplierId == widget.supplierId;
    final current = widget.editedValue ?? widget.price.pricePerUnit;
    final gap = cheapest == null ? 0.0 : current - cheapest.pricePerUnit;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?.name ?? '—',
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.itemPriceUpdated(
                    Formatters.date(widget.price.effectiveDate),
                  ),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          SizedBox(
            width: 180,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.right,
              style: AppTypography.numeric,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (raw) {
                final parsed = double.tryParse(raw.replaceAll(',', '.').trim());
                if (parsed != null) widget.onChanged(parsed);
              },
              decoration: InputDecoration(
                suffixText: '€ / $unit',
                suffixStyle: theme.textTheme.bodySmall,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          SizedBox(
            width: 150,
            child: isCheapest
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        LucideIcons.trendingDown,
                        size: AppSizing.iconSm,
                        color: AppColors.inStock.foreground,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          l10n.supplierPricingBest,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.inStock.foreground,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    gap > 0 ? '+${Formatters.price(gap)}' : '—',
                    textAlign: TextAlign.right,
                    style: AppTypography.numericSmall.copyWith(
                      color: gap > 0
                          ? AppColors.lowStock.foreground
                          : AppColors.textSecondary,
                    ),
                  ),
          ),
          IconButton(
            onPressed: widget.onViewHistory,
            icon: const Icon(LucideIcons.chartLine),
            tooltip: l10n.itemViewPriceHistory,
          ),
        ],
      ),
    );
  }
}
