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
import '../../../../data/view_models/view_models.dart';
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
  /// Prices being typed, keyed by article id.
  ///
  /// Only what is in the field right now. A committed price goes to the
  /// database and comes back through the query, so this holds a keystroke
  /// rather than a state of the world.
  final Map<String, double> _edited = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Receiving a delivery can change a price this screen is editing, and the
    // row follows it: the query watches the table the delivery writes to.
    final supplier = ref.watch(supplierProvider(widget.supplierId)).value;
    final products =
        ref.watch(supplierProductsProvider(widget.supplierId)).value ??
        const <SupplierProductView>[];

    if (supplier == null) {
      return ShellPage(
        title: l10n.supplierPricingTitle,
        child: ref.watch(supplierProvider(widget.supplierId)).isLoading
            ? const SkeletonList(rows: 4, rowHeight: 76)
            : ErrorState(
                onRetry: () =>
                    context.goSection(Routes.toSuppliers(widget.storeId)),
              ),
      );
    }

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
      child: products.isEmpty
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
                for (final product in products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PriceEditRow(
                      // Keyed on the offer so a price arriving from a delivery
                      // rebuilds the field rather than leaving the old number
                      // in it.
                      key: ValueKey(product.price.id),
                      product: product,
                      editedValue: _edited[product.price.itemId],
                      onChanged: (value) => setState(
                        () => _edited[product.price.itemId] = value,
                      ),
                      onCommit: (value) => _commit(product, value),
                      onViewHistory: () => context.pushScreen(
                        Routes.toPriceHistory(
                          widget.storeId,
                          product.price.itemId,
                          widget.supplierId,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _commit(SupplierProductView product, double value) async {
    final price = product.price;
    if ((value - price.pricePerUnit).abs() < 0.001) return;

    // Writes a price-history entry for this item-supplier pair as well as
    // moving the current price — the same path receiving a delivery takes, so
    // the history reads the same however the change arrived.
    await ref.read(supplierRepositoryProvider).updatePrice(price.id, value);

    if (!mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).priceUpdated);
  }
}

/// One editable price line.
class _PriceEditRow extends StatefulWidget {
  const _PriceEditRow({
    required this.product,
    required this.editedValue,
    required this.onChanged,
    required this.onCommit,
    required this.onViewHistory,
    super.key,
  });

  final SupplierProductView product;
  final double? editedValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;
  final VoidCallback onViewHistory;

  @override
  State<_PriceEditRow> createState() => _PriceEditRowState();
}

class _PriceEditRowState extends State<_PriceEditRow> {
  late final TextEditingController _controller = TextEditingController(
    text: Formatters.quantity(
      widget.editedValue ?? widget.product.price.pricePerUnit,
    ),
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

    final price = widget.product.price;
    final unit = widget.product.unitAbbreviation;

    // Measured against what is typed rather than what is stored, so the "le
    // moins cher" badge answers the number under the cursor.
    final current = widget.editedValue ?? price.pricePerUnit;
    final gap = current - widget.product.cheapestPricePerUnit;
    final isCheapest = gap.abs() < 0.001 || gap < 0;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      // Four columns of fixed and flex widths that only add up above about
      // 700dp. Below that the name, the price field and the comparison each
      // take their own line rather than squeezing the editable field to
      // nothing.
      child: AdaptiveRow(
        breakpoint: 700,
        cells: [
          AdaptiveCell(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.itemName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.itemPriceUpdated(Formatters.date(price.effectiveDate)),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AdaptiveCell(
            flex: 3,
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
          AdaptiveCell(
            flex: 3,
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
          AdaptiveCell(
            child: IconButton(
              onPressed: widget.onViewHistory,
              icon: const Icon(LucideIcons.chartLine),
              tooltip: l10n.itemViewPriceHistory,
            ),
          ),
        ],
      ),
    );
  }
}
