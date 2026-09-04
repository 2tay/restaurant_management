import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'primary_button.dart';

/// Shown when something could not be displayed.
///
/// Always offers a way forward. An error screen that is only an apology leaves
/// a user mid-service with nothing to do but restart the app.
///
/// Phase 1 could not actually fail — there was no network and no database — so
/// this was designed before it could be reached. It is reachable now: a query
/// that throws lands here, and so does an establishment that cannot be
/// resolved.
class ErrorState extends StatelessWidget {
  const ErrorState({this.title, this.message, this.onRetry, super.key});

  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.circleAlert,
                  size: 32,
                  color: AppColors.onErrorContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title ?? l10n.errorStateTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message ?? l10n.errorStateBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: l10n.actionRetry,
                  icon: LucideIcons.refreshCw,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
