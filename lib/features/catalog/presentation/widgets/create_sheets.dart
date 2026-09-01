import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// The sheets behind every "+ Créer" row and every catalogue edit button.
///
/// These exist so the brief's rule — categories and units are created in-app —
/// does not cost the user their place in a form. A cook adding "Persil plat"
/// who needs a "botte" unit creates it here and carries on; they never leave
/// the item form.
///
/// Each returns the **record it created or changed**, or null if cancelled.
/// Returning the record rather than a name is what lets the item form select
/// what the user just made — which is the entire point of the inline row.
///
/// Uniqueness is validated inside the sheet, under the field, while it is still
/// open. Reporting a clash after the sheet has closed would leave the user
/// looking at a snackbar with nothing to correct.
abstract final class CreateSheets {
  /// Creates a category, or renames [existing] when one is given.
  static Future<Category?> category(
    BuildContext context, {
    required String storeId,
    Category? existing,
  }) {
    return showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _CategorySheet(storeId: storeId, existing: existing),
    );
  }

  /// Creates a unit, or edits [existing] when one is given.
  static Future<UnitOfMeasure?> unit(
    BuildContext context, {
    required String storeId,
    UnitOfMeasure? existing,
  }) {
    return showModalBottomSheet<UnitOfMeasure>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _UnitSheet(storeId: storeId, existing: existing),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.storeId, this.existing});

  final String storeId;
  final Category? existing;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );

  /// Set when the entered name is already taken. Cleared on the next keystroke
  /// so a corrected field stops complaining immediately.
  bool _taken = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SheetShell(
      title: _isEditing ? l10n.editCategoryTitle : l10n.createCategoryTitle,
      children: [
        AppTextField(
          label: l10n.createCategoryName,
          controller: _name,
          hint: l10n.createCategoryHint,
          errorText: _taken ? l10n.categoryNameTaken : null,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _taken = false),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xl),
        _SheetActions(
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    final catalog = ref.read(catalogRepositoryProvider);
    final result = _isEditing
        ? await catalog.renameCategory(widget.existing!.id, name)
        : await catalog.createCategory(storeId: widget.storeId, name: name);

    if (!mounted) return;

    // Null means the name collides — the only way these can fail once the
    // field is non-empty.
    if (result == null) {
      setState(() => _taken = true);
      return;
    }
    Navigator.of(context).pop(result);
  }
}

class _UnitSheet extends ConsumerStatefulWidget {
  const _UnitSheet({required this.storeId, this.existing});

  final String storeId;
  final UnitOfMeasure? existing;

  @override
  ConsumerState<_UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends ConsumerState<_UnitSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _abbreviation = TextEditingController(
    text: widget.existing?.abbreviation ?? '',
  );

  bool _nameTaken = false;
  bool _abbreviationTaken = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _abbreviation.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _name.text.trim().isNotEmpty && _abbreviation.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SheetShell(
      title: _isEditing ? l10n.editUnitTitle : l10n.createUnitTitle,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppTextField(
                label: l10n.createUnitName,
                controller: _name,
                hint: l10n.createUnitNameHint,
                errorText: _nameTaken ? l10n.unitNameTaken : null,
                autofocus: true,
                onChanged: (_) => setState(() => _nameTaken = false),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              flex: 2,
              child: AppTextField(
                label: l10n.createUnitAbbreviation,
                controller: _abbreviation,
                hint: l10n.createUnitAbbreviationHint,
                errorText: _abbreviationTaken
                    ? l10n.unitAbbreviationTaken
                    : null,
                onChanged: (_) =>
                    setState(() => _abbreviationTaken = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _SheetActions(
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: _canSubmit ? _submit : null,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final abbreviation = _abbreviation.text.trim();

    final catalog = ref.read(catalogRepositoryProvider);
    final result = _isEditing
        ? await catalog.updateUnit(
            widget.existing!.id,
            name: name,
            abbreviation: abbreviation,
          )
        : await catalog.createUnit(
            storeId: widget.storeId,
            name: name,
            abbreviation: abbreviation,
          );

    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
      return;
    }

    // The write reports failure as a single null, so the sheet works out which
    // of the two fields to flag. Asking the read side directly keeps the
    // write's contract simple and puts the error under the right field.
    final clashingName = await catalog.unitNamed(
      widget.storeId,
      name,
      excludingId: widget.existing?.id,
    );
    final clashingAbbreviation = await catalog.unitAbbreviated(
      widget.storeId,
      abbreviation,
      excludingId: widget.existing?.id,
    );

    if (!mounted) return;
    setState(() {
      _nameTaken = clashingName != null;
      _abbreviationTaken = clashingAbbreviation != null;
    });
  }
}

/// Cancel left, save right — the same convention as every form in the app.
class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.onCancel, required this.onSubmit});

  final VoidCallback onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SecondaryButton(label: l10n.actionCancel, onPressed: onCancel),
        const SizedBox(width: AppSpacing.md),
        PrimaryButton(label: l10n.actionSave, onPressed: onSubmit),
      ],
    );
  }
}

/// Shared sheet chrome: title, padding, and room for the keyboard.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // viewInsets so the sheet lifts above the on-screen keyboard rather than
      // hiding the field being typed into.
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.md,
        bottom: AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}
