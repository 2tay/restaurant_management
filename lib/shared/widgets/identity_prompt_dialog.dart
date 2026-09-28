import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'app_text_field.dart';

/// Confirms who is at a shared screen before an action goes through, by asking
/// for that person's **PIN** — the unique national-ID number that is also the
/// login identifier. Used by every button on the pointage kiosk (the card's
/// employee) and by "Payer" on the payroll page (the signed-in user).
///
/// The dialog owns the retry loop: it stays open through wrong entries — as
/// many as it takes, there is no lockout — and only resolves `true` once the
/// PIN is right (or `false` if the user backs out).
///
/// [verify] is the check itself, normally
/// `ref.read(credentialRepositoryProvider).verifyPin(pin, expectedEmployeeId)`.
class IdentityPromptDialog extends StatefulWidget {
  const IdentityPromptDialog({
    required this.title,
    required this.subtitle,
    required this.verify,
    super.key,
  });

  final String title;
  final String subtitle;
  final Future<bool> Function(String pin) verify;

  /// Shows the dialog and resolves to whether the PIN was accepted. A dismissal
  /// (Annuler, or Échap) resolves `false`.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Future<bool> Function(String pin) verify,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IdentityPromptDialog(
        title: title,
        subtitle: subtitle,
        verify: verify,
      ),
    );
    return ok ?? false;
  }

  @override
  State<IdentityPromptDialog> createState() => _IdentityPromptDialogState();
}

class _IdentityPromptDialogState extends State<IdentityPromptDialog> {
  final _controller = TextEditingController();
  String? _message;
  bool _busy = false;

  bool get _canSubmit => !_busy && _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _busy = true);
    final ok = await widget.verify(_controller.text.trim());
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _controller.clear();
      _message = AppLocalizations.of(context).identityPromptWrong;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l10n.identityPromptField,
              controller: _controller,
              hint: l10n.loginPinHint,
              enabled: !_busy,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(l10n.identityPromptValidate),
        ),
      ],
    );
  }
}
