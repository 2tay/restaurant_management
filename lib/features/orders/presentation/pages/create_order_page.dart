import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
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
import '../widgets/order_line_editor.dart';
import '../widgets/suggested_items_panel.dart';

/// Create a commande.
///
/// Thin on purpose — the form itself is [OrderFormPage], shared with the edit
/// screen, because "edit a draft" is the same screen with something already in
/// it and writing it twice would guarantee the two drift apart.
class CreateOrderPage extends StatelessWidget {
  const CreateOrderPage({
    required this.storeId,
    this.initialSupplierId,
    this.prefillSuggested = false,
    super.key,
  });

  final String storeId;

  /// Pre-selects a supplier. Set when arriving from the low stock alerts
  /// screen, which already knows who to order from.
  final String? initialSupplierId;

  /// Also adds that supplier's low-stock items straight away — the point of
  /// coming here from the alerts screen.
  final bool prefillSuggested;

  @override
  Widget build(BuildContext context) {
    return OrderFormPage(
      storeId: storeId,
      initialSupplierId: initialSupplierId,
      prefillSuggested: prefillSuggested,
    );
  }
}

/// The order form, used for both creating and editing a draft.
///
/// Split into a gate and a form, like the article and supplier forms: the
/// fields are filled from the draft being edited, and that draft is a query.
class OrderFormPage extends ConsumerWidget {
  const OrderFormPage({
    required this.storeId,
    this.orderId,
    this.initialSupplierId,
    this.prefillSuggested = false,
    super.key,
  });

  final String storeId;

  /// Null when creating. Editing anything that is not a draft is refused — the
  /// supplier already holds a copy of a sent order.
  final String? orderId;

  final String? initialSupplierId;
  final bool prefillSuggested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orderId == null) {
      return _OrderForm(
        storeId: storeId,
        existing: null,
        initialSupplierId: initialSupplierId,
        prefillSuggested: prefillSuggested,
      );
    }

    final l10n = AppLocalizations.of(context);
    final asyncOrder = ref.watch(orderProvider(orderId!));
    final existing = asyncOrder.value;

    if (existing == null) {
      return ShellPage(
        title: l10n.ordersTitle,
        child: asyncOrder.isLoading
            ? const SkeletonList(rows: 3, rowHeight: 100)
            : ErrorState(
                message: l10n.errorStateBody,
                onRetry: () => context.goSection(Routes.toOrders(storeId)),
              ),
      );
    }

    return _OrderForm(
      key: ValueKey(orderId),
      storeId: storeId,
      existing: existing,
      initialSupplierId: initialSupplierId,
      prefillSuggested: prefillSuggested,
    );
  }
}

class _OrderForm extends ConsumerStatefulWidget {
  const _OrderForm({
    required this.storeId,
    required this.existing,
    required this.initialSupplierId,
    required this.prefillSuggested,
    super.key,
  });

  final String storeId;

  /// The draft being edited, or null when creating.
  final PurchaseOrder? existing;

  final String? initialSupplierId;
  final bool prefillSuggested;

  @override
  ConsumerState<_OrderForm> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends ConsumerState<_OrderForm> {
  final _noteController = TextEditingController();
  final List<OrderLineDraft> _lines = [];

  String? _supplierId;
  int _lineSequence = 0;

  /// True while the supplier picker is showing.
  ///
  /// Separate from `_supplierId == null` so that reopening the picker on an
  /// order that already has a supplier does not have to blank the choice first
  /// — blanking it would strand the lines against a supplier that is no longer
  /// selected, and re-picking the same one would then wrongly offer to clear
  /// them.
  bool _pickingSupplier = false;

  // Snapshot for the dirty check, so undoing an edit back to where it started
  // correctly stops counting as unsaved.
  String _initialNote = '';
  String? _initialSupplierId;
  String _initialLines = '';

  bool get _isEditing => widget.existing != null;

  /// The rows the item picker offers, and the prices behind them.
  ///
  /// Refreshed at the top of every build from the chosen supplier's offers, so
  /// the handlers below — which run between builds — always see the same list
  /// the user was looking at when they tapped.
  List<SupplierProductView> _offers = const [];

  /// The articles behind those rows, by id.
  ///
  /// Refreshed alongside [_offers] and for the same reason. `SupplierProductView`
  /// answers "what does this supplier charge"; the top-up figure needs "how much
  /// is on the shelf and how much fits", which is a fact about the article.
  Map<String, Item> _stockById = const {};

  /// Set once, when the suggestion list first arrives for a prefilled order.
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _supplierId = existing.supplierId;
      _noteController.text = existing.note ?? '';
      for (final line in existing.lines) {
        _lines.add(
          OrderLineDraft(
            id: line.id,
            itemId: line.itemId,
            quantity: line.quantityOrdered,
            unitPrice: line.unitPrice,
          ),
        );
      }
    } else if (widget.initialSupplierId != null) {
      // Arriving from the low-stock alerts screen. The lines themselves are
      // filled in during the first build that has the suggestions in hand —
      // they are a query now, and `initState` cannot wait for one.
      _supplierId = widget.initialSupplierId;
    }

