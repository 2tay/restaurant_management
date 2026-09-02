import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// A panel that slides in from the right for a row's detail — the attendance
/// and payment history both open one instead of navigating away or throwing a
/// full-screen modal.
///
/// ~440px on a desktop, near full-width below 600. Dismissed by the close
/// button, the scrim, or Échap.
class DetailDrawer extends StatelessWidget {
  const DetailDrawer({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) =>
          DetailDrawer(title: title, children: children),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < 600 ? screenWidth : 440.0;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        elevation: 16,
        color: AppColors.surface,
        child: SizedBox(
          width: panelWidth,
          height: double.infinity,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title, style: theme.textTheme.titleMedium),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.x),
                        tooltip: l10n.actionClose,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A `label — value` line for the drawer body. `value` may be a string or,
/// via [valueWidget], any widget (a badge, an amount).
class DrawerRow extends StatelessWidget {
  const DrawerRow({required this.label, this.value, this.valueWidget, super.key});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                valueWidget ??
                Text(value ?? '—', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
