import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A small icon and one line of text — a phone number, an email, an
/// address — for the contact block of a card.
///
/// With [value], the text is a grey caption and the value follows it in
/// [valueColor] — the brand green by default: "Embauché le  12 janv. 2024".
class InfoLine extends StatelessWidget {
  const InfoLine({
    required this.icon,
    required this.text,
    this.value,
    this.valueColor = AppColors.primary600,
    super.key,
  });

  final IconData icon;
  final String text;
  final String? value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: AppSizing.iconSm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: text,
              style: value == null
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              children: [
                if (value != null)
                  TextSpan(
                    text: '  $value',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A tinted block that puts one figure forward — an icon, the value, and a
/// caption under it ("15,00 € /h · Salaire horaire") on a wash of [color]:
/// the brand green by default, red for a record no longer active.
class HighlightTile extends StatelessWidget {
  const HighlightTile({
    required this.icon,
    required this.value,
    required this.caption,
    this.color = AppColors.primary600,
    super.key,
  });

  final IconData icon;
  final String value;
  final String caption;

  /// The icon, the value, and (translucent) the background.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSizing.iconLg, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  caption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
