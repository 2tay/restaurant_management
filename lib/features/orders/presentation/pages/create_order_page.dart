import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/busy_calendar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../stock_movement/presentation/widgets/picker/product_picker_sheet.dart';
import '../widgets/order_detail_view.dart';
import '../widgets/order_line_editor.dart';
import '../widgets/order_visuals.dart';
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
    this.forBusyDays = false,
    super.key,
  });

  final String storeId;

  /// Pre-selects a supplier. Set when arriving from the low stock alerts
  /// screen, which already knows who to order from.
  final String? initialSupplierId;

  /// Also adds that supplier's low-stock items straight away — the point of
  /// coming here from the alerts screen.
  final bool prefillSuggested;

  /// Suggests against the busy-day minimum instead of the ordinary one — set
  /// when arriving from the alerts screen's "Jours chargés" list, whose
  /// products may not be low on an ordinary day at all.
  final bool forBusyDays;

  @override
  Widget build(BuildContext context) {
    return OrderFormPage(
      storeId: storeId,
      initialSupplierId: initialSupplierId,
      prefillSuggested: prefillSuggested,
      forBusyDays: forBusyDays,
    );
  }
}

/// Opens « Nouvelle commande » as a pop-up over the screen it was asked from,
/// the same [WizardDialog] as « Ajouter un employé »: Fournisseur, Produits,
/// Récapitulatif, then Envoyer — or Enregistrer le brouillon.
///
/// Resolves to the new commande's id, or null when the dialog was closed
/// without saving. The caller decides where to show it.
Future<String?> showCreateOrderWizard(
  BuildContext context, {
  required String storeId,
  String? initialSupplierId,
}) {
  return WizardDialog.show<String>(
    context,
    builder: (_) => _OrderForm(
      storeId: storeId,
      existing: null,
      initialSupplierId: initialSupplierId,
      prefillSuggested: false,
      asDialog: true,
    ),
  );
}

/// Opens « Nouvelle commande » as a pop-up and, once it is saved or sent,
/// shows the new commande in a panel over the screen that asked for it.
Future<void> createOrder(
  BuildContext context, {
  required String storeId,
  String? supplierId,
}) async {
  final orderId = await showCreateOrderWizard(
    context,
    storeId: storeId,
    initialSupplierId: supplierId,
  );
  if (orderId == null || !context.mounted) return;
  await openOrderPanel(context, storeId: storeId, orderId: orderId);
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
    this.forBusyDays = false,
    super.key,
  });

  final String storeId;

  /// Null when creating. Editing anything that is not a draft is refused — the
  /// supplier already holds a copy of a sent order.
  final String? orderId;

  final String? initialSupplierId;
  final bool prefillSuggested;
  final bool forBusyDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orderId == null) {
      return _OrderForm(
        storeId: storeId,
        existing: null,
        initialSupplierId: initialSupplierId,
        prefillSuggested: prefillSuggested,
        forBusyDays: forBusyDays,
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
      forBusyDays: forBusyDays,
    );
  }
}

class _OrderForm extends ConsumerStatefulWidget {
  const _OrderForm({
    required this.storeId,
    required this.existing,
    required this.initialSupplierId,
    required this.prefillSuggested,
    this.forBusyDays = false,
    this.asDialog = false,
    super.key,
  });

  final String storeId;

  /// In a [WizardDialog] rather than a page. Saving then closes the dialog
  /// with the commande's id instead of navigating.
  final bool asDialog;

  /// The draft being edited, or null when creating.
  final PurchaseOrder? existing;

  final String? initialSupplierId;
  final bool prefillSuggested;
  final bool forBusyDays;

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

  /// On the third step — the summary before sending.
  bool _reviewing = false;

  /// The pop-up's note field, shown once « Ajouter une note » is tapped.
  bool _showNote = false;

  /// 0 supplier, 1 products, 2 summary.
  int get _step => _supplierId == null || _pickingSupplier
      ? 0
      : _reviewing
      ? 2
      : 1;

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
          quantity: widget.forBusyDays
              ? busyTopUpQuantity(item)
              : topUpQuantity(item),
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

  /// Moves to a wizard step: back to the supplier, to the products, or on to
  /// the summary.
  void _goToStep(int target) => setState(() {
    _pickingSupplier = target == 0;
    _reviewing = target == 2;
  });

  /// Empties the form back to where it opened.
  void _reset() => setState(() {
    for (final line in _lines) {
      line.dispose();
    }
    _lines.clear();
    _noteController.clear();
    _supplierId = widget.initialSupplierId;
    _pickingSupplier = false;
    _reviewing = false;
    _showNote = false;
  });

