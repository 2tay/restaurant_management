import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/credential_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';

/// The login screen — email + PIN (the CIN), checked against the employees
/// (`CredentialRepository.authenticate`). The PIN is the secret, so it is
/// typed hidden.
///
/// Resolves the session into `currentEmployeeProvider`, and refuses a `staff`
/// account, which has no active access to the app, and a retired one.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _pin = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePin = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthLayout(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      children: [
        AppTextField(
          label: l10n.loginEmail,
          controller: _email,
          hint: l10n.loginEmailHint,
          prefixIcon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.loginPin,
          controller: _pin,
          hint: l10n.loginPinHint,
          prefixIcon: LucideIcons.idCard,
          obscureText: _obscurePin,
          textInputAction: TextInputAction.done,
          onChanged: (_) => _clearError(),
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _obscurePin = !_obscurePin),
            icon: Icon(
              _obscurePin ? LucideIcons.eye : LucideIcons.eyeOff,
              size: AppSizing.iconSm,
            ),
            label: Text(_obscurePin ? l10n.actionShow : l10n.actionHide),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Switch(
              value: _rememberMe,
              onChanged: (value) => setState(() => _rememberMe = value),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.loginRemember,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorNotice(message: _error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: l10n.loginSubmit,
          icon: LucideIcons.logIn,
          fullWidth: true,
          large: true,
          onPressed: () => _signIn(),
        ),
      ],
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    final attempt = await ref
        .read(credentialRepositoryProvider)
        .authenticate(_email.text, _pin.text);
    if (!mounted) return;

    switch (attempt.outcome) {
      case LoginOutcome.success:
        final employee = attempt.employee!;
        await ref.read(currentEmployeeProvider.notifier).signIn(employee.id);
        if (!mounted) return;
        // The owner picks a store from the grid; a manager goes straight to
        // the store they belong to.
        context.goSection(
          can(employee.role, Capability.spanAllStores)
              ? Routes.stores
              : Routes.toDashboard(employee.storeId),
        );
      case LoginOutcome.unknownEmail:
      case LoginOutcome.wrongPin:
        setState(() => _error = l10n.loginErrorBadCredentials);
      case LoginOutcome.noAppAccess:
        setState(() => _error = l10n.loginErrorNoAccess);
      case LoginOutcome.archived:
        setState(() => _error = l10n.loginErrorArchived);
    }
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.outOfStock.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.circleAlert,
            size: AppSizing.iconMd,
            color: AppColors.outOfStock.foreground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.outOfStock.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
