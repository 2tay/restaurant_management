import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_notice.dart';

/// A reset link for the account password (SYNC_PLAN.md, Phase 4). Not the
/// employee's four-digit code: that one is reset by an owner, as before.
class AccountForgotPage extends ConsumerStatefulWidget {
  const AccountForgotPage({super.key});

  @override
  ConsumerState<AccountForgotPage> createState() => _AccountForgotPageState();
}

class _AccountForgotPageState extends ConsumerState<AccountForgotPage> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthLayout(
      title: l10n.forgotAccountTitle,
      subtitle: l10n.forgotAccountSubtitle,
      children: [
        AppTextField(
          label: l10n.accountEmail,
          controller: _email,
          prefixIcon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _send(),
        ),
        if (_sent) ...[
          const SizedBox(height: AppSpacing.md),
          AuthNotice.info(l10n.forgotAccountSent),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AuthNotice.error(_error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: l10n.forgotAccountSubmit,
          icon: LucideIcons.send,
          fullWidth: true,
          large: true,
          isBusy: _busy,
          onPressed: _busy ? null : _send,
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => context.goSection(Routes.welcome),
          child: Text(l10n.forgotAccountBack),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (_email.text.trim().isEmpty) {
      setState(() => _error = l10n.setupFieldsRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountBackendProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = accountErrorMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
