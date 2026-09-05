import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'adaptive_row.dart';

/// A tinted strip that tells the user something about the screen they are on.
///
/// The dashboard's stale-orders warning and the employee detail's archived
/// notice were each their own `Container` + `Row` + icon + text + optional
/// button, and both overflowed on a phone in the same way: the action button
/// sat in a `Row` with unbounded main-axis room and took its natural width
/// whatever was left.
///
/// This is not [OfflineBanner], which is deliberately a different thing — a
/// full-bleed slim bar pinned above the whole content area, describing the app
/// rather than the page.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.colors,
    super.key,
  });

  final IconData icon;

  /// The one line the user must read.
  final String title;

  /// The detail under it. Omitted for a notice that is only a status.
  final String? message;

  /// What to do about it. Sits at the end of the strip, or on its own line
  /// when there is not enough width for both.
  final Widget? action;

  /// Tint. Defaults to the neutral surface — a notice is not automatically a
  /// warning, and colouring one amber that isn't spends the signal.
  final StockStatusColors? colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = colors?.container ?? AppColors.surfaceVariant;
    final foreground = colors?.foreground ?? AppColors.textSecondary;

    final text = Row(
      children: [
        Icon(icon, size: AppSizing.iconLg, color: foreground),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(color: foreground),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.mdAll,
      ),
      child: action == null
          ? text
          : AdaptiveRow(
              // The icon and its text stay together on every layout; only the
              // action drops to its own line.
              cells: [
                AdaptiveCell(flex: 1, child: text),
                AdaptiveCell(child: action!),
              ],
            ),
    );
  }
}
