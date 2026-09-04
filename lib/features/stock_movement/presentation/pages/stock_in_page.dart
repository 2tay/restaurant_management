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
class StockInPage extends ConsumerStatefulWidget {
  const StockInPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends ConsumerState<StockInPage> {
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

  /// The picked article, from the list the dropdown already shows.
  ItemRowView? _selected(List<ItemRowView> rows) {
    for (final row in rows) {
      if (row.item.id == _itemId) return row;
    }
    return null;
  }

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

  /// Picking an article pre-selects its usual supplier and pulls that price in.
  ///
  /// This is the whole point of the screen: for a routine delivery the form is
  /// already filled, and the only thing left to do is confirm the quantity.
  ///
  /// Asynchronous now, because the offers are a query. The write it eventually
  /// makes is the user's, so a slow answer costs a beat of an empty price field
  /// rather than a wrong number.
  Future<void> _onItemChanged(String? itemId) async {
    setState(() {
      _itemId = itemId;
      _supplierId = null;
      _autofilledPrice = null;
      _priceController.clear();
    });
    if (itemId == null) return;

    final pricing = await ref
        .read(supplierRepositoryProvider)
        .defaultPriceForItem(itemId);
    if (!mounted || _itemId != itemId) return;

    setState(() {
      _supplierId = pricing?.supplierId;
      _autofilledPrice = pricing?.pricePerUnit;
      _priceController.text = pricing == null
          ? ''
          : Formatters.quantity(pricing.pricePerUnit);
    });
  }

  Future<void> _onSupplierChanged(String? supplierId) async {
    setState(() => _supplierId = supplierId);

    final itemId = _itemId;
    if (itemId == null || supplierId == null) {
      setState(() {
        _autofilledPrice = null;
        _priceController.clear();
      });
      return;
    }

    final price = await ref
        .read(supplierRepositoryProvider)
        .priceFor(itemId, supplierId);
    if (!mounted || _itemId != itemId || _supplierId != supplierId) return;

    setState(() {
      _autofilledPrice = price?.pricePerUnit;
      _priceController.text = price == null
          ? ''
          : Formatters.quantity(price.pricePerUnit);
    });
  }

  bool get _isDirty => _itemId != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final rows =
        ref.watch(itemRowsProvider((
              storeId: widget.storeId,
              filter: ItemFilter.none,
            ))).value ??
        const <ItemRowView>[];

    final row = _selected(rows);
    final item = row?.item;
    final unit = row?.unitAbbreviation ?? '';

    final items = [
      for (final row in rows)
        DropdownOption(
          value: row.item.id,
          label: row.item.name,
          secondaryLabel: row.categoryName,
        ),
    ];

    // Only suppliers that actually supply this article. Offering all of them
    // would invite a link that does not exist and a price of nothing.
    final offers = item == null
        ? const <SupplierPriceView>[]
        : ref.watch(itemPricingProvider(item.id)).value?.prices ??
              const <SupplierPriceView>[];

    final supplierOptions = <DropdownOption<String>>[
      for (final offer in offers)
        DropdownOption(
          value: offer.price.supplierId,
          label: offer.supplierName,
          secondaryLabel:
              '${Formatters.price(offer.price.pricePerUnit)} / $unit',
        ),
    ];

    // The supplier named beside the auto-filled price. Taken from the same
    // list the menu shows, so the sentence cannot name somebody the menu does
    // not offer.
    var supplierName = '—';
    for (final offer in offers) {
      if (offer.price.supplierId == _supplierId) {
        supplierName = offer.supplierName;
      }
    }

    final total = (_enteredPrice ?? 0) * _quantity;

    return FormScaffold(
      title: l10n.stockInTitle,
      subtitle: l10n.stockInSubtitle,
      back: BackDestination(
        label: l10n.movementsTitle,
        path: Routes.toMovements(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.movementsTitle, Routes.toMovements(widget.storeId)),
        Crumb(l10n.stockInTitle),
      ],
      submitLabel: l10n.stockInSubmit,
      submitIcon: LucideIcons.arrowDownToLine,
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _isDirty,
      maxWidth: 720,
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
                      onPressed: () => context.pushScreen(
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
                Text(l10n.stockInQuantity, style: theme.textTheme.labelMedium),
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
                    l10n.stockInPriceAutofilled(supplierName),
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
                DateField(
                  value: _date,
                  onChanged: (value) => setState(() => _date = value),
                  // Deliveries are recorded on the day or shortly after, never
                  // for the future — a future delivery has not arrived.
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
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
                    style: AppTypography.numericHero,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final suppliers = ref.read(supplierRepositoryProvider);
    final priceWasEdited = _priceWasEdited;

    // No order behind it: somebody ran to the market. The movement carries no
    // order or receipt reference, which is exactly how the history tells the
    // two paths apart.
    await ref
        .read(movementRepositoryProvider)
        .recordStockIn(
          storeId: widget.storeId,
          itemId: _itemId!,
          quantity: _quantity,
          supplierId: _supplierId,
          unitPrice: _enteredPrice,
          occurredAt: _date,
        );

    // A price typed here that differs from the one on file is a real price
    // change, recorded the same way receiving a delivery records one.
    final price = await suppliers.priceFor(_itemId!, _supplierId!);
    final entered = _enteredPrice;
    if (price != null && entered != null && priceWasEdited) {
      await suppliers.updatePrice(price.id, entered, changedAt: _date);
    }

    if (!mounted) return;
    AppSnackBar.success(context, l10n.stockInRecorded);
    context.goSection(Routes.toMovements(widget.storeId));
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
