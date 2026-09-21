import 'dart:async';

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
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/movement_labels.dart';
import '../widgets/picker/movement_cart.dart';
import '../widgets/picker/product_picker_sheet.dart';

/// Receive a delivery — several products at once.
///
/// Products are picked by their card, not from a list of names, and each one
/// becomes its own line. A delivery of eight products is one form, saved in
/// one transaction, instead of the same form filled eight times.
///
/// The interaction that matters on every line: **picking a product
/// auto-fills its usual supplier and that supplier's current price, and both
/// stay editable.** Auto-filling removes the typing; keeping it editable
/// acknowledges that the invoice sometimes disagrees with the price on file,
/// and when it does the difference is what feeds the price history.
///
/// Each line has its own supplier, so a run to the market that came back with
/// tomatoes from one stall and herbs from another is still one delivery.
class StockInPage extends ConsumerStatefulWidget {
  const StockInPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<StockInPage> createState() => _StockInPageState();
}

/// One product on the delivery, and what the user has entered for it.
class _DeliveryLine {
  _DeliveryLine(this.itemId);

  final String itemId;
  final TextEditingController price = TextEditingController();

  String? supplierId;
  double quantity = 1;

  /// The price on file for the current item–supplier pair, so the line can
  /// tell whether the user has since edited it.
  double? autofilledPrice;

  double? get enteredPrice =>
      double.tryParse(price.text.replaceAll(',', '.').trim());

  /// True when the user has changed the auto-filled price — the invoice
  /// disagreed with the price on file.
  bool get priceWasEdited {
    final entered = enteredPrice;
    final autofilled = autofilledPrice;
    if (entered == null || autofilled == null) return false;
    return (entered - autofilled).abs() > 0.001;
  }

  bool get isValid => supplierId != null && quantity > 0;

  double get total => (enteredPrice ?? 0) * quantity;
}

