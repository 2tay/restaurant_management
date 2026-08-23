import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Receive a delivery.
///
/// The interesting interaction in the app: **picking a supplier auto-fills that
/// supplier's current price, and the field stays editable.** Both halves
/// matter. Auto-filling removes the typing the brief asks us to avoid; keeping
/// it editable acknowledges that the invoice sometimes disagrees with the price
/// on file, and when it does the difference is what feeds the price history.
///
/// Pre-selects the item's default supplier, so the common case is: pick item,
/// tap +, save.
class StockInPage extends StatefulWidget {
  const StockInPage({required this.storeId, super.key});

  final String storeId;

  @override
  State<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends State<StockInPage> {
  final _priceController = TextEditingController();

  String? _itemId;
  String? _supplierId;
  double _quantity = 1;
  DateTime _date = DateTime.now();

  /// The price on file for the current item–supplier pair, so the form can tell
  /// whether the user has since edited it.
  double? _autofilledPrice;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Item? get _item => _itemId == null ? null : MockQueries.itemById(_itemId!);

  double? get _enteredPrice =>
      double.tryParse(_priceController.text.replaceAll(',', '.').trim());

  bool get _canSubmit =>
      _itemId != null && _supplierId != null && _quantity > 0;

  /// True when the user has changed the auto-filled price — the invoice
  /// disagreed with the price on file.
  bool get _priceWasEdited {
    final entered = _enteredPrice;
    final autofilled = _autofilledPrice;
    if (entered == null || autofilled == null) return false;
    return (entered - autofilled).abs() > 0.001;
  }

  void _onItemChanged(String? itemId) {
    setState(() {
      _itemId = itemId;
      // Pre-select the item's usual supplier and pull its price in. This is the
      // whole point: for a routine delivery the form is already filled.
      final defaultPrice = itemId == null
          ? null
          : MockQueries.defaultPriceForItem(itemId);
      _supplierId = defaultPrice?.supplierId;
      _applyPriceFor(itemId, _supplierId);
    });
  }

  void _onSupplierChanged(String? supplierId) {
    setState(() {
      _supplierId = supplierId;
      _applyPriceFor(_itemId, supplierId);
    });
  }

  void _applyPriceFor(String? itemId, String? supplierId) {
    if (itemId == null || supplierId == null) {
      _autofilledPrice = null;
      _priceController.clear();
      return;
    }

    final price = MockQueries.priceFor(itemId, supplierId);
    _autofilledPrice = price?.pricePerUnit;
    _priceController.text = price == null
        ? ''
        : Formatters.quantity(price.pricePerUnit);
  }

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
            secondaryLabel: MockQueries.categoryNameOf(i.categoryId),
          ),
        )
        .toList();

    // Only suppliers that actually supply this item. Offering all of them would
    // invite a link that does not exist and a price of nothing.
    final supplierOptions = item == null
        ? <DropdownOption<String>>[]
        : MockQueries.pricesForItem(item.id)
              .map(
                (price) => DropdownOption(
                  value: price.supplierId,
                  label: MockQueries.supplierNameOf(price.supplierId),
                  secondaryLabel:
                      '${Formatters.price(price.pricePerUnit)} / $unit',
                ),
              )
              .toList();

    final total = (_enteredPrice ?? 0) * _quantity;

    return ShellPage(
      title: l10n.stockInTitle,
      subtitle: l10n.stockInSubtitle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdown<String>(
                    label: l10n.stockInItem,
                    value: _itemId,
                    options: items,
                    onChanged: _onItemChanged,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppDropdown<String>(
                    label: l10n.stockInSupplier,
                    value: _supplierId,
                    options: supplierOptions,
                    enabled: item != null,
                    onChanged: _onSupplierChanged,
                  ),
                  if (item != null && supplierOptions.isEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _Hint(
                      icon: LucideIcons.triangleAlert,
                      colors: AppColors.lowStock,
                      message: l10n.stockInNoSupplier,
                      action: SecondaryButton(
                        label: l10n.itemLinkSupplier,
                        onPressed: () => context.go(
                          Routes.toLinkSupplier(widget.storeId, item.id),
                        ),
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
                  Text(
                    l10n.stockInQuantity,
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuantityStepper(
                    value: _quantity,
                    unitAbbreviation: unit,
                    min: 0,
                    onChanged: (value) => setState(() => _quantity = value),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField.currency(
                    label: l10n.stockInUnitPrice(unit.isEmpty ? '—' : unit),
                    controller: _priceController,
                    enabled: _supplierId != null,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_supplierId != null && !_priceWasEdited) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.stockInPriceAutofilled(
                        MockQueries.supplierNameOf(_supplierId),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (_priceWasEdited) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _Hint(
                      icon: LucideIcons.info,
                      colors: AppColors.lowStock,
                      message: l10n.stockInPriceChanged(
                        Formatters.price(_autofilledPrice!),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  Text(l10n.stockInDate, style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _DateField(
                    date: _date,
                    onChanged: (value) => setState(() => _date = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (_canSubmit && total > 0)
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.stockInTotal,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      Formatters.price(total),
                      style: AppTypography.numericLarge.copyWith(fontSize: 26),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xl),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SecondaryButton(
                  label: l10n.actionCancel,
                  onPressed: () =>
                      context.go(Routes.toMovements(widget.storeId)),
                ),
                const SizedBox(width: AppSpacing.md),
                PrimaryButton(
                  label: l10n.stockInSubmit,
                  icon: LucideIcons.arrowDownToLine,
                  large: true,
                  onPressed: _canSubmit ? _submit : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    AppSnackBar.success(context, l10n.stockInRecorded);
    context.go(Routes.toMovements(widget.storeId));
  }
}

/// Date picker rendered as a tappable field.
class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          // Deliveries are recorded on the day or shortly after, never for the
          // future — a future delivery has not arrived.
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
          locale: const Locale('fr', 'BE'),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        height: AppSizing.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.calendar,
              size: AppSizing.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                Formatters.dateLong(date),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const Icon(
              LucideIcons.chevronDown,
              size: AppSizing.iconSm,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tinted inline note under a field.
class _Hint extends StatelessWidget {
  const _Hint({
    required this.icon,
    required this.colors,
    required this.message,
    this.action,
  });

  final IconData icon;
  final StockStatusColors colors;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: AppSizing.iconMd, color: colors.foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.foreground),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}
