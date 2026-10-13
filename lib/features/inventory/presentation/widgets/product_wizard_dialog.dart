import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../barcode/presentation/barcode_camera_page.dart';
import '../../../barcode/presentation/barcode_support.dart';
import '../../../barcode/presentation/hardware_scan_listener.dart';
import '../../../catalog/presentation/widgets/create_sheets.dart';
import 'item_image_field.dart';

/// Create or edit a product, in a [WizardDialog] over the screen it was
/// opened from — the same pop-up « Ajouter un employé » uses, full screen on a
/// phone.
///
/// Four steps:
///
/// 1. **Identité** — the photo, the name and the barcode (typed, scanned by
///    the camera, or by a handheld scanner anywhere on the step).
/// 2. **Classification** — category and unit, created inline when missing;
///    the default supplier on an edit only (a new product has no supplier
///    links for a preference to be about).
/// 3. **Gestion stock** — the quantity on hand (an edit only, read-only:
///    stock changes through an adjustment, which leaves a movement), the
///    minimum, the maximum, the busy-week minimum, and the note.
/// 4. **Vérification** — everything above, read back before saving.
///
/// **There is no cost field, and that is the point.** Price belongs to the
/// item–supplier link, because the same product comes from several suppliers
/// at different prices.
///
/// Creating walks the steps in order; editing may jump to any step and save
/// from each ([WizardDialog.freeNavigation]).
///
/// Opened from a product drawer, the drawer closes first ([DrawerScope]).
///
/// Resolves to the saved product's id, or null when closed without saving.
Future<String?> showProductWizard(
  BuildContext context, {
  required String storeId,
  String? itemId,
  String? initialBarcode,
}) {
  // A drawer is about to go, and this context with it: show from the root
  // navigator, which stays.
  final navigator = Navigator.of(context, rootNavigator: true);
  DrawerScope.maybeOf(context)?.close();
  return WizardDialog.show<String>(
    navigator.context,
    builder: (_) => _ProductWizardLoader(
      storeId: storeId,
      itemId: itemId,
      initialBarcode: initialBarcode,
    ),
  );
}

/// Waits for the product, the categories, the units and the suppliers — a
/// dropdown asked to show a value its options do not contain yet throws, so
/// the form is never drawn before all four.
class _ProductWizardLoader extends ConsumerWidget {
  const _ProductWizardLoader({
    required this.storeId,
    this.itemId,
    this.initialBarcode,
  });

  final String storeId;
  final String? itemId;
  final String? initialBarcode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existing = itemId == null
        ? const AsyncValue<Item?>.data(null)
        : ref.watch(itemProvider(itemId!));

    final data = asyncAll4(
      existing,
      ref.watch(categoriesProvider(storeId)),
      ref.watch(unitsProvider(storeId)),
      ref.watch(suppliersProvider(storeId)),
      (item, categories, units, suppliers) => (
        item: item,
        categories: categories,
        units: units,
        suppliers: suppliers,
      ),
    );

