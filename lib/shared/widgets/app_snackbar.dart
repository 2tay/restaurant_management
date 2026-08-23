import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// Confirmation that something happened.
///
/// The brief's requirement is that a rushed user never wonders "did that
/// save?". Every action that changes something calls one of these, and they all
/// look identical so the confirmation becomes something the user recognises
/// rather than reads.
///
/// Four seconds rather than the Material default of two: the user may well be
/// looking at a pan, not the tablet, when the action lands.
abstract final class AppSnackBar {
  static const Duration _duration = Duration(seconds: 4);

  /// Something worked. "Livraison enregistrée", "Article supprimé".
  static void success(
    BuildContext context,
    String message, {
    VoidCallback? onUndo,
  }) {
    _show(
      context,
      message: message,
      icon: LucideIcons.circleCheck,
      iconColor: AppColors.inStock.solid,
      onUndo: onUndo,
    );
  }

  /// Something needs attention but nothing broke.
  static void warning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: LucideIcons.triangleAlert,
      iconColor: AppColors.warning,
    );
  }

  /// Something failed.
  static void error(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: LucideIcons.circleX,
      iconColor: AppColors.outOfStock.solid,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onUndo,
  }) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: _duration,
        // Constrained so a snackbar does not stretch the full width of a 1280dp
        // tablet, which puts the text miles from where the user was looking.
        width: 560,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(icon, size: AppSizing.iconMd, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
        action: onUndo == null
            ? null
            : SnackBarAction(label: l10n.actionUndo, onPressed: onUndo),
      ),
    );
  }
}
