import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/device_access.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_notice.dart';

/// Creating a restaurant account (SYNC_PLAN.md, Phase 4). The owner, or a
/// manager who will join with a code on the next screen.
class AccountSignUpPage extends ConsumerStatefulWidget {
  const AccountSignUpPage({super.key});

  /// Supabase's default minimum.
  static const int minPasswordLength = 8;

  @override
  ConsumerState<AccountSignUpPage> createState() => _AccountSignUpPageState();
}

class _AccountSignUpPageState extends ConsumerState<AccountSignUpPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthLayout(
      title: l10n.signUpTitle,
      subtitle: l10n.signUpSubtitle,
      children: [
        AppTextField(
          label: l10n.accountEmail,
          controller: _email,
          prefixIcon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.accountPassword,
          helperText: l10n.accountPasswordHint,
          controller: _password,
          prefixIcon: LucideIcons.lock,
          obscureText: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.signUpPasswordConfirm,
          controller: _confirm,
          prefixIcon: LucideIcons.lock,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AuthNotice.error(_error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: l10n.signUpSubmit,
          icon: LucideIcons.userPlus,
          fullWidth: true,
          large: true,
          isBusy: _busy,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => context.goSection(Routes.welcome),
          child: Text(l10n.signUpHaveAccount),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final String? problem;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      problem = l10n.setupFieldsRequired;
    } else if (_password.text.length < AccountSignUpPage.minPasswordLength) {
      problem = l10n.signUpPasswordTooShort;
    } else if (_password.text != _confirm.text) {
      problem = l10n.signUpPasswordMismatch;
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
          .read(deviceAccessProvider.notifier)
          .signUp(_email.text, _password.text);
      if (!mounted) return;
      AppSnackBar.success(context, l10n.signUpDone);
      context.goSection(Routes.accountSetup);
    } catch (error) {
      if (mounted) setState(() => _error = accountErrorMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