    return data.when(
      data: (data) => _ProductForm(
        storeId: storeId,
        existing: data.item,
        categories: data.categories,
        units: data.units,
        suppliers: data.suppliers,
        initialBarcode: initialBarcode,
      ),
      loading: () => const Dialog(
        backgroundColor: AppColors.background,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            heightFactor: 1,
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, _) => Dialog(
        backgroundColor: AppColors.background,
        child: ErrorState(
          message: error.toString(),
          onRetry: () {
            if (itemId != null) ref.invalidate(itemProvider(itemId!));
            ref.invalidate(categoriesProvider(storeId));
            ref.invalidate(unitsProvider(storeId));
            ref.invalidate(suppliersProvider(storeId));
          },
        ),
      ),
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({
    required this.storeId,
    required this.existing,
    required this.categories,
    required this.units,
    required this.suppliers,
    this.initialBarcode,
  });

  final String storeId;
  final String? initialBarcode;

  /// Null when creating — and when the product being edited was deleted from
  /// another screen, which leaves a create as the only useful thing to do.
  final Item? existing;

  /// Passed in rather than watched here, so the menus are never empty while a
  /// value is selected. Still live: creating a category inline rebuilds the
  /// loader and hands this a longer list.
  final List<Category> categories;
  final List<UnitOfMeasure> units;
  final List<Supplier> suppliers;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _barcode = TextEditingController();

  /// The wizard step on screen.
  int _step = 0;

  /// Set at save time when the barcode already belongs to another product of
  /// this store — checked then rather than per keystroke, and the wizard goes
  /// back to step 1 to show it.
  String? _barcodeConflictName;

  String? _categoryId;
  String? _unitId;

  /// The picker's stand-in for "no preference": a dropdown cannot offer null
  /// as an option, so clearing needs a value of its own.
  static const String _noSupplier = '__no_supplier__';

  String? _defaultSupplierId;

  /// The stored photo name, or null for none.
  String? _imagePath;

  /// Shown on an edit, never edited here.
  double _quantity = 0;
  double _threshold = 0;
  double _maxStock = 0;

  /// Zero means "not set" — stored as null, and the product then follows
  /// twice its minimum.
  double _holidayMinimum = 0;

  // The snapshot the dirty check and Réinitialiser go back to.
  late final String _initialName;
  late final String _initialNote;
  late final String _initialBarcode;
  late final String? _initialCategoryId;
  late final String? _initialUnitId;
  late final String? _initialDefaultSupplierId;
  late final String? _initialImagePath;
  late final double _initialThreshold;
  late final double _initialMaxStock;
  late final double _initialHolidayMinimum;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _note.text = existing.note ?? '';
      _barcode.text = existing.barcode ?? '';
      _categoryId = existing.categoryId;
      _unitId = existing.unitId;
      _quantity = existing.quantity;
      _threshold = existing.lowStockThreshold;
      _maxStock = existing.maxStock;
      _holidayMinimum = existing.holidayLowStockThreshold ?? 0;
      _defaultSupplierId = existing.defaultSupplierId;
      _imagePath = existing.imagePath;
    } else if (widget.initialBarcode != null) {
      _barcode.text = widget.initialBarcode!.trim();
    }

    _initialName = _name.text.trim();
    _initialNote = _note.text.trim();
    _initialBarcode = _barcode.text.trim();
    _initialCategoryId = _categoryId;
    _initialUnitId = _unitId;
    _initialDefaultSupplierId = _defaultSupplierId;
    _initialImagePath = _imagePath;
    _initialThreshold = _threshold;
    _initialMaxStock = _maxStock;
    _initialHolidayMinimum = _holidayMinimum;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _barcode.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _name.text.trim() != _initialName ||
      _note.text.trim() != _initialNote ||
      _barcode.text.trim() != _initialBarcode ||
      _categoryId != _initialCategoryId ||
      _unitId != _initialUnitId ||
      _threshold != _initialThreshold ||
      _maxStock != _initialMaxStock ||
      _holidayMinimum != _initialHolidayMinimum ||
      _defaultSupplierId != _initialDefaultSupplierId ||
      _imagePath != _initialImagePath;

  // --- Step validity --------------------------------------------------------

  bool get _identityValid =>
      _name.text.trim().isNotEmpty && _barcodeConflictName == null;

  bool get _classificationValid => _categoryId != null && _unitId != null;

  ({bool minimumMissing, bool maximumTooLow}) get _rangeProblems =>
      stockRangeProblems(minimum: _threshold, maximum: _maxStock);

  /// An explicit busy-week minimum has to clear the ordinary one; zero is
  /// "not set" and always fine.
  bool get _holidayTooLow =>
      _holidayMinimum > 0 && _holidayMinimum <= _threshold;

  bool get _stockValid =>
      !_rangeProblems.minimumMissing &&
      !_rangeProblems.maximumTooLow &&
      !_holidayTooLow;

  // --- Actions --------------------------------------------------------------

  /// Every field back to what the dialog opened with, and step 1.
  void _reset() {
    setState(() {
      _name.text = _initialName;
      _note.text = _initialNote;
      _barcode.text = _initialBarcode;
      _categoryId = _initialCategoryId;
      _unitId = _initialUnitId;
      _defaultSupplierId = _initialDefaultSupplierId;
      _imagePath = _initialImagePath;
      _threshold = _initialThreshold;
      _maxStock = _initialMaxStock;
      _holidayMinimum = _initialHolidayMinimum;
      _barcodeConflictName = null;
      _step = 0;
    });
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeCameraPage.scanOnce(context);
    if (code != null && mounted) _setBarcode(code);
  }

