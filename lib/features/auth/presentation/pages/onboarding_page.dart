import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// A single introductory screen.
///
/// Kept to one screen on purpose. The brief marks onboarding optional, and a
/// multi-step carousel is something restaurant staff will skip — the app has to
/// be self-explanatory anyway.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.primary600,
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: const Icon(
                        LucideIcons.chefHat,
                        color: AppColors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.onboardingTitle,
                    style: theme.textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.onboardingBody,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Feature(
                    icon: LucideIcons.boxes,
                    title: l10n.onboardingFeatureStock,
                    body: l10n.onboardingFeatureStockBody,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Feature(
                    icon: LucideIcons.scale,
                    title: l10n.onboardingFeaturePrices,
                    body: l10n.onboardingFeaturePricesBody,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Feature(
                    icon: LucideIcons.triangleAlert,
                    title: l10n.onboardingFeatureAlerts,
                    body: l10n.onboardingFeatureAlertsBody,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: PrimaryButton(
                      label: l10n.onboardingStart,
                      icon: LucideIcons.arrowRight,
                      large: true,
                      onPressed: () => context.go(Routes.stores),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.onPrimaryContainer,
              size: AppSizing.iconMd,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
