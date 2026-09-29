import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/auth_service.dart';

/// A boxed message on the auth screens: an error, or a plain note.
class AuthNotice extends StatelessWidget {
  const AuthNotice.error(this.message, {super.key}) : isError = true;
  const AuthNotice.info(this.message, {super.key}) : isError = false;

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final foreground = isError
        ? AppColors.outOfStock.foreground
        : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.outOfStock.container
            : AppColors.surfaceVariant,
        borderRadius: AppRadius.mdAll,
        border: isError ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? LucideIcons.circleAlert : LucideIcons.info,
            size: AppSizing.iconMd,
            color: foreground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// An account error, in words.
String accountErrorMessage(AppLocalizations l10n, Object error) {
  final code = error is AccountException
      ? error.code
      : AccountErrorCode.unknown;
  return switch (code) {
    AccountErrorCode.unavailable => l10n.accountErrorUnavailable,
    AccountErrorCode.network => l10n.accountErrorNetwork,
    AccountErrorCode.badCredentials => l10n.accountErrorBadCredentials,
    AccountErrorCode.emailTaken => l10n.accountErrorEmailTaken,
    AccountErrorCode.weakPassword => l10n.accountErrorWeakPassword,
    AccountErrorCode.confirmEmail => l10n.accountErrorConfirmEmail,
    AccountErrorCode.invalidCode => l10n.accountErrorInvalidCode,
    AccountErrorCode.alreadyMember => l10n.accountErrorAlreadyMember,
    AccountErrorCode.notAllowed => l10n.accountErrorNotAllowed,
    AccountErrorCode.unknown => l10n.accountErrorUnknown,
  };
}
