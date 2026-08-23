import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// Confirmation before something the user cannot undo.
///
/// The brief requires this for deleting an item, removing a supplier link, and
/// large downward adjustments. Two deliberate choices:
///
/// - **Cancel is the safe default**, positioned left and styled quietly. The
///   destructive action is the one that has to be aimed at.
/// - **The message names the thing.** "Supprimer cet élément ?" is how people
///   delete the wrong record; "Supprimer « Blanc de poulet » ?" is not.
///
/// Returns true only if the user confirmed. Dismissing by tapping outside
/// returns null, which callers should treat as a no.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.confirmLabel,
    this.message,
    this.isDestructive = true,
    super.key,
  });

  final String title;
  final String? message;
  final String confirmLabel;

  /// False for a confirmation that is merely significant rather than
  /// irreversible — leaving a form with unsaved changes, say.
  final bool isDestructive;

  /// Shows the dialog and resolves to whether the user confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? message,
    bool isDestructive = true,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
      ),
    );
    return confirmed ?? false;
  }

  /// The common case: deleting a named record.
  ///
  /// Wraps the name in French quotation marks and appends the irreversibility
  /// warning, so every delete in the app reads the same way.
  static Future<bool> confirmDelete(
    BuildContext context, {
    required String name,
    String? extraWarning,
  }) {
    final l10n = AppLocalizations.of(context);
    final message = extraWarning == null
        ? l10n.confirmDeleteIrreversible
        : '$extraWarning\n\n${l10n.confirmDeleteIrreversible}';

    return show(
      context,
      title: l10n.confirmDeleteTitle('« $name »'),
      message: message,
      confirmLabel: l10n.actionDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(title),
      content: message == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(message!),
            ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