  void _setBarcode(String code) {
    setState(() {
      _barcode.text = code.trim();
      _barcodeConflictName = null;
    });
  }

  /// Creates a category and selects it, without leaving the wizard.
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

  /// « Ajuster le stock » on an edit: the adjustment screen is a page, so
  /// the wizard closes first — asking before it drops anything typed.
  Future<void> _goAdjust() async {
    final l10n = AppLocalizations.of(context);
    if (_isDirty) {
      final leave = await ConfirmDialog.show(
        context,
        title: l10n.discardChangesTitle,
        message: l10n.discardChangesBody,
        confirmLabel: l10n.discardChangesConfirm,
        cancelLabel: l10n.discardChangesCancel,
      );
      if (!leave || !mounted) return;
    }
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push(Routes.toAdjustment(widget.storeId)));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final items = ref.read(itemRepositoryProvider);

    // Uniqueness against the other products of this store only; the product
    // being edited is excluded so it can keep its own code.
    final barcode = _barcode.text.trim();
    if (barcode.isNotEmpty) {
      final conflict = await items.barcodeConflict(
        widget.storeId,
        barcode,
        excludingItemId: widget.existing?.id,
      );
      if (!mounted) return;
      if (conflict != null) {
        setState(() {
          _barcodeConflictName = conflict.name;
          _step = 0;
        });
        return;
      }
    }

    final note = _note.text.trim();
    final String savedId;

    if (_isEditing) {
      savedId = widget.existing!.id;
      await items.update(
        savedId,
        name: _name.text.trim(),
        categoryId: _categoryId,
        unitId: _unitId,
        lowStockThreshold: _threshold,
        maxStock: _maxStock,
        holidayLowStockThreshold: _holidayMinimum > 0 ? _holidayMinimum : null,
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
      // No quantity and no cost: the product starts empty, and the first
      // receipt or adjustment says where its stock came from.
      final created = await items.create(
        storeId: widget.storeId,
        name: _name.text.trim(),
        categoryId: _categoryId!,
        unitId: _unitId!,
        lowStockThreshold: _threshold,
        maxStock: _maxStock,
        holidayLowStockThreshold: _holidayMinimum > 0 ? _holidayMinimum : null,
        barcode: barcode.isEmpty ? null : barcode,
        note: note.isEmpty ? null : note,
        imagePath: _imagePath,
      );
      if (created == null) return;
      savedId = created.id;
    }

    if (!mounted) return;
    AppSnackBar.success(
      context,
      _isEditing ? l10n.itemUpdated : l10n.itemCreated,
    );
    Navigator.of(context).pop(savedId);
  }

  // --- Build ----------------------------------------------------------------

