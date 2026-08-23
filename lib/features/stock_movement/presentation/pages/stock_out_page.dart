import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/movement_labels.dart';

/// Record stock leaving: sold, used, wasted or transferred.
///
/// The reason is a row of large chips rather than a dropdown. This is the
/// screen used most often mid-service, the options never change, and one tap
/// beats open-scroll-select every time.
class StockOutPage extends StatefulWidget {
  const StockOutPage({required this.storeId, super.key});

  final String storeId;

  @override
  State<StockOutPage> createState() => _StockOutPageState();
}

class _StockOutPageState extends State<StockOutPage> {
  String? _itemId;
  double _quantity = 1;
  StockOutReason _reason = StockOutReason.sale;

  Item? get _item => _itemId == null ? null : MockQueries.itemById(_itemId!);

  bool get _canSubmit => _itemId != null && _quantity > 0;

  bool get _exceedsStock {
    final item = _item;
    return item != null && _quantity > item.quantity;
  }

  bool get _isDirty => _itemId != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final item = _item;
    final unit = item == null
        ? ''
        : MockQueries.unitAbbreviationOf(item.unitId);

    final items = MockQueries.itemsForStore(widget.storeId)
        .map(
          (i) => DropdownOption(
            value: i.id,
            label: i.name,
            secondaryLabel: Formatters.quantityWithUnit(
              i.quantity,
              MockQueries.unitAbbreviationOf(i.unitId),
            ),
          ),
        )
        .toList();

    return FormScaffold(
      title: l10n.stockOutTitle,
      subtitle: l10n.stockOutSubtitle,
      back: BackDestination(
        label: l10n.movementsTitle,
        path: Routes.toMovements(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.movementsTitle, Routes.toMovements(widget.storeId)),
        Crumb(l10n.stockOutTitle),
      ],
      submitLabel: l10n.stockOutSubmit,
      submitIcon: LucideIcons.arrowUpFromLine,
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _isDirty,
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: AppDropdown<String>(
              label: l10n.stockInItem,
              value: _itemId,
              options: items,
              onChanged: (value) => setState(() => _itemId = value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.stockOutQuantity,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    if (item != null)
                      Text(
                        l10n.stockOutAvailable(
                          Formatters.quantityWithUnit(item.quantity, unit),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                QuantityStepper(
                  value: _quantity,
                  unitAbbreviation: unit,
                  onChanged: (value) => setState(() => _quantity = value),
                ),
                if (_exceedsStock) ...[
                  const SizedBox(height: AppSpacing.md),
                  // A warning rather than a hard block: stock counts drift,
                  // and refusing to record something that actually left the
                  // building would make the data worse, not better.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.lowStock.container,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.triangleAlert,
                          size: AppSizing.iconMd,
                          color: AppColors.lowStock.foreground,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.stockOutExceedsStock,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.lowStock.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.stockOutReason, style: theme.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final reason in StockOutReason.values)
                      _ReasonChip(
                        reason: reason,
                        selected: _reason == reason,
                        onTap: () => setState(() => _reason = reason),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);

    // Recorded as entered even when it takes the item below zero. The warning
    // above is the whole intervention: refusing would make staff either lie to
    // the app or stop using it, and negative stock is itself a useful signal
    // that a delivery went unrecorded.
    MovementMutations.recordStockOut(
      storeId: widget.storeId,
      itemId: _itemId!,
      quantity: _quantity,
      reason: _reason,
    );

    AppSnackBar.success(context, l10n.stockOutRecorded);
    context.goSection(Routes.toMovements(widget.storeId));
  }
}

/// A large, single-tap reason selector.
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final StockOutReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        height: AppSizing.buttonHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? AppColors.primary600 : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reasonIcon(reason),
              size: AppSizing.iconMd,
              color: selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              reasonLabel(l10n, reason),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? AppColors.onPrimaryContainer
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
