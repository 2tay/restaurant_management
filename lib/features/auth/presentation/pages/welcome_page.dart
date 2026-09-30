import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/device_access.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_notice.dart';

/// The first screen of a fresh install (SYNC_PLAN.md, Phase 4): sign in to
/// the restaurant's account, create one, or try the demo.
///
/// This is the **account** login (e-mail, once per device). The employee
/// login (PIN) comes after it, on `/login`, as before.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasServer = ref.watch(accountBackendProvider).isAvailable;
    final access = ref.watch(deviceAccessProvider);

    return AuthLayout(
      title: l10n.welcomeTitle,
      subtitle: l10n.welcomeSubtitle,
      children: [
        if (!hasServer) ...[
          AuthNotice.info(l10n.accountServerMissing),
          const SizedBox(height: AppSpacing.xl),
        ] else ...[
          AppTextField(
            label: l10n.accountEmail,
            controller: _email,
            prefixIcon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l10n.accountPassword,
            controller: _password,
            prefixIcon: LucideIcons.lock,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              tooltip: _obscure ? l10n.actionShow : l10n.actionHide,
              icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            onChanged: (_) => _clearError(),
            onSubmitted: (_) => _signIn(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.goSection(Routes.accountForgot),
              child: Text(l10n.accountForgotLink),
            ),
          ),
          if (access.mode == DeviceMode.demo) ...[
            const SizedBox(height: AppSpacing.sm),
            AuthNotice.info(l10n.accountDemoWipeWarning),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AuthNotice.error(_error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.accountSignIn,
            icon: LucideIcons.logIn,
            fullWidth: true,
            large: true,
            isBusy: _busy,
            onPressed: _busy ? null : _signIn,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: l10n.accountCreate,
            icon: LucideIcons.userPlus,
            fullWidth: true,
            onPressed: _busy
                ? null
                : () => context.goSection(Routes.accountSignUp),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  l10n.welcomeOr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        SecondaryButton(
          label: l10n.welcomeTryDemo,
          icon: LucideIcons.chefHat,
          fullWidth: true,
          onPressed: _busy ? null : _startDemo,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.welcomeDemoHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(deviceAccessProvider.notifier);
      final summary = await controller.signIn(_email.text, _password.text);
      if (!mounted) return;
      if (!summary.hasOrganization) {
        context.goSection(Routes.accountSetup);
        return;
      }
      // The restaurant's own data on this device is never wiped silently:
      // it is sent to the account, or backed up first (Phase 9).
      if (await controller.localData() == LocalDataKind.own) {
        if (!mounted) return;
        context.goSection(Routes.accountExistingData);
        return;
      }
      await controller.finishWithAccount(summary);
      if (!mounted) return;
      context.goSection(Routes.login);
    } catch (error) {
      if (mounted) setState(() => _error = accountErrorMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startDemo() async {
    setState(() => _busy = true);
    await ref.read(deviceAccessProvider.notifier).startDemo();
    if (!mounted) return;
    setState(() => _busy = false);
    context.goSection(Routes.login);
  }
}