  Widget _dialog(BuildContext context, AppLocalizations l10n) {
    final step = _step;

    return WizardDialog(
      title: l10n.createOrderTitle,
      description: l10n.createOrderDescription,
      currentStep: step,
      onStepChanged: _goToStep,
      steps: [
        WizardStep(
          label: l10n.orderStepSupplier,
          isValid: _supplierId != null,
          child: step == 0
              ? _SupplierStep(
                  storeId: widget.storeId,
                  onChosen: _chooseSupplier,
                )
              : const SizedBox.shrink(),
        ),
        // Only the step on screen is built: the products and the summary
        // both need a chosen supplier.
        WizardStep(
          label: l10n.orderStepProducts,
          isValid: _canSubmit,
          child: step == 1
              ? _productsStep(context, l10n)
              : const SizedBox.shrink(),
        ),
        WizardStep(
          label: l10n.orderStepReview,
          child: step == 2
              ? _reviewStep(context, l10n)
              : const SizedBox.shrink(),
        ),
      ],
      submitLabel: l10n.orderActionSend,
      submitIcon: LucideIcons.send,
      onSubmit: _canSubmit ? _send : null,
      extraActions: [
        if (step == 2)
          SecondaryButton(
            label: l10n.orderActionSaveDraft,
            icon: LucideIcons.check,
            tone: SecondaryButtonTone.surface,
            onPressed: _canSubmit ? _saveDraft : null,
          ),
      ],
      isDirty: _isDirty,
      onReset: _reset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.asDialog) return _dialog(context, l10n);

    final back = BackDestination(
      label: l10n.ordersTitle,
      path: Routes.toOrders(widget.storeId),
    );
    final title = _isEditing ? l10n.editOrderTitle : l10n.createOrderTitle;

    final step = _step;
    final saveDraft = SecondaryButton(
      label: l10n.orderActionSaveDraft,
      icon: LucideIcons.check,
      onPressed: _canSubmit ? _saveDraft : null,
    );

    return FormScaffold(
      title: title,
      back: back,
      crumbs: [
        Crumb(l10n.ordersTitle, Routes.toOrders(widget.storeId)),
        Crumb(title),
      ],
      // Continue through the steps; send only from the summary, once the
      // whole order has been read back.
      submitLabel: step == 2 ? l10n.orderActionSend : l10n.orderContinue,
      submitIcon: step == 2 ? LucideIcons.send : LucideIcons.arrowRight,
      onSubmit: switch (step) {
        0 => null,
        1 => _canSubmit ? () => setState(() => _reviewing = true) : null,
        _ => _canSubmit ? _send : null,
      },
      submitSecondary: step == 0 ? null : saveDraft,
      isDirty: _isDirty,
      maxWidth: 1080,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepIndicator(
            current: step,
            labels: [
              l10n.orderStepSupplier,
              l10n.orderStepProducts,
              l10n.orderStepReview,
            ],
            // Back to a step already done; never ahead of the current one.
            onTap: (target) => setState(() {
              if (target == 0) {
                _pickingSupplier = true;
                _reviewing = false;
              } else if (target == 1) {
                _pickingSupplier = false;
                _reviewing = false;
              }
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          switch (step) {
            0 => _SupplierStep(
              storeId: widget.storeId,
              onChosen: _chooseSupplier,
            ),
            1 => _linesStep(context, l10n),
            _ => _reviewStep(context, l10n),
          },
        ],
      ),
    );
  }

  /// Step 3: the order read back — supplier, every line, the note, the
  /// total — before it goes.
  Widget _reviewStep(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final supplierName = _supplierName(_supplierId!);
    final note = _note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChosenSupplier(
          name: supplierName,
          onChange: () => setState(() {
            _pickingSupplier = true;
            _reviewing = false;
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: l10n.orderStepProducts,
          count: _lines.length,
          trailing: SecondaryButton(
            label: l10n.orderEditProducts,
            icon: LucideIcons.pencil,
            onPressed: () => setState(() => _reviewing = false),
          ),
        ),
        AppTable<OrderLineDraft>(
          rows: _lines,
          shrinkWrap: true,
          columns: [
            AppTableColumn(label: l10n.tableColProduct, flex: 3),
            AppTableColumn(
              label: l10n.orderDocColumnQuantity,
              width: 120,
              numeric: true,
            ),
            AppTableColumn(
              label: l10n.orderDocColumnUnitPrice,
              width: 120,
              numeric: true,
              minTableWidth: 520,
            ),
            AppTableColumn(
              label: l10n.orderDocColumnTotal,
              width: 112,
              numeric: true,
            ),
          ],
          cell: (context, line, column) => switch (column) {
            0 => Text(
              _itemNameOf(line.itemId),
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            1 => Text(
              Formatters.quantityWithUnit(line.quantity, _unitOf(line.itemId)),
              style: AppTypography.numeric,
            ),
            2 => Text(
              Formatters.price(line.unitPrice),
              style: AppTypography.numeric,
            ),
            _ => Text(
              Formatters.price(line.total),
              style: AppTypography.numeric.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          },
        ),
        if (note != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.orderNoteLabel, style: theme.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(note, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.orderTotalLabel,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(Formatters.price(_total), style: AppTypography.numericHero),
            ],
          ),
        ),
      ],
    );
  }

  String _itemNameOf(String itemId) {
    for (final offer in _offers) {
      if (offer.price.itemId == itemId) return offer.itemName;
    }
    return '—';
  }

  /// Opens the product picker — the same photo cards as the movement forms —
  /// limited to what this supplier sells.
  Future<void> _pickProducts() async {
    final l10n = AppLocalizations.of(context);
    final picked = await ProductPickerSheet.show(
      context,
      storeId: widget.storeId,
      alreadyPicked: {for (final line in _lines) line.itemId},
      onlyItemIds: {for (final offer in _offers) offer.price.itemId},
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _addItems([for (final row in picked) row.item]));
    AppSnackBar.success(context, l10n.orderSuggestedAdded(picked.length));
  }

  /// Step 2 in the pop-up, kept to one way of doing each thing: a tile that
  /// opens the product picker, the low-stock suggestions as chips you tap to
  /// add, and one compact row per product — photo, name, price, quantity,
  /// total. The note hides behind a link until it is wanted.
  Widget _productsStep(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final suggestions = _watchProducts();
    final supplierId = _supplierId!;
    final supplierName = _supplierName(supplierId);
    final chosen = {for (final line in _lines) line.itemId};
    final remaining = [
      for (final row in suggestions)
        if (!chosen.contains(row.item.id)) row,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Who it goes to; tapping it goes back to choose another.
        Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: l10n.orderSupplierChange,
            child: InkWell(
              borderRadius: AppRadius.pillAll,
              onTap: () => setState(() => _pickingSupplier = true),
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.pillAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SupplierMonogram(name: supplierName, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        supplierName,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      LucideIcons.pencil,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        _AddProductsTile(
          label: l10n.orderAddProductsTile,
          onTap: _availableItems().isEmpty ? null : _pickProducts,
        ),

        if (remaining.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _LowStockChips(
            rows: remaining,
            onAdd: (item) => setState(() => _addItems([item])),
            onAddAll: () {
              setState(() => _addItems([for (final r in remaining) r.item]));
              AppSnackBar.success(
                context,
                l10n.orderSuggestedAdded(remaining.length),
              );
            },
          ),
        ],

        if (_lines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, line) in _lines.indexed) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.hairline),
                  _CompactLine(
                    key: ValueKey(line.id),
                    draft: line,
                    name: _itemNameOf(line.itemId),
                    imagePath: _stockById[line.itemId]?.imagePath,
                    unit: _unitOf(line.itemId),
                    onQuantityChanged: (value) =>
                        setState(() => line.quantity = value),
                    onPriceChanged: () => setState(() {}),
                    onRemove: () => _removeLine(line),
                  ),
                ],
                // The commitment, under the lines it adds up.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.hairline)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.orderPanelItems(_lines.length),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        l10n.orderTotalLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        Formatters.price(_total),
                        style: AppTypography.numeric.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        if (_showNote || _noteController.text.isNotEmpty)
          AppTextField(
            label: l10n.orderNoteLabel,
            controller: _noteController,
            hint: l10n.orderNoteHint,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showNote = true),
              icon: const Icon(LucideIcons.stickyNote, size: 16),
              label: Text(l10n.orderAddNote),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  /// Watches what the products step shows — the supplier's offers, their
  /// articles, the low-stock suggestions — and prefills once when asked to.
  /// Returns the suggestions.
  List<ItemRowView> _watchProducts() {
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
        ref
            .watch(
              itemRowsProvider((
                storeId: widget.storeId,
                filter: ItemFilter(
                  supplierId: supplierId,
                  lowStockOnly: !widget.forBusyDays,
                  belowBusyMinimumOnly: widget.forBusyDays,
                ),
              )),
            )
            .value ??
        const <ItemRowView>[];

    // The alerts screen sends people here with "fill it in for me". Done on
    // the first build that has the suggestions, since `initState` could not
    // wait for the query.
    if (!_prefilled && widget.prefillSuggested && suggestions.isNotEmpty) {
      _prefilled = true;
      _addItems([for (final row in suggestions) row.item]);
      _snapshot();
    }

    return suggestions;
  }

  Widget _linesStep(BuildContext context, AppLocalizations l10n) {
    final supplierId = _supplierId!;
    final suggestions = _watchProducts();

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
          trailing: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SecondaryButton(
                label: l10n.orderPickProducts,
                icon: LucideIcons.layoutGrid,
                onPressed: _availableItems().isEmpty ? null : _pickProducts,
              ),
              SecondaryButton(
                label: l10n.orderAddLine,
                icon: LucideIcons.plus,
                onPressed: _availableItems().isEmpty ? null : _addEmptyLine,
              ),
            ],
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
    if (widget.asDialog) {
      Navigator.of(context).pop(order.id);
      return;
    }
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
    if (widget.asDialog) {
      Navigator.of(context).pop(orderId);
      return;
    }
    // An edit was opened from the order's page: back to it, not a second
    // copy of it on top.
    if (_isEditing) {
      context.backTo(Routes.toOrder(widget.storeId, orderId));
      return;
    }
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

/// "1 Fournisseur — 2 Produits — 3 Récapitulatif": where the form is, what
/// is done (ticked), and what comes next. A done step is tappable, to go back
/// to it; the next ones are not, since each needs the one before.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.current,
    required this.labels,
    required this.onTap,
  });

  final int current;
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget step(int index) {
      final done = index < current;
      final active = index == current;
      final circle = Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done || active ? AppColors.primary600 : AppColors.surface,
          border: Border.all(
            color: done || active ? AppColors.primary600 : AppColors.border,
          ),
        ),
        child: done
            ? const Icon(
                LucideIcons.check,
                size: AppSizing.iconSm,
                color: AppColors.white,
              )
            : Text(
                '${index + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
      );

      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              labels[index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      );

      return Flexible(
        child: done
            ? InkWell(
                onTap: () => onTap(index),
                borderRadius: AppRadius.mdAll,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: content,
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: content,
              ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                color: i <= current ? AppColors.primary600 : AppColors.border,
              ),
            ),
          step(i),
        ],
      ],
    );
  }
}

