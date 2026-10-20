import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/device_access.dart';
import '../../features/auth/presentation/widgets/auth_notice.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync_service.dart';
import 'app_snackbar.dart';
import 'app_text_field.dart';

/// Signs the device's account in again after its session expired, without
/// wiping anything, then resumes sending. Shared by the sync page and the red
/// bar every screen shows meanwhile ([SessionExpiredBanner]).
Future<void> reconnectAccount(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final email = ref.read(deviceAccessProvider).accountEmail ?? '';
  final typed = await showDialog<String>(
    context: context,
    builder: (_) => _ReconnectDialog(email: email),
  );
  if (typed == null || !context.mounted) return;

  try {
    await ref.read(deviceAccessProvider.notifier).reconnect(typed);
    await ref.read(syncControllerProvider.notifier).syncNow();
  } catch (error) {
    if (context.mounted) {
      AppSnackBar.warning(context, accountErrorMessage(l10n, error));
    }
  }
}

/// Asks the account's password again; pops with it, or null when cancelled.
///
/// The dialog owns its field's controller: the field is still on screen
/// during the closing animation, so the controller is freed with the dialog,
/// not when [showDialog] returns.
class _ReconnectDialog extends StatefulWidget {
  const _ReconnectDialog({required this.email});

  final String email;

  @override
  State<_ReconnectDialog> createState() => _ReconnectDialogState();
}

class _ReconnectDialogState extends State<_ReconnectDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.syncReconnectTitle),
      content: AppTextField(
        label: l10n.syncReconnectBody(widget.email),
        controller: _password,
        obscureText: true,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_password.text),
          child: Text(l10n.syncReconnect),
        ),
      ],
    );
  }
}
