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
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/movement_labels.dart';
import '../../../../core/utils/employee_status.dart';
import '../widgets/picker/movement_cart.dart';
import '../widgets/picker/product_picker_sheet.dart';
import '../widgets/picker/supplier_choice.dart';

/// Receive a delivery — several products at once.
///
/// Products are picked by their card, not from a list of names, and each one
/// becomes a compact row: supplier, price, quantity, line total. A delivery of
/// eight products is one form, saved in one transaction.
///
/// The interaction that matters on every row: **picking a product auto-fills
/// its usual supplier and that supplier's current price, and both stay
/// editable.** Auto-filling removes the typing; keeping it editable
/// acknowledges that the invoice sometimes disagrees with the price on file,
/// and when it does the difference is what feeds the price history.
///
/// Each row has its own supplier, so a run to the market that came back with
/// tomatoes from one stall and herbs from another is still one delivery — and
/// when it all came from one supplier, one tick applies it to every row.
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
  final FocusNode quantityFocus = FocusNode();
  final GlobalKey key = GlobalKey();

  String? supplierId;
  double quantity = 1;

  /// The price on file for the current item–supplier pair, so the row can
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

  void dispose() {
    price.dispose();
    quantityFocus.dispose();
  }
}

class _StockInPageState extends ConsumerState<StockInPage> {
  final List<_DeliveryLine> _lines = [];
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit =>
      !_saving && _lines.isNotEmpty && _lines.every((line) => line.isValid);

  double get _total => _lines.fold(0, (sum, line) => sum + line.total);