/// The supplier's low-stock products as chips: tap one to add it, or add
/// them all at once.
class _LowStockChips extends StatelessWidget {
  const _LowStockChips({
    required this.rows,
    required this.onAdd,
    required this.onAddAll,
  });

  final List<ItemRowView> rows;
  final ValueChanged<Item> onAdd;
  final VoidCallback onAddAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.lowStock.solid,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${l10n.orderSuggestedShort} (${rows.length})',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onAddAll,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(l10n.orderSuggestedAddAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final row in rows)
              ActionChip(
                avatar: const Icon(
                  LucideIcons.plus,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                label: Text(row.item.name),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
                onPressed: () => onAdd(row.item),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

/// The one way to add products: a wide tile that opens the photo picker.
class _AddProductsTile extends StatelessWidget {
  const _AddProductsTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = onTap == null ? AppColors.textDisabled : AppColors.textPrimary;

    return AppCard(
      onTap: onTap,
      elevated: false,
      dashedBorderColor: AppColors.borderStrong,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.plus, size: AppSizing.iconMd, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One product on the order: photo and name, the unit price (typed), the
/// quantity (stepped), the line total and a way to take it off.
///
/// One row with room; on a phone the price, quantity and total move under the
/// name.
class _CompactLine extends StatelessWidget {
  const _CompactLine({
    required this.draft,
    required this.name,
    required this.imagePath,
    required this.unit,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
    super.key,
  });

  final OrderLineDraft draft;
  final String name;
  final String? imagePath;
  final String unit;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onPriceChanged;
  final VoidCallback onRemove;

  static const double _stacksBelow = 600;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final photo = ProductImage(
      imagePath: imagePath,
      size: 44,
      radius: 10,
      placeholder: ProductImagePlaceholder.disc,
    );
    final title = Text(
      name,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final price = SizedBox(
      width: 112,
      child: TextField(
        controller: draft.priceController,
        onChanged: (_) => onPriceChanged(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        textAlign: TextAlign.right,
        style: AppTypography.numeric,
        decoration: InputDecoration(
          isDense: true,
          hintText: '0,00',
          suffixText: unit.isEmpty ? '€' : '€/$unit',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
    final quantity = QuantityStepper(
      value: draft.quantity,
      unitAbbreviation: unit,
      compact: true,
      onChanged: onQuantityChanged,
    );
    final total = SizedBox(
      width: 88,
      child: Text(
        Formatters.price(draft.total),
        textAlign: TextAlign.right,
        style: AppTypography.numeric.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
      ),
    );
    final remove = IconButton(
      onPressed: onRemove,
      tooltip: l10n.orderRemoveLine,
      icon: const Icon(LucideIcons.x, size: 18),
      color: AppColors.textSecondary,
      visualDensity: VisualDensity.compact,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _stacksBelow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    photo,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: title),
                    remove,
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [quantity, price, total],
                ),
              ],
            );
          }
          return Row(
            children: [
              photo,
              const SizedBox(width: AppSpacing.md),
              Expanded(child: title),
              const SizedBox(width: AppSpacing.md),
              price,
              const SizedBox(width: AppSpacing.md),
              quantity,
              const SizedBox(width: AppSpacing.md),
              total,
              remove,
            ],
          );
        },
      ),
    );
  }
}
