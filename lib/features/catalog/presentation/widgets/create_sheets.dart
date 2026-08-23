import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// The inline creation sheets behind every category and unit dropdown's
/// "+ Créer" row.
///
/// These exist so the brief's rule — categories and units are created in-app —
/// does not cost the user their place in a form. A cook adding "Persil plat"
/// who needs a "botte" unit creates it here and carries on; they never leave
/// the item form.
///
/// Both return the created name, or null if cancelled. Phase 1 stores nothing;
/// the caller uses the returned value to update its own local selection.
abstract final class CreateSheets {
  /// Returns the new category name.
  static Future<String?> category(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _showSingleFieldSheet(
      context,
      title: l10n.createCategoryTitle,
      label: l10n.createCategoryName,
      hint: l10n.createCategoryHint,
    );
  }

  /// Returns the new unit's full name. The abbreviation is captured too but,
  /// with no persistence in Phase 1, only the name is handed back for display.
  static Future<String?> unit(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _CreateUnitSheet(),
    );
  }

  static Future<String?> _showSingleFieldSheet(
    BuildContext context, {
    required String title,
    required String label,
    required String hint,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _SingleFieldSheet(title: title, label: label, hint: hint),
    );
  }
}

class _SingleFieldSheet extends StatefulWidget {
  const _SingleFieldSheet({
    required this.title,
    required this.label,
    required this.hint,
  });

  final String title;
  final String label;
  final String hint;

  @override
  State<_SingleFieldSheet> createState() => _SingleFieldSheetState();
}

class _SingleFieldSheetState extends State<_SingleFieldSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SheetShell(
      title: widget.title,
      children: [
        AppTextField(
          label: widget.label,
          controller: _controller,
          hint: widget.hint,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SecondaryButton(
              label: l10n.actionCancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: AppSpacing.md),
            PrimaryButton(
              label: l10n.actionSave,
              onPressed: _controller.text.trim().isEmpty ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }
}

class _CreateUnitSheet extends StatefulWidget {
  const _CreateUnitSheet();

  @override
  State<_CreateUnitSheet> createState() => _CreateUnitSheetState();
}

class _CreateUnitSheetState extends State<_CreateUnitSheet> {
  final _name = TextEditingController();
  final _abbreviation = TextEditingController();

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
      title: l10n.createUnitTitle,
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
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              flex: 2,
              child: AppTextField(
                label: l10n.createUnitAbbreviation,
                controller: _abbreviation,
                hint: l10n.createUnitAbbreviationHint,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SecondaryButton(
              label: l10n.actionCancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: AppSpacing.md),
            PrimaryButton(
              label: l10n.actionSave,
              onPressed: _canSubmit
                  ? () => Navigator.of(context).pop(_name.text.trim())
                  : null,
            ),
          ],
        ),
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