  String get _unitAbbreviation {
    for (final unit in widget.units) {
      if (unit.id == _unitId) return unit.abbreviation;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final existing = widget.existing;

    return WizardDialog(
      title: _isEditing ? l10n.editItemTitle : l10n.addItemTitle,
      description: existing == null
          ? l10n.productFormDescription
          : l10n.productFormEditDescription(existing.name),
      currentStep: _step,
      onStepChanged: (step) => setState(() => _step = step),
      freeNavigation: _isEditing,
      submitLabel: l10n.actionSave,
      submitIcon: LucideIcons.check,
      onSubmit: _submit,
      isDirty: _isDirty,
      onReset: _reset,
      steps: [
        WizardStep(
          label: l10n.productWizardStepIdentity,
          isValid: _identityValid,
          child: _identityStep(l10n),
        ),
        WizardStep(
          label: l10n.productWizardStepClassification,
          isValid: _classificationValid,
          child: _classificationStep(l10n),
        ),
        WizardStep(
          label: l10n.productWizardStepStock,
          isValid: _stockValid,
          child: _stockStep(context, l10n),
        ),
        WizardStep(
          label: l10n.productWizardStepReview,
          child: _reviewStep(context, l10n),
        ),
      ],
    );
  }

  /// Step 1 — the photo first (the catalogue is mostly photographs), then
  /// the name and the optional barcode.
  Widget _identityStep(AppLocalizations l10n) {
    return HardwareScanListener(
      onScan: _setBarcode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ItemImageField(
            imagePath: _imagePath,
            onChanged: (value) => setState(() => _imagePath = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: l10n.itemFormName,
            controller: _name,
            hint: l10n.itemFormNameHint,
            prefixIcon: LucideIcons.package,
            autofocus: !_isEditing,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Optional: most restaurant stock arrives loose with nothing to
          // scan. Numeric keyboard, but letters are accepted.
          AppTextField(
            label: l10n.itemBarcodeLabel,
            controller: _barcode,
            hint: l10n.itemBarcodeHint,
            prefixIcon: LucideIcons.barcode,
            helperText: _barcodeConflictName == null
                ? l10n.itemBarcodeHelp
                : null,
            errorText: _barcodeConflictName == null
                ? null
                : l10n.itemBarcodeDuplicate(_barcodeConflictName!),
            keyboardType: TextInputType.number,
            suffixIcon: cameraScanAvailable
                ? IconButton(
                    onPressed: _scanBarcode,
                    tooltip: l10n.itemBarcodeScanTooltip,
                    icon: const Icon(LucideIcons.scanLine),
                  )
                : null,
            onChanged: (_) => setState(() => _barcodeConflictName = null),
          ),
        ],
      ),
    );
  }

  /// Step 2 — where the product is filed and how it is counted.
  Widget _classificationStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveRow(
          breakpoint: 440,
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.xl,
          crossAxisAlignment: CrossAxisAlignment.start,
          stackedCrossAxisAlignment: CrossAxisAlignment.stretch,
          cells: [
            AdaptiveCell.expand(
              AppDropdown<String>(
                label: l10n.itemCategoryLabel,
                value: _categoryId,
                options: [
                  for (final c in widget.categories)
                    DropdownOption(value: c.id, label: c.name),
                ],
                hint: l10n.inventoryFilterAll,
                onChanged: (value) => setState(() => _categoryId = value),
                onCreateNew: _createCategory,
                createNewLabel: l10n.itemFormCreateCategory,
              ),
            ),
            AdaptiveCell.expand(
              AppDropdown<String>(
                label: l10n.itemUnitLabel,
                value: _unitId,
                options: [
                  for (final u in widget.units)
                    DropdownOption(
                      value: u.id,
                      label: u.name,
                      secondaryLabel: u.abbreviation,
                    ),
                ],
                onChanged: (value) => setState(() => _unitId = value),
                onCreateNew: _createUnit,
                createNewLabel: l10n.itemFormCreateUnit,
              ),
            ),
          ],
        ),
        // A preference, not a price — and an edit-only one: a new product
        // has no supplier links yet.
        if (_isEditing) ...[
          const SizedBox(height: AppSpacing.xl),
          AppDropdown<String>(
            label: l10n.itemDefaultSupplierLabel,
            value: _defaultSupplierId,
            options: [
              DropdownOption(
                value: _noSupplier,
                label: l10n.itemDefaultSupplierNone,
              ),
              for (final supplier in widget.suppliers)
                DropdownOption(value: supplier.id, label: supplier.name),
            ],
            hint: l10n.itemDefaultSupplierNone,
            onChanged: (value) => setState(
              () => _defaultSupplierId = value == _noSupplier ? null : value,
            ),
          ),
        ],
      ],
    );
  }

  /// Step 3 — the bounds that decide when the product is flagged and how
  /// much a commande orders, then the note.
  Widget _stockStep(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final gap = context.isPhone ? AppSpacing.lg : AppSpacing.xl;
    final unit = _unitAbbreviation;
    final problems = _rangeProblems;
    // Only complain about a ceiling once one is typed: an untouched zero just
    // keeps Suivant disabled.
    final maxError = _maxStock > 0 && problems.maximumTooLow;

    Widget help(String text, {bool error = false}) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: error ? theme.colorScheme.error : null,
        ),
      ),
    );

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: theme.textTheme.labelMedium),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Read-only: stock changes through an adjustment, which leaves a
        // movement behind. A new product starts at zero.
        if (_isEditing) ...[
          label(l10n.itemOnHandLabel),
          _QuantityFact(
            value: Formatters.quantityWithUnit(_quantity, unit),
            onAdjust: _goAdjust,
          ),
          SizedBox(height: gap),
        ],
        label(l10n.itemThresholdLabel),
        QuantityStepper(
          value: _threshold,
          unitAbbreviation: unit,
          onChanged: (value) => setState(() => _threshold = value),
        ),
        help(l10n.itemFormThresholdHelp),
        SizedBox(height: gap),
        label(l10n.itemMaxStockLabel),
        QuantityStepper(
          value: _maxStock,
          unitAbbreviation: unit,
          onChanged: (value) => setState(() => _maxStock = value),
        ),
        help(
          maxError ? l10n.itemFormMaxStockInvalid : l10n.itemFormMaxStockHelp,
          error: maxError,
        ),
        SizedBox(height: gap),
        label(l10n.itemHolidayMinLabel),
        QuantityStepper(
          value: _holidayMinimum,
          unitAbbreviation: unit,
          onChanged: (value) => setState(() => _holidayMinimum = value),
        ),
        help(
          _holidayTooLow
              ? l10n.itemHolidayMinInvalid
              : l10n.itemHolidayMinHelp(
                  Formatters.quantityWithUnit(_threshold * 2, unit),
                ),
          error: _holidayTooLow,
        ),
        SizedBox(height: gap),
        AppTextField(
          label: l10n.itemNoteLabel,
          controller: _note,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  /// Step 4 — the record as it will be saved.
  Widget _reviewStep(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final unit = _unitAbbreviation;
    String? nameOf<T>(List<T> list, String? id, String Function(T) name,
        String Function(T) idOf) {
      for (final e in list) {
        if (idOf(e) == id) return name(e);
      }
      return null;
    }

    final category = nameOf<Category>(
      widget.categories,
      _categoryId,
      (c) => c.name,
      (c) => c.id,
    );
    final unitName = nameOf<UnitOfMeasure>(
      widget.units,
      _unitId,
      (u) => u.name,
      (u) => u.id,
    );
    final supplier = nameOf<Supplier>(
      widget.suppliers,
      _defaultSupplierId,
      (s) => s.name,
      (s) => s.id,
    );
    final barcode = _barcode.text.trim();
    final note = _note.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.productReviewHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        _ReviewSection(
          title: l10n.productWizardStepIdentity,
          leading: ProductImage(imagePath: _imagePath, size: 56),
          rows: [
            (l10n.itemFormName, _name.text.trim()),
            (l10n.itemBarcodeLabel, barcode.isEmpty ? null : barcode),
          ],
          emptyLabel: l10n.productReviewEmpty,
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewSection(
          title: l10n.productWizardStepClassification,
          rows: [
            (l10n.itemCategoryLabel, category),
            (l10n.itemUnitLabel, unitName == null ? null : '$unitName ($unit)'),
            if (_isEditing)
              (
                l10n.itemDefaultSupplierLabel,
                supplier ?? l10n.itemDefaultSupplierNone,
              ),
          ],
          emptyLabel: l10n.productReviewEmpty,
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewSection(
          title: l10n.productWizardStepStock,
          rows: [
            if (_isEditing)
              (
                l10n.itemOnHandLabel,
                Formatters.quantityWithUnit(_quantity, unit),
              ),
            (
              l10n.itemThresholdLabel,
              Formatters.quantityWithUnit(_threshold, unit),
            ),
            (
              l10n.itemMaxStockLabel,
              Formatters.quantityWithUnit(_maxStock, unit),
            ),
            (
              l10n.itemHolidayMinLabel,
              _holidayMinimum > 0
                  ? Formatters.quantityWithUnit(_holidayMinimum, unit)
                  : l10n.productReviewHolidayAuto(
                      Formatters.quantityWithUnit(_threshold * 2, unit),
                    ),
            ),
            (l10n.itemNoteLabel, note.isEmpty ? null : note),
          ],
          emptyLabel: l10n.productReviewEmpty,
        ),
      ],
    );
  }
}

/// One block of the review: the step's name over its label / value lines.
class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.rows,
    required this.emptyLabel,
    this.leading,
  });

  final String title;

  /// Label, then value — null when the field was left empty.
  final List<(String, String?)> rows;
  final String emptyLabel;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (label, value)) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 3,
                child: Text(
                  value ?? emptyLabel,
                  style: value == null
                      ? theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textDisabled,
                        )
                      : theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (leading == null)
            lines
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading!,
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: lines),
              ],
            ),
        ],
      ),
    );
  }
}

/// The quantity on an edit: stated, with the right way to change it.
class _QuantityFact extends StatelessWidget {
  const _QuantityFact({required this.value, required this.onAdjust});

  final String value;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
