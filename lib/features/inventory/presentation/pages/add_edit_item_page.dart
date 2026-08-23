import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
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
class AddEditItemPage extends StatefulWidget {
  const AddEditItemPage({required this.storeId, this.itemId, super.key});

  final String storeId;

  /// Null when creating.
  final String? itemId;

  @override
  State<AddEditItemPage> createState() => _AddEditItemPageState();
}

class _AddEditItemPageState extends State<AddEditItemPage> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  String? _categoryId;
  String? _unitId;
  double _quantity = 0;
  double _threshold = 0;

  /// Categories and units created inline during this session. Phase 1 persists
  /// nothing, so they live here for as long as the form is open — enough to
  /// demo the flow end to end.
  final List<String> _newCategories = [];
  final List<String> _newUnits = [];

  // Snapshot taken in initState. The dirty check compares against these rather
  // than tracking a flag, so undoing an edit back to its original value
  // correctly stops counting as unsaved.
  String _initialName = '';
  String _initialNote = '';
  String? _initialCategoryId;
  String? _initialUnitId;
  double _initialQuantity = 0;
  double _initialThreshold = 0;

  bool get _isEditing => widget.itemId != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.itemId == null
        ? null
        : MockQueries.itemById(widget.itemId!);

    if (existing != null) {
      _nameController.text = existing.name;
      _noteController.text = existing.note ?? '';
      _categoryId = existing.categoryId;
      _unitId = existing.unitId;
      _quantity = existing.quantity;
      _threshold = existing.lowStockThreshold;
    }

    _initialName = _nameController.text.trim();
    _initialNote = _noteController.text.trim();
    _initialCategoryId = _categoryId;
    _initialUnitId = _unitId;
    _initialQuantity = _quantity;
    _initialThreshold = _threshold;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
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
      _categoryId != _initialCategoryId ||
      _unitId != _initialUnitId ||
      _quantity != _initialQuantity ||
      _threshold != _initialThreshold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final categories = [
      for (final c in MockQueries.categoriesForStore(widget.storeId))
        DropdownOption(value: c.id, label: c.name),
      for (final name in _newCategories)
        DropdownOption(value: 'new:$name', label: name),
    ];

    final units = [
      for (final u in MockQueries.unitsForStore(widget.storeId))
        DropdownOption(
          value: u.id,
          label: u.name,
          secondaryLabel: u.abbreviation,
        ),
      for (final name in _newUnits)
        DropdownOption(value: 'new:$name', label: name),
    ];

    final unitAbbreviation = _unitId == null
        ? ''
        : MockQueries.unitAbbreviationOf(_unitId!);

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
                      ? l10n.itemQuantityLabel
                      : l10n.itemFormStartingQuantity,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                QuantityStepper(
                  value: _quantity,
                  unitAbbreviation: unitAbbreviation,
                  onChanged: (value) => setState(() => _quantity = value),
                ),
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

  Future<void> _createCategory() async {
    final name = await CreateSheets.category(context);
    if (name == null || !mounted) return;

    setState(() {
      _newCategories.add(name);
      _categoryId = 'new:$name';
    });
    AppSnackBar.success(context, AppLocalizations.of(context).categoryCreated);
  }

  Future<void> _createUnit() async {
    final name = await CreateSheets.unit(context);
    if (name == null || !mounted) return;

    setState(() {
      _newUnits.add(name);
      _unitId = 'new:$name';
    });
    AppSnackBar.success(context, AppLocalizations.of(context).unitCreated);
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    AppSnackBar.success(
      context,
      _isEditing ? l10n.itemUpdated : l10n.itemCreated,
    );
    _leave();
  }

  void _leave() {
    if (_isEditing) {
      context.pushScreen(Routes.toItem(widget.storeId, widget.itemId!));
    } else {
      context.goSection(Routes.toInventory(widget.storeId));
    }
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
