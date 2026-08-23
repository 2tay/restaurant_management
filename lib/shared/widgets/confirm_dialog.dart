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
    this.cancelLabel,
    this.isDestructive = true,
    super.key,
  });

  final String title;
  final String? message;
  final String confirmLabel;

  /// Overrides the default "Annuler". The discard-changes dialog uses
  /// "Continuer la saisie", which says what staying does rather than making
  /// the user infer it.
  final String? cancelLabel;

  /// False for a confirmation that is merely significant rather than
  /// irreversible — leaving a form with unsaved changes, say.
  final bool isDestructive;

  /// Shows the dialog and resolves to whether the user confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? message,
    String? cancelLabel,
    bool isDestructive = true,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
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

  /// The other half of a delete decision: the times it cannot happen.
  ///
  /// A category with articles filed under it, a supplier with an open order —
  /// deleting either would leave records pointing at nothing. Rather than a
  /// disabled button the user has to interrogate, tapping delete explains what
  /// is in the way and what to do about it.
  ///
  /// One action, because there is no choice to make. It is deliberately not a
  /// snackbar: a snackbar is for reporting what happened, and nothing happened.
  static Future<void> blocked(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final l10n = AppLocalizations.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(message),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionUnderstood),
          ),
        ],
      ),
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
        // Dismissive action on the left, confirming action on the right — the
        // same convention as every form and header in the app.
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel ?? l10n.actionCancel),
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
