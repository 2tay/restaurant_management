import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../catalog/presentation/widgets/create_sheets.dart';

/// Create or edit an item.
///
/// **There is no cost field here, and that is the point.** Price belongs to the
/// item–supplier link, because the same product comes from several suppliers at
/// different prices. A cost field on this form would force a single number and
/// quietly destroy the app's most valuable feature.
///
/// Its absence is explained on screen rather than left as a puzzle — a
/// restaurant owner who has used any other inventory app will look for it.
class AddEditItemPage extends ConsumerWidget {
  const AddEditItemPage({required this.storeId, this.itemId, super.key});

  final String storeId;

  /// Null when creating.
  final String? itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Three things, and the form cannot be drawn without any of them.
    //
    // The article is obvious: `initState` fills the fields from it. The
    // categories and units are less so, and skipping them is a real bug rather
    // than a slow frame — a dropdown asked to show a selected value that is not
    // among its options throws, so an edit form drawn before its categories
    // arrive crashes on the article's own category. Creating waits for the same
    // two, since a form whose only two required fields have empty menus has
    // nothing to offer anyway.
    final existing = itemId == null
        ? const AsyncValue<Item?>.data(null)
        : ref.watch(itemProvider(itemId!));

    final data = asyncAll3(
      existing,
      ref.watch(categoriesProvider(storeId)),
      ref.watch(unitsProvider(storeId)),
      (item, categories, units) => (
        item: item,
        categories: categories,
        units: units,
      ),
    );

