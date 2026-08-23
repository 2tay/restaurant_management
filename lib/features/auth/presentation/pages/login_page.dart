import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';

/// The login screen.
///
/// Authenticates nothing — Phase 1 has no auth, and the submit button simply
/// navigates to the store selector. The demo notice at the bottom says so
/// rather than letting a client believe the login is real.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController(
    text: 'marc.delvaux@brasserie-sablon.be',
  );
  final _passwordController = TextEditingController(text: 'demo1234');
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
          controller: _emailController,
          prefixIcon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.loginPassword,
          controller: _passwordController,
          prefixIcon: LucideIcons.lock,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
              size: AppSizing.iconSm,
            ),
            label: Text(_obscurePassword ? 'Afficher' : 'Masquer'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Stacked rather than side by side. "Rester connecté" and "Mot de passe
        // oublié ?" together are wider than a 440dp form column, and squeezing
        // them onto one line costs the forgot-password link its tap target.
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
            onPressed: () => context.go(Routes.forgotPassword),
            child: Text(l10n.loginForgot),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: l10n.loginSubmit,
          icon: LucideIcons.logIn,
          fullWidth: true,
          large: true,
          onPressed: _submit,
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

  void _submit() => context.go(Routes.stores);
}
