import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../shared/widgets/widgets.dart';

/// Attach a supplier to an item, with that supplier's price.
///
/// This is where the item–supplier link is created, and therefore the only
/// place a price is ever entered for an item. Suppliers already linked are
/// excluded from the picker — linking the same supplier twice would produce two
/// competing prices for the same pair.
class LinkSupplierToItemPage extends ConsumerStatefulWidget {
  const LinkSupplierToItemPage({
    required this.storeId,
    required this.itemId,
    super.key,
  });

  final String storeId;
  final String itemId;

  @override
  ConsumerState<LinkSupplierToItemPage> createState() =>
      _LinkSupplierToItemPageState();
}

class _LinkSupplierToItemPageState
    extends ConsumerState<LinkSupplierToItemPage> {
  final _priceController = TextEditingController();
  String? _supplierId;
  bool _setAsDefault = false;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _supplierId != null && _priceController.text.trim().isNotEmpty;

  bool get _isDirty =>
      _supplierId != null || _priceController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final row = ref.watch(itemRowProvider(widget.itemId)).value;
    final pricing = ref.watch(itemPricingProvider(widget.itemId)).value;

    if (row == null || pricing == null) {
      final loading =
          ref.watch(itemRowProvider(widget.itemId)).isLoading ||
          ref.watch(itemPricingProvider(widget.itemId)).isLoading;

      return ShellPage(
        title: l10n.linkSupplierTitle,
        back: BackDestination(
          label: l10n.inventoryTitle,
          path: Routes.toInventory(widget.storeId),
        ),
        child: loading
            ? const SkeletonList(rows: 3, rowHeight: 90)
            : ErrorState(
                onRetry: () =>
                    context.goSection(Routes.toInventory(widget.storeId)),
              ),
      );
    }

    final item = row.item;
    final unit = row.unitAbbreviation;

    // Suppliers this article is already linked to are left out of the menu
    // rather than offered and then refused — linking the same pair twice is
    // the one thing the write below cannot do.
    final alreadyLinked = {
      for (final entry in pricing.prices) entry.price.supplierId,
    };

    final available = <DropdownOption<String>>[
      for (final supplier
          in ref.watch(suppliersProvider(widget.storeId)).value ?? const [])
        if (!alreadyLinked.contains(supplier.id))
          DropdownOption(
            value: supplier.id,
            label: supplier.name,
            secondaryLabel: supplier.city,
          ),
    ];

    return FormScaffold(
      title: l10n.linkSupplierTitle,
      subtitle: l10n.linkSupplierFor(item.name),
      // Information, not description — kept on a phone.
      keepSubtitle: true,
      back: BackDestination(
        label: item.name,
        path: Routes.toItem(widget.storeId, item.id),
      ),
      crumbs: [
        Crumb(l10n.inventoryTitle, Routes.toInventory(widget.storeId)),
        Crumb(item.name, Routes.toItem(widget.storeId, item.id)),
        Crumb(l10n.linkSupplierTitle),
      ],
      submitLabel: l10n.linkSupplierSubmit,
      submitIcon: LucideIcons.link2,
      onSubmit: _canSubmit ? () => _submit(item.id) : null,
      isDirty: _isDirty,
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppDropdown<String>(
                  label: l10n.linkSupplierPick,
                  value: _supplierId,
                  options: available,
                  onChanged: (value) => setState(() => _supplierId = value),
                  onCreateNew: () =>
                      context.pushScreen(Routes.toAddSupplier(widget.storeId)),
                  createNewLabel: l10n.linkSupplierCreate,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField.currency(
                  label: l10n.linkSupplierPrice(unit),
                  controller: _priceController,
                  helperText: l10n.linkSupplierPriceHelp,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Switch(
                  value: _setAsDefault,
                  onChanged: (value) => setState(() => _setAsDefault = value),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.linkSupplierSetDefault,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.linkSupplierSetDefaultHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Shows what this supplier would cost against the current cheapest,
          // while the price is still being typed. Cheaper to reconsider now
          // than after the link exists.
          if (_canSubmit) ...[
            const SizedBox(height: AppSpacing.lg),
            _PriceComparisonHint(
              itemId: item.id,
              unit: unit,
              enteredPrice: _parsedPrice,
            ),
          ],
        ],
      ),
    );
  }

  double? get _parsedPrice =>
      double.tryParse(_priceController.text.replaceAll(',', '.').trim());

  Future<void> _submit(String itemId) async {
    final l10n = AppLocalizations.of(context);

    await ref
        .read(supplierRepositoryProvider)
        .linkItem(
          itemId: itemId,
          supplierId: _supplierId!,
          pricePerUnit: _parsedPrice ?? 0,
        );

    if (!mounted) return;
    AppSnackBar.success(context, l10n.supplierLinked);
    context.pushScreen(Routes.toItem(widget.storeId, itemId));
  }
}

class _PriceComparisonHint extends ConsumerWidget {
  const _PriceComparisonHint({
    required this.itemId,
    required this.unit,
    required this.enteredPrice,
  });

  final String itemId;
  final String unit;
  final double? enteredPrice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Silent until the pricing is in hand. A hint that cannot compare has
    // nothing to say, and saying it late is better than saying it wrong.
    final cheapest = ref.watch(itemPricingProvider(itemId)).value?.cheapest;
    final price = enteredPrice;
    if (cheapest == null || price == null) return const SizedBox.shrink();

    final difference = price - cheapest.price.pricePerUnit;
    final isBetter = difference < 0;
    final supplierName = cheapest.supplierName;

    final l10n = AppLocalizations.of(context);
    final colors = isBetter ? AppColors.inStock : AppColors.lowStock;
    final message = isBetter
        ? l10n.linkSupplierCheaperThan(
            supplierName,
            Formatters.price(difference.abs()),
            unit,
          )
        : difference == 0
        ? l10n.linkSupplierSamePriceAs(supplierName)
        : l10n.linkSupplierDearerThan(
            supplierName,
            Formatters.price(difference),
            unit,
          );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            isBetter ? LucideIcons.trendingDown : LucideIcons.trendingUp,
            color: colors.foreground,
            size: AppSizing.iconMd,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
