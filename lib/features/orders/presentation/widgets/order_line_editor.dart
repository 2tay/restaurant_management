import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'already_on_order_badge.dart';

/// One line of an order while it is being built.
///
/// Mutable, and owns its price controller, because the price field has to be
/// typed into rather than stepped and a controller per line is the only way
/// that stays correct when lines are added and removed above it.
///
/// The page that holds these is responsible for disposing them.
class OrderLineDraft {
  OrderLineDraft({
    required this.id,
    required this.itemId,
    required this.quantity,
    required double unitPrice,
  }) : priceController = TextEditingController(
         text: Formatters.quantity(unitPrice),
       );

  final String id;
  String itemId;
  double quantity;

  final TextEditingController priceController;

  /// The typed price, or zero if the field is empty or unparseable.
  ///
  /// Accepts a comma decimal separator, because that is what a Belgian keyboard
  /// and a Belgian brain both produce.
  double get unitPrice =>
      double.tryParse(priceController.text.replaceAll(',', '.').trim()) ?? 0;

  double get total => quantity * unitPrice;

  /// Refills the price after the supplier changes, or when the item does.
  void setPrice(double value) {
    priceController.text = Formatters.quantity(value);
  }

  void dispose() => priceController.dispose();

  PurchaseOrderLine toLine() => PurchaseOrderLine(
    id: id,
    itemId: itemId,
    quantityOrdered: quantity,
    unitPrice: unitPrice,
  );
}

/// The editor for one [OrderLineDraft].
///
/// The unit is inherited from the item and read-only — an order is placed in
/// whatever the kitchen counts in, and letting somebody order 12 of something
/// measured in kilos when they meant crates is a mistake worth making
/// structurally impossible.
class OrderLineEditor extends StatelessWidget {
  const OrderLineEditor({
    required this.draft,
    required this.storeId,
    required this.supplierId,
    required this.itemOptions,
    required this.onItemChanged,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
    super.key,
  });

  final OrderLineDraft draft;
  final String storeId;
  final String supplierId;

  /// Only items this supplier actually supplies, minus the ones already on the
  /// order. Built by the page so it can exclude the other lines' choices.
  final List<DropdownOption<String>> itemOptions;

  final ValueChanged<String?> onItemChanged;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onPriceChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final item = MockQueries.itemById(draft.itemId);
    final unit = item == null
        ? ''
        : MockQueries.unitAbbreviationOf(item.unitId);

    final picker = AppDropdown<String>(
      label: l10n.orderLinePickerLabel,
      value: draft.itemId,
      options: itemOptions,
      onChanged: onItemChanged,
    );

    final quantity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.orderLineQuantity, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        QuantityStepper(
          value: draft.quantity,
          unitAbbreviation: unit,
          onChanged: onQuantityChanged,
        ),
      ],
    );

    final price = SizedBox(
      width: 170,
      child: AppTextField.currency(
        label: l10n.orderLineUnitPrice(unit.isEmpty ? '—' : unit),
        controller: draft.priceController,
        onChanged: (_) => onPriceChanged(),
      ),
    );

    final total = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(l10n.orderLineTotal, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppSizing.inputHeight,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              Formatters.price(draft.total),
              style: AppTypography.numericMedium,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );

    final remove = Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: IconButton(
        onPressed: onRemove,
        tooltip: l10n.orderRemoveLine,
        icon: const Icon(LucideIcons.trash2),
        color: AppColors.textSecondary,
        constraints: const BoxConstraints(
          minWidth: AppSizing.minTapTarget,
          minHeight: AppSizing.minTapTarget,
        ),
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // The stepper alone is 276dp. Four controls plus French labels
              // do not fit one row on a small tablet, so below this they take
              // two rows rather than being squeezed to unreadable.
              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: picker),
                        remove,
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.lg,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [quantity, price, total],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: picker),
                  const SizedBox(width: AppSpacing.lg),
                  quantity,
                  const SizedBox(width: AppSpacing.lg),
                  price,
                  const SizedBox(width: AppSpacing.lg),
                  SizedBox(width: 120, child: total),
                  remove,
                ],
              );
            },
          ),

          // The double-order guard. The condition is checked here rather than
          // left to the badge so a line with nothing in transit does not carry
          // an empty gap where the badge would have been.
          if (item != null &&
              MockQueries.onOrderQuantity(storeId, item.id) > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: AlreadyOnOrderBadge(
                storeId: storeId,
                itemId: item.id,
                unitAbbreviation: unit,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