    _snapshot();
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _snapshot() {
    _initialNote = _noteController.text.trim();
    _initialSupplierId = _supplierId;
    _initialLines = _fingerprint();
  }

  /// A cheap stand-in for comparing the line list field by field.
  String _fingerprint() =>
      _lines.map((l) => '${l.itemId}:${l.quantity}:${l.unitPrice}').join('|');

  bool get _isDirty =>
      _noteController.text.trim() != _initialNote ||
      _supplierId != _initialSupplierId ||
      _fingerprint() != _initialLines;

  /// Every line needs an item and a quantity worth sending to a supplier.
  bool get _canSubmit =>
      _supplierId != null &&
      _lines.isNotEmpty &&
      _lines.every((line) => line.quantity > 0 && line.unitPrice > 0);

  double get _total {
    var total = 0.0;
    for (final line in _lines) {
      total += line.total;
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // Lines
  // ---------------------------------------------------------------------------

  String _nextLineId() {
    _lineSequence++;
    return 'draft-line-$_lineSequence';
  }

  /// The price this supplier charges for an item, or zero if there is no link.
  ///
  /// From the offers already on screen rather than from a query of its own: the
  /// picker only lists articles this supplier sells, so the answer is always in
  /// the list the user just chose from.
  double _priceFor(String itemId) {
    for (final offer in _offers) {
      if (offer.price.itemId == itemId) return offer.price.pricePerUnit;
    }
    return 0;
  }

  void _addItems(List<Item> items) {
    for (final item in items) {
      if (_lines.any((line) => line.itemId == item.id)) continue;
      _lines.add(
        OrderLineDraft(
          id: _nextLineId(),
          itemId: item.id,
          // Guessing a quantity beats leaving a zero the user has to notice
          // and fix on every line.
          quantity: topUpQuantity(item),
          unitPrice: _priceFor(item.id),
        ),
      );
    }
  }

  /// [topUpQuantity] for an article the page knows only by id.
  ///
  /// One for an article that is not in the catalogue this build is holding —
  /// the picker cannot offer one, so this is the empty-line placeholder rather
  /// than a real answer.
  double _suggestedQuantityFor(String itemId) {
    final item = _stockById[itemId];
    return item == null ? 1 : topUpQuantity(item);
  }

  void _addEmptyLine() {
    final available = _availableItems();
    setState(() {
      final itemId = available.isEmpty ? '' : available.first.price.itemId;
      _lines.add(
        OrderLineDraft(
          id: _nextLineId(),
          itemId: itemId,
          // Pre-filled to the top-up for whichever article the picker landed
          // on, so a hand-added line starts where a suggested one would.
          quantity: _suggestedQuantityFor(itemId),
          unitPrice: available.isEmpty ? 0 : available.first.price.pricePerUnit,
        ),
      );
    });
  }

  /// Articles this supplier supplies that are not already on the order.
  List<SupplierProductView> _availableItems({String? including}) {
    final chosen = _lines
        .map((line) => line.itemId)
        .where((id) => id != including)
        .toSet();

    return [
      for (final offer in _offers)
        if (!chosen.contains(offer.price.itemId)) offer,
    ];
  }

  void _removeLine(OrderLineDraft line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
    AppSnackBar.success(context, AppLocalizations.of(context).orderLineRemoved);
  }

  // ---------------------------------------------------------------------------
  // Supplier
  // ---------------------------------------------------------------------------

  Future<void> _chooseSupplier(String supplierId) async {
    if (supplierId == _supplierId) {
      setState(() => _pickingSupplier = false);
      return;
    }

    // Changing supplier invalidates every line: the item picker is filtered by
    // supplier and the prices came from the old one. Say so rather than
    // silently emptying the form.
    if (_lines.isNotEmpty) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.orderChangeSupplierTitle,
        message: l10n.orderChangeSupplierBody(_lines.length),
        confirmLabel: l10n.orderChangeSupplierAction,
        isDestructive: false,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      for (final line in _lines) {
        line.dispose();
      }
      _lines.clear();
      _supplierId = supplierId;
      _pickingSupplier = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final back = BackDestination(
      label: l10n.ordersTitle,
      path: Routes.toOrders(widget.storeId),
    );
    final title = _isEditing ? l10n.editOrderTitle : l10n.createOrderTitle;

    return FormScaffold(
      title: title,
      back: back,
      crumbs: [
        Crumb(l10n.ordersTitle, Routes.toOrders(widget.storeId)),
        Crumb(title),
      ],
      submitLabel: l10n.orderActionSend,
      submitIcon: LucideIcons.send,
      onSubmit: _canSubmit ? _send : null,
      submitSecondary: SecondaryButton(
        label: l10n.orderActionSaveDraft,
        icon: LucideIcons.check,
        onPressed: _canSubmit ? _saveDraft : null,
      ),
      isDirty: _isDirty,
      maxWidth: 1080,
      child: _supplierId == null || _pickingSupplier
          ? _SupplierStep(storeId: widget.storeId, onChosen: _chooseSupplier)
          : _linesStep(context, l10n),
    );
  }

  Widget _linesStep(BuildContext context, AppLocalizations l10n) {
    final supplierId = _supplierId!;

    // Everything this supplier sells, with prices and names already resolved.
    // One query serves the picker, the auto-filled prices and the line labels.
    _offers =
        ref.watch(supplierProductsProvider(supplierId)).value ??
        const <SupplierProductView>[];

    _stockById = {
      for (final item
          in ref
                  .watch(
                    itemsProvider((
                      storeId: widget.storeId,
                      filter: ItemFilter(supplierId: supplierId),
                    )),
                  )
                  .value ??
              const <Item>[])
        item.id: item,
    };

    final suggestions =
        ref.watch(
          itemRowsProvider((
            storeId: widget.storeId,
            filter: ItemFilter(supplierId: supplierId, lowStockOnly: true),
          )),
        ).value ??
        const <ItemRowView>[];

    // The alerts screen sends people here with "fill it in for me". Done on
    // the first build that has the suggestions, since `initState` could not
    // wait for the query.
    if (!_prefilled && widget.prefillSuggested && suggestions.isNotEmpty) {
      _prefilled = true;
      _addItems([for (final row in suggestions) row.item]);
      _snapshot();
    }

    final supplierName = _supplierName(supplierId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChosenSupplier(
          name: supplierName,
          onChange: () => setState(() => _pickingSupplier = true),
        ),
        const SizedBox(height: AppSpacing.xl),

        SuggestedItemsPanel(
          storeId: widget.storeId,
          supplierId: supplierId,
          suggestions: suggestions,
          supplierName: supplierName,
          chosenItemIds: _lines.map((line) => line.itemId).toSet(),
          onAdd: (item) {
            setState(() => _addItems([item]));
            AppSnackBar.success(context, l10n.orderSuggestedAdded(1));
          },
          onAddAll: (items) {
            setState(() => _addItems(items));
            AppSnackBar.success(
              context,
              l10n.orderSuggestedAdded(items.length),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(
          title: l10n.orderStepLines,
          count: _lines.isEmpty ? null : _lines.length,
          trailing: SecondaryButton(
            label: l10n.orderAddLine,
            icon: LucideIcons.plus,
            onPressed: _availableItems().isEmpty ? null : _addEmptyLine,
          ),
        ),

        if (_lines.isEmpty)
          AppCard(
            child: EmptyState(
              icon: LucideIcons.packagePlus,
              title: l10n.orderLinesEmptyTitle,
              message: l10n.orderLinesEmptyBody(supplierName),
              actionLabel: l10n.orderAddLine,
              actionIcon: LucideIcons.plus,
              onAction: _availableItems().isEmpty ? null : _addEmptyLine,
            ),
          )
        else
          for (final line in _lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: OrderLineEditor(
                key: ValueKey(line.id),
                draft: line,
                storeId: widget.storeId,
                supplierId: supplierId,
                unitAbbreviation: _unitOf(line.itemId),
                itemOptions: [
                  for (final offer in _availableItems(including: line.itemId))
                    DropdownOption(
                      value: offer.price.itemId,
                      label: offer.itemName,
                      secondaryLabel: offer.categoryName,
                    ),
                ],
                onItemChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    line.itemId = value;
                    line.setPrice(_priceFor(value));
                    // The quantity belonged to the article that was on this
                    // line a moment ago. Keeping it would carry 12 kg of
                    // potatoes over onto the saffron.
                    line.quantity = _suggestedQuantityFor(value);
                  });
                },
                onQuantityChanged: (value) =>
                    setState(() => line.quantity = value),
                onPriceChanged: () => setState(() {}),
                onRemove: () => _removeLine(line),
              ),
            ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: AppTextField(
            label: l10n.orderNoteLabel,
            controller: _noteController,
            hint: l10n.orderNoteHint,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // The commitment, stated before either forward action is reachable.
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.orderTotalLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(Formatters.price(_total), style: AppTypography.numericHero),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  List<PurchaseOrderLine> _toLines() => [
    for (final line in _lines) line.toLine(),
  ];

  String? get _note {
    final text = _noteController.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _saveDraft() async {
    final l10n = AppLocalizations.of(context);
    final orders = ref.read(orderRepositoryProvider);

    if (_isEditing) {
      await orders.updateDraft(
        widget.existing!.id,
        supplierId: _supplierId,
        lines: _toLines(),
        note: _note,
      );

      if (!mounted) return;
      _snapshot();
      AppSnackBar.success(context, l10n.orderDraftUpdated);
      context.backTo(Routes.toOrders(widget.storeId));
      return;
    }

    final order = await orders.createDraft(
      storeId: widget.storeId,
      supplierId: _supplierId!,
      lines: _toLines(),
      note: _note,
    );

    if (!mounted) return;
    _snapshot();
    AppSnackBar.success(context, l10n.orderDraftSaved);
    context.replaceScreen(Routes.toOrder(widget.storeId, order.id));
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final orders = ref.read(orderRepositoryProvider);
    final supplierName = _supplierName(_supplierId!);

    // Sending is irreversible in the sense that matters: the supplier now has
    // the document, and the order locks.
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.orderSendConfirmTitle(supplierName),
      message: l10n.orderSendConfirmBody,
      confirmLabel: l10n.orderSendConfirmAction,
    );
    if (!confirmed || !mounted) return;

    final String orderId;
    if (_isEditing) {
      orderId = widget.existing!.id;
      await orders.updateDraft(
        orderId,
        supplierId: _supplierId,
        lines: _toLines(),
        note: _note,
      );
    } else {
      final created = await orders.createDraft(
        storeId: widget.storeId,
        supplierId: _supplierId!,
        lines: _toLines(),
        note: _note,
      );
      orderId = created.id;
    }

    await orders.send(orderId);
    if (!mounted) return;

    _snapshot();
    AppSnackBar.success(context, l10n.orderSent(supplierName));
    context.replaceScreen(Routes.toOrder(widget.storeId, orderId));
  }

  /// The chosen supplier's name, from the offers already on screen.
  ///
  /// Falls back to the picker's own list on the first frame after choosing,
  /// before the offers for the new supplier have arrived.
  String _supplierName(String supplierId) {
    final suppliers = ref.read(suppliersProvider(widget.storeId)).value;
    for (final supplier in suppliers ?? const []) {
      if (supplier.id == supplierId) return supplier.name;
    }
    return '—';
  }

  /// The unit one line's article is measured in, from the offers on screen.
  String _unitOf(String itemId) {
    for (final offer in _offers) {
      if (offer.price.itemId == itemId) return offer.unitAbbreviation;
    }
    return '';
  }
}

/// Step one: who is this order going to.
///
/// A full step rather than a field halfway down the form, because everything
/// after it depends on the answer — the item picker is filtered by supplier and
/// every price is auto-filled from them.
class _SupplierStep extends ConsumerStatefulWidget {
  const _SupplierStep({required this.storeId, required this.onChosen});

  final String storeId;
  final ValueChanged<String> onChosen;

  @override
  ConsumerState<_SupplierStep> createState() => _SupplierStepState();
}

class _SupplierStepState extends ConsumerState<_SupplierStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();

    final rows =
        ref.watch(supplierRowsProvider(widget.storeId)).value ??
        const <SupplierRowView>[];

    final suppliers = [
      for (final row in rows)
        if (query.isEmpty ||
            row.supplier.name.toLowerCase().contains(query) ||
            row.supplier.city.toLowerCase().contains(query))
          row,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.orderStepSupplier,
          subtitle: l10n.orderSupplierPromptBody,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SearchField(
            hint: l10n.orderSupplierSearchHint,
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (suppliers.isEmpty)
          EmptyState.noResults(l10n)
        else
          for (final row in suppliers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => widget.onChosen(row.supplier.id),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.truck,
                      size: AppSizing.iconMd,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.supplier.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${row.supplier.contactName} · ${row.supplier.city}',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      l10n.suppliersProductCount(row.productCount),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: AppSizing.iconSm,
                      color: AppColors.textDisabled,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// The chosen supplier, with a way back to the picker.
class _ChosenSupplier extends StatelessWidget {
  const _ChosenSupplier({required this.name, required this.onChange});

  final String name;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      child: AdaptiveRow(
        cells: [
          AdaptiveCell(
            flex: 1,
            // The medallion and the name stay together whatever the width;
            // only "Modifier" drops to its own line.
            child: Row(
              children: [
                Container(
                  width: AppSizing.statTileMedallion,
                  height: AppSizing.statTileMedallion,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.truck,
                    size: AppSizing.iconMd,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.orderStepSupplier,
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AdaptiveCell(
            child: SecondaryButton(
              label: l10n.orderSupplierChange,
              icon: LucideIcons.pencil,
              onPressed: onChange,
            ),
          ),
        ],
      ),
    );
  }
}
