import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../l10n/app_localizations.dart';

/// Shared chrome for the screens outside the shell.
///
/// A two-pane split on a tablet: brand panel on the left, form on the right.
/// Below the split breakpoint the brand panel drops away entirely rather than
/// shrinking — a 200px-wide decorative panel is worse than none.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBrandPanel = context.canSplitView;

    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!showBrandPanel) ...[
                const _BrandMark(compact: true),
                const SizedBox(height: AppSpacing.xl),
              ],
              Text(title, style: theme.textTheme.headlineLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              ...children,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: showBrandPanel
            ? Row(
                children: [
                  const Expanded(flex: 2, child: _BrandPanel()),
                  Expanded(flex: 3, child: form),
                ],
              )
            : form,
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      color: AppColors.steel800,
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BrandMark(),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            l10n.onboardingBody,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.neutral200,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          _BrandPoint(
            icon: LucideIcons.boxes,
            label: l10n.onboardingFeatureStock,
          ),
          const SizedBox(height: AppSpacing.lg),
          _BrandPoint(
            icon: LucideIcons.scale,
            label: l10n.onboardingFeaturePrices,
          ),
          const SizedBox(height: AppSpacing.lg),
          _BrandPoint(
            icon: LucideIcons.triangleAlert,
            label: l10n.onboardingFeatureAlerts,
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = compact ? AppColors.textPrimary : AppColors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.primary600,
            borderRadius: AppRadius.mdAll,
          ),
          child: const Icon(
            LucideIcons.chefHat,
            color: AppColors.white,
            size: AppSizing.iconLg,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            l10n.appTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _BrandPoint extends StatelessWidget {
  const _BrandPoint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary500, size: AppSizing.iconMd),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.neutral100),
          ),
        ),
      ],
    );
  }
}