class _StockInPageState extends ConsumerState<StockInPage> {
  final List<_DeliveryLine> _lines = [];
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    for (final line in _lines) {
      line.price.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit =>
      !_saving && _lines.isNotEmpty && _lines.every((line) => line.isValid);

  double get _total => _lines.fold(0, (sum, line) => sum + line.total);

  Future<void> _pick() async {
    final picked = await ProductPickerSheet.show(
      context,
      storeId: widget.storeId,
      alreadyPicked: {for (final line in _lines) line.itemId},
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    final added = [for (final row in picked) _DeliveryLine(row.item.id)];
    setState(() => _lines.addAll(added));
    for (final line in added) {
      unawaited(_prefill(line));
    }
  }

  /// A new line pre-selects the product's usual supplier and pulls that price
  /// in. For a routine delivery the line is then already filled, and the only
  /// thing left to do is confirm the quantity.
  Future<void> _prefill(_DeliveryLine line) async {
    final pricing = await ref
        .read(supplierRepositoryProvider)
        .defaultPriceForItem(line.itemId);
    if (!mounted || !_lines.contains(line) || line.supplierId != null) return;

    setState(() {
      line.supplierId = pricing?.supplierId;
      line.autofilledPrice = pricing?.pricePerUnit;
      line.price.text = pricing == null
          ? ''
          : Formatters.quantity(pricing.pricePerUnit);
    });
  }

  Future<void> _onSupplierChanged(
    _DeliveryLine line,
    String? supplierId,
  ) async {
    setState(() {
      line.supplierId = supplierId;
      line.autofilledPrice = null;
      line.price.clear();
    });
    if (supplierId == null) return;

    final price = await ref
        .read(supplierRepositoryProvider)
        .priceFor(line.itemId, supplierId);
    if (!mounted || line.supplierId != supplierId) return;

    setState(() {
      line.autofilledPrice = price?.pricePerUnit;
      line.price.text = price == null
          ? ''
          : Formatters.quantity(price.pricePerUnit);
    });
  }

  void _remove(_DeliveryLine line) {
    setState(() => _lines.remove(line));
    // After the frame, so a line leaving through a swipe is not disposed
    // while the dismiss animation still holds its field.
    WidgetsBinding.instance.addPostFrameCallback((_) => line.price.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Read fresh on every build, so the "en stock" figure under each line
    // moves if a delivery lands elsewhere while this one is being entered.
    final rows =
        ref
            .watch(
              itemRowsProvider((
                storeId: widget.storeId,
                filter: ItemFilter.none,
              )),
            )
            .value ??
        const <ItemRowView>[];
    final byId = {for (final row in rows) row.item.id: row};

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
      submitSecondary: CartSummary(count: _lines.length, total: _total),
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _lines.isNotEmpty,
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // One date for the whole delivery: it arrived once.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

          MovementCartList(
            accent: movementColors(StockMovementType.stockIn),
            onPick: _pick,
            lines: [
              for (final line in _lines)
                if (byId[line.itemId] != null)
                  MovementLineCard(
                    key: ObjectKey(line),
                    view: byId[line.itemId]!,
                    onRemove: () => _remove(line),
                    invalid: line.supplierId == null,
                    trailing: line.total > 0
                        ? Text(
                            Formatters.price(line.total),
                            style: AppTypography.numeric.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                    child: _DeliveryLineFields(
                      storeId: widget.storeId,
                      line: line,
                      view: byId[line.itemId]!,
                      onSupplierChanged: (id) => _onSupplierChanged(line, id),
                      onQuantityChanged: (value) =>
                          setState(() => line.quantity = value),
                      onPriceChanged: () => setState(() {}),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final movements = ref.read(movementRepositoryProvider);
    final suppliers = ref.read(supplierRepositoryProvider);
    final lines = List.of(_lines);

    setState(() => _saving = true);
    try {
      // All of it or none of it: a failure on the sixth line must not leave
      // five on the shelf and the user unsure which.
      await movements.batch(() async {
        for (final line in lines) {
          // No order behind it: somebody ran to the market. The movement
          // carries no order or receipt reference, which is exactly how the
          // history tells the two paths apart.
          await movements.recordStockIn(
            storeId: widget.storeId,
            itemId: line.itemId,
            quantity: line.quantity,
            supplierId: line.supplierId,
            unitPrice: line.enteredPrice,
            occurredAt: _date,
          );

          // A price typed here that differs from the one on file is a real
          // price change, recorded the same way receiving a delivery records
          // one.
          final entered = line.enteredPrice;
          if (entered != null && line.priceWasEdited) {
            final price = await suppliers.priceFor(
              line.itemId,
              line.supplierId!,
            );
            if (price != null) {
              await suppliers.updatePrice(price.id, entered, changedAt: _date);
            }
          }
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    AppSnackBar.success(
      context,
      lines.length == 1
          ? l10n.stockInRecorded
          : l10n.movementsRecorded(lines.length),
    );
    context.goSection(Routes.toMovements(widget.storeId));
  }
}

/// Supplier, price and quantity for one delivery line.
class _DeliveryLineFields extends ConsumerWidget {
  const _DeliveryLineFields({
    required this.storeId,
    required this.line,
    required this.view,
    required this.onSupplierChanged,
    required this.onQuantityChanged,
    required this.onPriceChanged,
  });

  final String storeId;
  final _DeliveryLine line;
  final ItemRowView view;
  final ValueChanged<String?> onSupplierChanged;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onPriceChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = view.unitAbbreviation;

    // Only suppliers that actually supply this article. Offering all of them
    // would invite a link that does not exist and a price of nothing.
    final pricing = ref.watch(itemPricingProvider(line.itemId));
    final offers = pricing.value?.prices ?? const <SupplierPriceView>[];

    final supplierOptions = <DropdownOption<String>>[
      for (final offer in offers)
        DropdownOption(
          value: offer.price.supplierId,
          label: offer.supplierName,
          secondaryLabel:
              '${Formatters.price(offer.price.pricePerUnit)} / $unit',
        ),
    ];

    var supplierName = '—';
    for (final offer in offers) {
      if (offer.price.supplierId == line.supplierId) {
        supplierName = offer.supplierName;
      }
    }

    if (pricing.hasValue && supplierOptions.isEmpty) {
      return _Hint(
        icon: LucideIcons.triangleAlert,
        colors: AppColors.lowStock,
        message: l10n.stockInNoSupplier,
        action: SecondaryButton(
          label: l10n.itemLinkSupplier,
          onPressed: () =>
              context.pushScreen(Routes.toLinkSupplier(storeId, line.itemId)),
        ),
      );
    }

    final supplier = AppDropdown<String>(
      label: l10n.stockInSupplier,
      // The default supplier can arrive before this line's offers have: a
      // menu asked to show a value it does not list asserts, so it shows
      // nothing for that frame instead.
      value: supplierOptions.any((option) => option.value == line.supplierId)
          ? line.supplierId
          : null,
      options: supplierOptions,
      onChanged: onSupplierChanged,
    );

    final price = AppTextField.currency(
      label: l10n.stockInUnitPrice(unit.isEmpty ? '—' : unit),
      controller: line.price,
      enabled: line.supplierId != null,
      onChanged: (_) => onPriceChanged(),
    );

    final quantity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LineFieldLabel(l10n.stockInQuantity),
        QuantityStepper(
          value: line.quantity,
          unitAbbreviation: unit,
          min: 0,
          onChanged: onQuantityChanged,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: supplier),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 2, child: price),
                ],
              )
            else ...[
              supplier,
              const SizedBox(height: AppSpacing.md),
              price,
            ],
            if (line.supplierId != null && !line.priceWasEdited) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.stockInPriceAutofilled(supplierName),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (line.priceWasEdited) ...[
              const SizedBox(height: AppSpacing.sm),
              _Hint(
                icon: LucideIcons.info,
                colors: AppColors.lowStock,
                message: l10n.stockInPriceChanged(
                  Formatters.price(line.autofilledPrice!),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            quantity,
          ],
        );
      },
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
