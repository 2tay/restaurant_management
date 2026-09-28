import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/item_image_field.dart';
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

    final data = asyncAll4(
      existing,
      ref.watch(categoriesProvider(storeId)),
      ref.watch(unitsProvider(storeId)),
      // Waited on for the same reason as the other two: an article whose
      // default supplier is already set would hand the dropdown a value its
      // options did not contain yet, and that throws.
      ref.watch(suppliersProvider(storeId)),
      (item, categories, units, suppliers) => (
        item: item,
        categories: categories,
        units: units,
        suppliers: suppliers,
      ),
    );

    return AsyncContent<
      ({
        Item? item,
        List<Category> categories,
        List<UnitOfMeasure> units,
        List<Supplier> suppliers,
      })
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
        ref.invalidate(suppliersProvider(storeId));
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
        suppliers: data.suppliers,
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
    required this.suppliers,
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

  /// Every supplier of the establishment, for the default-supplier picker.
  final List<Supplier> suppliers;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _barcodeController = TextEditingController();

  /// Set when the entered barcode already belongs to another item. Validated at
  /// save time rather than on every keystroke — flagging a duplicate while
  /// somebody is still halfway through typing one is noise.
  String? _barcodeConflictName;

  /// Set when the maximum is at or below the alert threshold. Same timing as
  /// the barcode conflict, and for the same reason: a form that complains
  /// while the number is still being typed complains about every number.
  bool _maxBelowThreshold = false;

  /// Set at save time when an explicit busy-week minimum does not clear the
  /// ordinary one, which would make it useless.
  bool _holidayBelowThreshold = false;

  /// Set at save time when the minimum is still zero.
  ///
  /// Both bounds are required. They were optional, and a maximum of zero meant
  /// "no ceiling" — which left the stock gauge with no range to draw and the
  /// ordering screen guessing a top-up from the threshold alone. A product
  /// without a floor and a ceiling cannot be reasoned about, so the form asks
  /// for both rather than inventing either.
  bool _thresholdMissing = false;

  String? _categoryId;
  String? _unitId;
  /// The picker's stand-in for "no preference".
  ///
  /// A dropdown cannot carry null as a selectable option — null is what it
  /// shows the hint for — so clearing needs a value of its own, translated
  /// back to null on the way into the state.
  static const String _noSupplier = '__no_supplier__';

  String? _defaultSupplierId;

  /// The photo as it stands: the stored name on an edit, the name of a freshly
  /// copied file once one is picked, null when there is none.
  String? _imagePath;

  /// The quantity on hand. Displayed on edit, never edited here — see the
  /// note at its call site. On create it is simply zero: this form describes
  /// the product, and stock arrives through a receipt or an adjustment.
  double _quantity = 0;
  double _threshold = 0;
  double _maxStock = 0;

  /// Zero means "not set", and is stored as null — see `holidayMinimumOf`.
  /// The stepper has no other way to say "leave it to follow the minimum".
  double _holidayMinimum = 0;

  // Snapshot taken in initState. The dirty check compares against these rather
  // than tracking a flag, so undoing an edit back to its original value
  // correctly stops counting as unsaved.
  String _initialName = '';
  String _initialNote = '';
  String _initialBarcode = '';
  String? _initialCategoryId;
  String? _initialUnitId;
  String? _initialDefaultSupplierId;
  String? _initialImagePath;
  double _initialThreshold = 0;
  double _initialMaxStock = 0;
  double _initialHolidayMinimum = 0;

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
      _maxStock = existing.maxStock;
      _holidayMinimum = existing.holidayLowStockThreshold ?? 0;
      _defaultSupplierId = existing.defaultSupplierId;
      _imagePath = existing.imagePath;
    }

    _initialName = _nameController.text.trim();
    _initialNote = _noteController.text.trim();
    _initialBarcode = _barcodeController.text.trim();
    _initialCategoryId = _categoryId;
    _initialUnitId = _unitId;
    _initialThreshold = _threshold;
    _initialMaxStock = _maxStock;
    _initialHolidayMinimum = _holidayMinimum;
    _initialDefaultSupplierId = _defaultSupplierId;
    _initialImagePath = _imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _barcodeController.dispose();
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
      _categoryId != _initialCategoryId ||
      _unitId != _initialUnitId ||
      _threshold != _initialThreshold ||
      _maxStock != _initialMaxStock ||
      _holidayMinimum != _initialHolidayMinimum ||
      _defaultSupplierId != _initialDefaultSupplierId ||
      _imagePath != _initialImagePath;

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
          // Four blocks instead of one run of ten fields. The stock rules in
          // particular were lost between a barcode and a note; they decide when
          // the product is flagged and how much a commande orders, and they
          // deserve to be findable as a group.
          _FormSection(
            title: l10n.itemFormSectionIdentity,
            children: [
                // First, because it is the only field somebody can answer
                // without reading a label, and because the product grid is now
                // mostly photographs — a form that buried this under six text
                // fields would keep producing products that look empty there.
                ItemImageField(
                  imagePath: _imagePath,
                  onChanged: (value) => setState(() => _imagePath = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l10n.itemFormName,
                  controller: _nameController,
                  hint: l10n.itemFormNameHint,
                  autofocus: !_isEditing,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Optional, and the label says so. Most restaurant stock —
                // produce, meat, fish, bread — arrives loose with nothing to
                // scan, so a field that looked required would be wrong far more
                // often than it was right.
                //
                // It sits with the name because that is what it is: another way
                // of naming this exact product.
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
          const SizedBox(height: AppSpacing.lg),

          _FormSection(
            title: l10n.itemFormSectionClassification,
            children: [
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

                // A preference, not a price. Which supplier is pre-selected
                // when a delivery is received; what any of them charges is an
                // item–supplier link and lives on its own screen, which is
                // what the notice at the bottom of this form explains.
                //
                // **Editing only.** A product being created has no supplier
                // links yet — they are made on the "associer un fournisseur"
                // screen, which needs the product to exist first — so at
                // creation this could only ever offer a preference between
                // suppliers that do not sell the product. It stayed at "Aucun"
                // because "Aucun" was the only honest answer available.
                //
                // "Aucun" remains a real answer on an edit, and picking it
                // clears the preference: that is what the empty option in the
                // list is for.
                if (_isEditing) ...[
                  AppDropdown<String>(
                    label: l10n.itemDefaultSupplierLabel,
                    value: _defaultSupplierId,
                    options: [
                      DropdownOption(
                        value: _noSupplier,
                        label: l10n.itemDefaultSupplierNone,
                      ),
                      for (final supplier in widget.suppliers)
                        DropdownOption(
                          value: supplier.id,
                          label: supplier.name,
                        ),
                    ],
                    hint: l10n.itemDefaultSupplierNone,
                    onChanged: (value) => setState(
                      () => _defaultSupplierId = value == _noSupplier
                          ? null
                          : value,
                    ),
                  ),
                ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _FormSection(
            title: l10n.itemFormSectionLevels,
            children: [
                // The quantity appears here on an edit and nowhere on a create,
                // because this form describes the product rather than its
                // stock.
                //
                // Dragging a stepper from 40 to 35 on a routine edit form would
                // be an untraceable stock change: the most consequential thing
                // in the app, done by accident, with nothing in the movement
                // log to explain it. Adjusting stock has its own screen, and it
                // asks for the counted figure and leaves a record.
                //
                // A new product therefore starts at zero and reads as "Rupture
                // de stock" until a receipt or an adjustment says otherwise.
                // That is the truth — you have none of it yet — and it is
                // preferred over a friendlier-looking state that would have to
                // be invented.
                if (_isEditing) ...[
                  Text(
                    l10n.itemOnHandLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _QuantityFact(
                    value: Formatters.quantityWithUnit(
                      _quantity,
                      unitAbbreviation,
                    ),
                    onAdjust: () =>
                        context.pushScreen(Routes.toAdjustment(widget.storeId)),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Text(
                  l10n.itemThresholdLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                QuantityStepper(
                  value: _threshold,
                  unitAbbreviation: unitAbbreviation,
                  onChanged: (value) => setState(() {
                    _threshold = value;
                    _maxBelowThreshold = false;
                    _thresholdMissing = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _thresholdMissing
                      ? l10n.itemFormThresholdRequired
                      : l10n.itemFormThresholdHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _thresholdMissing
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),

                // The ceiling, immediately under the floor it has to clear.
                // Ordering only the shortfall below the threshold refills a
                // product to exactly its alert line, where the next portion
                // sold makes it low again. The maximum is what a commande tops
                // up *to* instead.
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l10n.itemMaxStockLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                QuantityStepper(
                  value: _maxStock,
                  unitAbbreviation: unitAbbreviation,
                  onChanged: (value) => setState(() {
                    _maxStock = value;
                    _maxBelowThreshold = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _maxBelowThreshold
                      ? l10n.itemFormMaxStockInvalid
                      : l10n.itemFormMaxStockHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _maxBelowThreshold
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),

                // The busy-week minimum: a holiday, a festival, the run-up to
                // a long weekend. Optional, and left alone it follows twice the
                // ordinary minimum rather than being written down — so raising
                // the minimum later raises this too.
                //
                // Nothing reads it yet. It is captured now so the figure is
                // already there when the app starts using it.
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l10n.itemHolidayMinLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                QuantityStepper(
                  value: _holidayMinimum,
                  unitAbbreviation: unitAbbreviation,
                  onChanged: (value) => setState(() {
                    _holidayMinimum = value;
                    _holidayBelowThreshold = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _holidayBelowThreshold
                      ? l10n.itemHolidayMinInvalid
                      // Names the figure it falls back to, worked out from the
                      // minimum currently typed above — so the default is
                      // visible without being written into the field, where
                      // nobody would remember they had not chosen it.
                      : l10n.itemHolidayMinHelp(
                          Formatters.quantityWithUnit(
                            _threshold * 2,
                            unitAbbreviation,
                          ),
                        ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _holidayBelowThreshold
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _FormSection(
            title: l10n.itemFormSectionNote,
            children: [
              AppTextField(
                label: l10n.itemNoteLabel,
                controller: _noteController,
                maxLines: 3,
              ),
            ],
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

    // Both bounds are required, and the maximum has to clear the minimum.
    //
    // Zero used to be allowed on both and meant "not set". That made the pair
    // unusable everywhere they are read: a gauge cannot draw a range with no
    // ceiling, and the ordering screen fell back to guessing a top-up from the
    // minimum alone. A maximum at or below the minimum is worse than unset —
    // it is a contradiction, and would have a commande suggest a zero or
    // negative top-up for a product already flagged as low.
    //
    // Both are checked before either returns, so somebody who left the whole
    // section alone sees what is wrong with it in one pass rather than being
    // sent back twice.
    final problems = stockRangeProblems(
      minimum: _threshold,
      maximum: _maxStock,
    );
    // A busy week needs more than an ordinary one, so an explicit figure that
    // does not clear the ordinary minimum is not a busy-week minimum. Zero is
    // the exception and means "not set", which is the field's default state.
    final holidayTooLow =
        _holidayMinimum > 0 && _holidayMinimum <= _threshold;
    if (problems.minimumMissing || problems.maximumTooLow || holidayTooLow) {
      setState(() {
        _thresholdMissing = problems.minimumMissing;
        _maxBelowThreshold = problems.maximumTooLow;
        _holidayBelowThreshold = holidayTooLow;
      });
      return;
    }

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
        maxStock: _maxStock,
        holidayLowStockThreshold: _holidayMinimum > 0 ? _holidayMinimum : null,
        // Emptying the field puts the product back to following twice its
        // ordinary minimum, rather than leaving the last figure behind.
        clearHolidayMinimum: _holidayMinimum <= 0,
        barcode: barcode,
        clearBarcode: barcode.isEmpty,
        note: note,
        clearNote: note.isEmpty,
        defaultSupplierId: _defaultSupplierId,
        clearDefaultSupplier: _defaultSupplierId == null,
        imagePath: _imagePath,
        clearImage: _imagePath == null,
      );
    } else {
      final created = await items.create(
        storeId: widget.storeId,
        name: _nameController.text.trim(),
        categoryId: _categoryId!,
        unitId: _unitId!,
        // No quantity and no opening cost: this form describes the product.
        // The article is created empty and with an unknown cost, and both are
        // answered by the first receipt or adjustment — the screens that leave
        // a movement behind saying where the stock came from and what it cost.
        lowStockThreshold: _threshold,
        maxStock: _maxStock,
        holidayLowStockThreshold: _holidayMinimum > 0 ? _holidayMinimum : null,
        barcode: barcode.isEmpty ? null : barcode,
        note: note.isEmpty ? null : note,
        // No default supplier: the field is edit-only, because a product being
        // created has no supplier links for a preference to be about.
        imagePath: _imagePath,
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

    // The figure and the button do not fit one line on a phone: "Ajuster le
    // stock" with its icon is most of a 296dp content area on its own.
    return AdaptiveRow(
      cells: [
        AdaptiveCell(
          flex: 1,
          child: Text(value, style: AppTypography.numericMedium),
        ),
        AdaptiveCell(
          child: SecondaryButton(
            label: l10n.itemFormAdjustStock,
            icon: LucideIcons.clipboardCheck,
            onPressed: onAdjust,
          ),
        ),
      ],
    );
  }
}

/// One block of the product form: a small heading over a card of fields.
///
/// The form was a single card of ten fields, where a barcode and a note sat
/// between the rules that decide when a product is flagged and how much a
/// commande orders. Blocks make those rules findable as a group, and give the
/// eye somewhere to rest on a form long enough to scroll.
///
/// The heading is outside the card rather than inside it, so it reads as a
/// label on the group rather than as a first field.
class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
