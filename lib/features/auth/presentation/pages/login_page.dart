import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/credential_status.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/credential_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';

/// The login screen — CIN + PIN, checked against the `employee_credentials`
/// table (Phase 6).
///
/// Still fake, deliberately: no backend, no real hashing, no network. What it
/// does do is resolve the session into `currentEmployeeProvider`, enforce the
/// lockout after [AuthRules.maxFailedAttempts] wrong PINs, and refuse a `staff`
/// account, which has no active access to the app. The demo notice at the
/// bottom keeps saying the authentication is not real.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  /// The seeded owner's CIN, pre-filled as a demo courtesy — the same one the
  /// Phase 1 form paid with an email and password. `1234` is every seeded PIN.
  static const _demoCin = '78.02.14-153.24';

  final _cin = TextEditingController(text: _demoCin);
  final _pin = TextEditingController(text: '1234');
  bool _rememberMe = true;
  bool _obscurePin = true;
  String? _error;

  @override
  void dispose() {
    _cin.dispose();
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
          label: l10n.loginCin,
          controller: _cin,
          hint: l10n.loginCinHint,
          prefixIcon: LucideIcons.idCard,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.loginPin,
          controller: _pin,
          hint: l10n.loginPinHint,
          prefixIcon: LucideIcons.lock,
          obscureText: _obscurePin,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(AuthRules.pinLength),
          ],
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.goSection(Routes.forgotPassword),
            child: Text(l10n.loginForgotPin),
          ),
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
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.info,
                size: AppSizing.iconMd,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.loginDemoNotice,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
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
        .authenticate(_cin.text, _pin.text);
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
      case LoginOutcome.unknownCin:
      case LoginOutcome.wrongPin:
        setState(() => _error = l10n.loginErrorBadCredentials);
      case LoginOutcome.locked:
        setState(() => _error = l10n.loginErrorLocked);
      case LoginOutcome.noAppAccess:
        setState(() => _error = l10n.loginErrorNoAccess);
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