  Future<void> _pick(List<ItemRowView> rows) async {
    // Whatever is running low is most likely what just arrived.
    final restock =
        [
          for (final row in rows)
            if (needsAttention(row.item)) row,
        ]..sort(
          (a, b) => stockStatusOf(
            b.item,
          ).index.compareTo(stockStatusOf(a.item).index),
        );

    final picked = await ProductPickerSheet.show(
      context,
      storeId: widget.storeId,
      alreadyPicked: {for (final line in _lines) line.itemId},
      featured: [for (final row in restock) row.item.id],
      featuredTitle: AppLocalizations.of(context).pickerSectionRestock,
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    final added = [for (final row in picked) _DeliveryLine(row.item.id)];
    setState(() => _lines.addAll(added));
    for (final line in added) {
      unawaited(_prefill(line));
    }
  }

  /// A new row pre-selects the product's usual supplier and pulls that price
  /// in. For a routine delivery the row is then already filled, and the only
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

  /// Sets [supplierId] on [line] and pulls in that supplier's price. Returns
  /// false when the supplier does not offer this product.
  Future<bool> _setSupplier(_DeliveryLine line, String supplierId) async {
    final price = await ref
        .read(supplierRepositoryProvider)
        .priceFor(line.itemId, supplierId);
    if (!mounted || price == null) return false;

    setState(() {
      line.supplierId = supplierId;
      line.autofilledPrice = price.pricePerUnit;
      line.price.text = Formatters.quantity(price.pricePerUnit);
    });
    return true;
  }

  Future<void> _chooseSupplier(
    _DeliveryLine line,
    ItemRowView view,
    List<SupplierPriceView> offers,
  ) async {
    final l10n = AppLocalizations.of(context);
    final choice = await SupplierChoiceSheet.show(
      context,
      itemName: view.item.name,
      unit: view.unitAbbreviation,
      offers: offers,
      selectedId: line.supplierId,
      canApplyToAll: _lines.length > 1,
    );
    if (choice == null || !mounted) return;

    await _setSupplier(line, choice.supplierId);
    if (!choice.applyToAll || !mounted) return;

    // Every other row this supplier also offers. A row whose product it does
    // not sell keeps its own supplier rather than being emptied.
    var applied = 1;
    for (final other in List.of(_lines)) {
      if (identical(other, line)) continue;
      if (await _setSupplier(other, choice.supplierId)) applied++;
    }
    if (!mounted) return;

    var name = '';
    for (final offer in offers) {
      if (offer.price.supplierId == choice.supplierId) {
        name = offer.supplierName;
      }
    }
    AppSnackBar.success(context, l10n.supplierAppliedAll(name, applied));
  }

  void _remove(_DeliveryLine line) {
    setState(() => _lines.remove(line));
    // After the frame, so a row leaving through a swipe is not disposed
    // while the dismiss animation still holds its field.
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  /// Enter on a quantity moves to the next row's quantity, so a whole
  /// delivery can be typed without reaching for the screen.
  void _focusAfter(_DeliveryLine line) {
    final index = _lines.indexOf(line);
    if (index >= 0 && index + 1 < _lines.length) {
      _lines[index + 1].quantityFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Deliveries are recorded on the day or shortly after, never for the
      // future — a future delivery has not arrived.
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'BE'),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String _dateLabel(AppLocalizations l10n) {
    final now = DateTime.now();
    final day = DateTime(_date.year, _date.month, _date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l10n.dateToday.toLowerCase();
    if (day == DateTime(now.year, now.month, now.day - 1)) {
      return l10n.dateYesterday.toLowerCase();
    }
    return Formatters.date(_date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Read fresh on every build, so the stock figure on each row moves if a
    // delivery lands elsewhere while this one is being entered.
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

    final noSupplier = [
      for (final line in _lines)
        if (line.supplierId == null) line,
    ];
    final noQuantity = [
      for (final line in _lines)
        if (line.quantity <= 0) line,
    ];
    final firstIssue = noSupplier.isNotEmpty
        ? noSupplier.first
        : noQuantity.isNotEmpty
        ? noQuantity.first
        : null;

    return FormScaffold(
      title: l10n.stockInTitle,
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
      submitSecondary: CartSummary(
        count: _lines.length,
        total: _total,
        issue: noSupplier.isNotEmpty
            ? l10n.cartIssueNoSupplier(noSupplier.length)
            : noQuantity.isNotEmpty
            ? l10n.cartIssueNoQuantity(noQuantity.length)
            : null,
        onIssueTap: firstIssue == null
            ? null
            : () => scrollToLine(firstIssue.key),
      ),
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _lines.isNotEmpty,
      maxWidth: 1080,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MovementBanner(
            colors: movementColors(StockMovementType.stockIn),
            icon: LucideIcons.arrowDownToLine,
            message: l10n.stockInSubtitle,
            // One date for the whole delivery: it arrived once.
            trailing: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(LucideIcons.calendar, size: AppSizing.iconSm),
              label: Text(l10n.deliveryReceivedOn(_dateLabel(l10n))),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillAll,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                visualDensity: VisualDensity.compact,
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          MovementProductsCard(
            accent: movementColors(StockMovementType.stockIn),
            onPick: () => _pick(rows),
            rows: [
              for (final line in _lines)
                if (byId[line.itemId] != null)
                  _DeliveryRow(
                    key: line.key,
                    storeId: widget.storeId,
                    line: line,
                    view: byId[line.itemId]!,
                    onRemove: () => _remove(line),
                    onChooseSupplier: (offers) =>
                        _chooseSupplier(line, byId[line.itemId]!, offers),
                    onQuantityChanged: (value) =>
                        setState(() => line.quantity = value),
                    onPriceChanged: () => setState(() {}),
                    onQuantitySubmitted: () => _focusAfter(line),
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

    // Who is at the tablet. Asked here, at the save, so the person who
    // confirms is the person who saves.
    final actor = await ActorConfirmSheet.show(
      context,
      storeId: widget.storeId,
      actionLabel: l10n.stockInSubmit,
    );
    if (actor == null || !mounted) return;
    final actorName = employeeDisplayName(actor);

    setState(() => _saving = true);
    try {
      // All of it or none of it: a failure on the sixth row must not leave
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
            userName: actorName,
            employeeId: actor.id,
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
      l10n.movementsRecordedBy(lines.length, actor.firstName),
    );
    context.goSection(Routes.toMovements(widget.storeId));
  }
}

/// One delivery row: supplier chip, unit price, quantity, line total.
class _DeliveryRow extends ConsumerWidget {
  const _DeliveryRow({
    required this.storeId,
    required this.line,
    required this.view,
    required this.onRemove,
    required this.onChooseSupplier,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onQuantitySubmitted,
    super.key,
  });

  final String storeId;
  final _DeliveryLine line;
  final ItemRowView view;
  final VoidCallback onRemove;
  final ValueChanged<List<SupplierPriceView>> onChooseSupplier;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onPriceChanged;
  final VoidCallback onQuantitySubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = view.unitAbbreviation;
    final stock = view.item.quantity;

    // Only suppliers that actually supply this article. Offering all of them
    // would invite a link that does not exist and a price of nothing.
    final pricing = ref.watch(itemPricingProvider(line.itemId));
    final offers = pricing.value?.prices ?? const <SupplierPriceView>[];

    String? supplierName;
    for (final offer in offers) {
      if (offer.price.supplierId == line.supplierId) {
        supplierName = offer.supplierName;
      }
    }

    final noOffers = pricing.hasValue && offers.isEmpty;

    final controls = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (noOffers)
          // Nobody is on file as selling this: the fix is one tap away.
          TextButton.icon(
            onPressed: () =>
                context.pushScreen(Routes.toLinkSupplier(storeId, line.itemId)),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(LucideIcons.link, size: AppSizing.iconSm),
            label: Text(l10n.itemLinkSupplier),
          )
        else
          SupplierChip(
            name: supplierName,
            enabled: offers.isNotEmpty,
            onTap: () => onChooseSupplier(offers),
          ),
        LinePriceField(
          controller: line.price,
          unit: unit,
          enabled: line.supplierId != null,
          onChanged: onPriceChanged,
          textInputAction: TextInputAction.next,
          onSubmitted: line.quantityFocus.requestFocus,
        ),
        QuantityStepper(
          compact: true,
          value: line.quantity,
          unitAbbreviation: unit,
          min: 0,
          onChanged: onQuantityChanged,
          focusNode: line.quantityFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: onQuantitySubmitted,
        ),
      ],
    );

    return MovementLineCard(
      view: view,
      onRemove: onRemove,
      state: line.supplierId == null || line.quantity <= 0
          ? LineState.invalid
          : LineState.normal,
      inlineMinWidth: 960,
      // What the shelf will hold once this is put away — or, when the price
      // on the invoice differed, what it was before.
      subtitle: line.priceWasEdited
          ? Text(
              l10n.linePriceEdited(Formatters.price(line.autofilledPrice!)),
              style: TextStyle(
                color: AppColors.lowStock.foreground,
                fontWeight: FontWeight.w600,
              ),
            )
          : StockAfter(before: stock, after: stock + line.quantity, unit: unit),
      trailing: Text(
        line.total > 0 ? Formatters.price(line.total) : '—',
        style: AppTypography.numeric.copyWith(fontWeight: FontWeight.w700),
      ),
      controls: controls,
    );
  }
}