    return AsyncContent<
      ({Item? item, List<Category> categories, List<UnitOfMeasure> units})
    >(
      value: data,
      skeleton: FormScaffold(
        title: itemId == null ? l10n.addItemTitle : l10n.editItemTitle,
        back: BackDestination(
          label: l10n.inventoryTitle,
          path: Routes.toInventory(storeId),
        ),
        submitLabel: l10n.actionSave,
        onSubmit: null,
        child: const SkeletonList(rows: 4, rowHeight: 80),
      ),
      onRetry: () {
        if (itemId != null) ref.invalidate(itemProvider(itemId!));
        ref.invalidate(categoriesProvider(storeId));
        ref.invalidate(unitsProvider(storeId));
      },
      builder: (context, data) => _ItemForm(
        // Keyed on the article so opening a different one through the same
        // route rebuilds the state instead of keeping the last one's name in
        // the field.
        key: ValueKey(itemId),
        storeId: storeId,
        existing: data.item,
        categories: data.categories,
        units: data.units,
      ),
    );
  }
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({
    required this.storeId,
    required this.existing,
    required this.categories,
    required this.units,
    super.key,
  });

  final String storeId;

  /// Null when creating, and null too when the article being edited has been
  /// deleted from another screen — the form treats that as a create, which is
  /// the only thing left that it can usefully do.
  final Item? existing;

  /// Passed in rather than watched here, so the two menus are never empty while
  /// a value is selected. They still arrive live: creating a category from the
  /// inline row rebuilds the page above and hands this a longer list.
  final List<Category> categories;
  final List<UnitOfMeasure> units;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _barcodeController = TextEditingController();

  /// What the starting stock was bought at. Create-only, like the quantity it
  /// belongs to, and for the same reason: it is a fact about the opening
  /// balance, not a field that stays editable afterwards.
  final _openingCostController = TextEditingController();

  /// Set when the entered barcode already belongs to another item. Validated at
  /// save time rather than on every keystroke — flagging a duplicate while
  /// somebody is still halfway through typing one is noise.
  String? _barcodeConflictName;

  String? _categoryId;
  String? _unitId;
  double _quantity = 0;
  double _threshold = 0;

  // Snapshot taken in initState. The dirty check compares against these rather
  // than tracking a flag, so undoing an edit back to its original value
  // correctly stops counting as unsaved.
  String _initialName = '';
  String _initialNote = '';
  String _initialBarcode = '';
  String? _initialCategoryId;
  String? _initialUnitId;
  double _initialQuantity = 0;
  double _initialThreshold = 0;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    if (existing != null) {
      _nameController.text = existing.name;
      _noteController.text = existing.note ?? '';
      _barcodeController.text = existing.barcode ?? '';
      _categoryId = existing.categoryId;
      _unitId = existing.unitId;
      _quantity = existing.quantity;
      _threshold = existing.lowStockThreshold;
    }

    _initialName = _nameController.text.trim();
    _initialNote = _noteController.text.trim();
    _initialBarcode = _barcodeController.text.trim();
    _initialCategoryId = _categoryId;
    _initialUnitId = _unitId;
    _initialQuantity = _quantity;
    _initialThreshold = _threshold;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _barcodeController.dispose();
    _openingCostController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _categoryId != null &&
      _unitId != null;

  /// True once the user has typed or picked something worth protecting.
  bool get _isDirty =>
      _nameController.text.trim() != _initialName ||
      _noteController.text.trim() != _initialNote ||
      _barcodeController.text.trim() != _initialBarcode ||
      _openingCostController.text.trim().isNotEmpty ||
      _categoryId != _initialCategoryId ||
      _unitId != _initialUnitId ||
      _quantity != _initialQuantity ||
      _threshold != _initialThreshold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Read live rather than merged with a local list of pending creations:
    // the inline "+ Créer" row now creates the real record, so there is no
    // second kind of category to keep track of.
    final categories = [
      for (final c in widget.categories)
        DropdownOption(value: c.id, label: c.name),
    ];

    final units = [
      for (final u in widget.units)
        DropdownOption(
          value: u.id,
          label: u.name,
          secondaryLabel: u.abbreviation,
        ),
    ];

    var unitAbbreviation = '';
    for (final unit in widget.units) {
      if (unit.id == _unitId) unitAbbreviation = unit.abbreviation;
    }

    return FormScaffold(
      title: _isEditing ? l10n.editItemTitle : l10n.addItemTitle,
      back: BackDestination(
        label: l10n.inventoryTitle,
        path: Routes.toInventory(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.inventoryTitle, Routes.toInventory(widget.storeId)),
        Crumb(_isEditing ? l10n.editItemTitle : l10n.addItemTitle),
      ],
      submitLabel: l10n.actionSave,
      submitIcon: LucideIcons.check,
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _isDirty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: l10n.itemFormName,
                  controller: _nameController,
                  hint: l10n.itemFormNameHint,
                  autofocus: !_isEditing,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppDropdown<String>(
                        label: l10n.itemCategoryLabel,
                        value: _categoryId,
                        options: categories,
                        hint: l10n.inventoryFilterAll,
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                        onCreateNew: _createCategory,
                        createNewLabel: l10n.itemFormCreateCategory,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppDropdown<String>(
                        label: l10n.itemUnitLabel,
                        value: _unitId,
                        options: units,
                        onChanged: (value) => setState(() => _unitId = value),
                        onCreateNew: _createUnit,
                        createNewLabel: l10n.itemFormCreateUnit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Optional, and the label says so. Most restaurant stock —
                // produce, meat, fish, bread — arrives loose with nothing to
                // scan, so a field that looked required would be wrong far more
                // often than it was right.
                AppTextField(
                  label: l10n.itemBarcodeLabel,
                  controller: _barcodeController,
                  hint: l10n.itemBarcodeHint,
                  helperText: _barcodeConflictName == null
                      ? l10n.itemBarcodeHelp
                      : null,
                  errorText: _barcodeConflictName == null
                      ? null
                      : l10n.itemBarcodeDuplicate(_barcodeConflictName!),
                  // Numeric by default because most barcodes are digits, but
                  // input is *not* restricted to them: internal and regional
                  // codes contain letters, and a field that silently refuses a
                  // real barcode is worse than one that accepts a wrong one.
                  keyboardType: TextInputType.number,
                  suffixIcon: IconButton(
                    // The scan button's seat, kept warm. Disabled rather than
                    // absent so adding the camera later is a swap rather than a
                    // reflow of the field around a control that appeared.
                    onPressed: null,
                    tooltip: l10n.itemBarcodeScanTooltip,
                    icon: const Icon(LucideIcons.scanLine),
                  ),
                  onChanged: (_) => setState(() {
                    // Clearing on edit rather than on save: leaving a stale
                    // error under a field the user has already fixed is how a
                    // form starts feeling broken.
                    _barcodeConflictName = null;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing
                      ? l10n.itemOnHandLabel
                      : l10n.itemFormStartingQuantity,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                // Editable on create — the starting quantity is recorded as an
                // opening-balance movement — and read-only afterwards.
                //
                // Dragging a stepper from 40 to 35 on a routine edit form would
                // be an untraceable stock change: the most consequential thing
                // in the app, done by accident, with nothing in the movement
                // log to explain it. Adjusting stock has its own screen, and it
                // asks for the counted figure and leaves a record.
                if (_isEditing)
                  _QuantityFact(
                    value: Formatters.quantityWithUnit(
                      _quantity,
                      unitAbbreviation,
                    ),
                    onAdjust: () =>
                        context.pushScreen(Routes.toAdjustment(widget.storeId)),
                  )
                else
                  QuantityStepper(
                    value: _quantity,
                    unitAbbreviation: unitAbbreviation,
                    onChanged: (value) => setState(() => _quantity = value),
                  ),
                if (!_isEditing) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.itemFormOpeningBalanceHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // What that starting stock was bought at.
                  //
                  // Optional, and never blocks saving. Left empty the article
                  // simply has no known cost and is left out of the valuation
                  // until a delivery arrives — which is honest, and better than
                  // demanding a number the person adding the article may not
                  // have to hand.
                  AppTextField(
                    label: l10n.itemFormOpeningCost,
                    controller: _openingCostController,
                    hint: l10n.itemFormOpeningCostHint,
                    helperText: l10n.itemFormOpeningCostHelp,
                    suffixText: unitAbbreviation.isEmpty
                        ? Formatters.currencySymbol
                        : '${Formatters.currencySymbol} / $unitAbbreviation',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l10n.itemThresholdLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                QuantityStepper(
                  value: _threshold,
                  unitAbbreviation: unitAbbreviation,
                  onChanged: (value) => setState(() => _threshold = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.itemFormThresholdHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // The explanation for the missing cost field.
          _NoCostNotice(),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: AppTextField(
              label: l10n.itemNoteLabel,
              controller: _noteController,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  /// Creates a category and selects it, without the user leaving this form.
  ///
  /// The selection is the point: a cook halfway through adding "Persil plat"
  /// who needs a "botte" unit should not have to abandon the article, go to a
  /// settings screen, create the unit, and start again.
  Future<void> _createCategory() async {
    final created = await CreateSheets.category(
      context,
      storeId: widget.storeId,
    );
    if (created == null || !mounted) return;

    setState(() => _categoryId = created.id);
    AppSnackBar.success(context, AppLocalizations.of(context).categoryCreated);
  }

  Future<void> _createUnit() async {
    final created = await CreateSheets.unit(context, storeId: widget.storeId);
    if (created == null || !mounted) return;

    setState(() => _unitId = created.id);
    AppSnackBar.success(context, AppLocalizations.of(context).unitCreated);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final items = ref.read(itemRepositoryProvider);

    // Uniqueness is checked here rather than on every keystroke, and against
    // the other items of *this store* only — two shops can stock the same
    // product, and a barcode collision across them is not a collision.
    final barcode = _barcodeController.text.trim();
    if (barcode.isNotEmpty) {
      final conflict = await items.barcodeConflict(
        widget.storeId,
        barcode,
        // Excluding the item being edited is what lets somebody save an item
        // with its own barcode unchanged. Without it every edit would fail
        // against itself.
        excludingItemId: widget.existing?.id,
      );
      if (!mounted) return;
      if (conflict != null) {
        setState(() => _barcodeConflictName = conflict.name);
        return;
      }
    }

    final note = _noteController.text.trim();

    if (_isEditing) {
      await items.update(
        widget.existing!.id,
        name: _nameController.text.trim(),
        categoryId: _categoryId,
        unitId: _unitId,
        lowStockThreshold: _threshold,
        barcode: barcode,
        clearBarcode: barcode.isEmpty,
        note: note,
        clearNote: note.isEmpty,
      );
    } else {
      final created = await items.create(
        storeId: widget.storeId,
        name: _nameController.text.trim(),
        categoryId: _categoryId!,
        unitId: _unitId!,
        // Recorded as an opening-balance movement rather than written onto the
        // item, so the quantity and the movement log agree from day one.
        quantity: _quantity,
        // Blank, or something that is not a number yet, leaves the cost
        // unknown. Never blocks the save: an article is worth having in the
        // catalogue even when nobody remembers what it cost.
        openingUnitCost: Formatters.parseDecimal(_openingCostController.text),
        lowStockThreshold: _threshold,
        barcode: barcode.isEmpty ? null : barcode,
        note: note.isEmpty ? null : note,
      );
      if (created == null) return;
    }

    if (!mounted) return;
    AppSnackBar.success(
      context,
      _isEditing ? l10n.itemUpdated : l10n.itemCreated,
    );
    _leave();
  }

  void _leave() {
    if (_isEditing) {
      context.pushScreen(Routes.toItem(widget.storeId, widget.existing!.id));
    } else {
      context.goSection(Routes.toInventory(widget.storeId));
    }
  }
}

/// The quantity on an edit form: stated, with the correct way to change it.
///
/// Read-only by design — see the note at the call site.
class _QuantityFact extends StatelessWidget {
  const _QuantityFact({required this.value, required this.onAdjust});

  final String value;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(value, style: AppTypography.numericMedium),
        ),
        const SizedBox(width: AppSpacing.md),
        SecondaryButton(
          label: l10n.itemFormAdjustStock,
          icon: LucideIcons.clipboardCheck,
          onPressed: onAdjust,
        ),
      ],
    );
  }
}

class _NoCostNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.info,
            color: AppColors.onPrimaryContainer,
            size: AppSizing.iconLg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.itemFormNoCostTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.itemFormNoCostBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
