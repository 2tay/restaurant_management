import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';

/// Password reset request, with its confirmation state.
///
/// The confirmation is deliberately non-committal — "if an account exists for
/// this address" — rather than confirming the address is registered. Phase 1
/// sends nothing, but the copy should already be right so Phase 2 doesn't
/// inherit a screen that leaks which addresses have accounts.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_sent) {
      return AuthLayout(
        title: l10n.forgotSentTitle,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.inStock.container,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.mailCheck,
                  color: AppColors.inStock.foreground,
                  size: AppSizing.iconLg,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.forgotSentBody(
                      _emailController.text.trim().isEmpty
                          ? '—'
                          : _emailController.text.trim(),
                    ),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.inStock.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SecondaryButton(
            label: l10n.forgotBackToLogin,
            icon: LucideIcons.arrowLeft,
            fullWidth: true,
            onPressed: () => context.goSection(Routes.login),
          ),
        ],
      );
    }

    return AuthLayout(
      title: l10n.forgotTitle,
      subtitle: l10n.forgotBody,
      children: [
        AppTextField(
          label: l10n.loginEmail,
          controller: _emailController,
          prefixIcon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: l10n.forgotSubmit,
          fullWidth: true,
          large: true,
          onPressed: _send,
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: l10n.forgotBackToLogin,
          fullWidth: true,
          onPressed: () => context.goSection(Routes.login),
        ),
      ],
    );
  }

  void _send() => setState(() => _sent = true);
}
