import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../data/device_access.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/auth_service.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/widgets/auth_notice.dart';

/// Changes the restaurant account's password, from Paramètres → Compte.
///
/// Only the owner on a device of the account is offered it. The PIN is not
/// changed here: it is the employee's CIN, and the owner corrects it in
/// Personnel.
Future<void> changeAccountPassword(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
  if (changed == true && context.mounted) {
    AppSnackBar.success(context, l10n.accountPasswordChanged);
  }
}

/// Asks the current password and the new one twice, and changes it on the
/// server; pops with true once changed. An error stays in the dialog so
/// nothing typed is lost.
///
/// The dialog owns its fields' controllers: the fields are still on screen
/// during the closing animation, so the controllers are freed with the
/// dialog, not when [showDialog] returns.
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_current, _new, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = ref.watch(deviceAccessProvider).accountEmail ?? '';

    return AlertDialog(
      title: Text(l10n.accountChangePassword),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.accountPasswordChangeNote(email)),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const ValueKey('password-current'),
                label: l10n.accountCurrentPassword,
                controller: _current,
                obscureText: true,
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const ValueKey('password-new'),
                label: l10n.accountNewPassword,
                helperText: l10n.accountPasswordHint,
                controller: _new,
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const ValueKey('password-confirm'),
                label: l10n.accountConfirmPassword,
                controller: _confirm,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                AuthNotice.error(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final current = _current.text;
    final next = _new.text;

    // What can be said without the server.
    final String? problem;
    if (current.isEmpty) {
      problem = l10n.accountCurrentPasswordWrong;
    } else if (next.length < 8) {
      problem = l10n.accountErrorWeakPassword;
    } else if (next != _confirm.text) {
      problem = l10n.accountPasswordMismatch;
    } else if (next == current) {
      problem = l10n.accountErrorSamePassword;
    } else {
      problem = null;
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountBackendProvider)
          .changePassword(currentPassword: current, newPassword: next);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            error is AccountException &&
                error.code == AccountErrorCode.badCredentials
            ? l10n.accountCurrentPasswordWrong
            : accountErrorMessage(l10n, error);
      });
    }
  }
}
