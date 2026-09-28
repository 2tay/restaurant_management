import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';

/// The supplier's initials on a soft tile — the anchor the eye lands on when
/// scanning a list of commandes or réceptions.
///
/// Neutral on purpose: the status pill beside it carries the colour, and a
/// second tint per row would turn the list into confetti.
class SupplierMonogram extends StatelessWidget {
  const SupplierMonogram({required this.name, this.size = 44, super.key});

  final String name;
  final double size;

  /// "Boucherie Martin" → "BM", "Métro" → "MÉ".
  static String initialsOf(String name) {
    final words = name
        .split(RegExp(r'[\s\-_/&]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length < 2 ? word.length : 2).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.55),
          borderRadius: AppRadius.mdAll,
        ),
        child: Text(
          initialsOf(name),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.34,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// How much of an order has arrived: a slim bar and the percentage beside it.
///
/// Teal while goods are still owed, green once everything is in.
class ReceivedProgress extends StatelessWidget {
  const ReceivedProgress({required this.share, this.label, super.key});

  /// Between 0 and 1.
  final double share;

  /// Written before the percentage — "Reçu" — where no column header says it.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = share >= 1;
    final color = done ? AppColors.inStock.solid : AppColors.primary600;
    final percent = Formatters.percent(share);

    return Semantics(
      label: label == null ? percent : '$label $percent',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 40),
                child: ClipRRect(
                  borderRadius: AppRadius.pillAll,
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6,
                    color: color,
                    backgroundColor: AppColors.neutral100,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label == null ? percent : '$label $percent',
              style: theme.textTheme.labelSmall?.copyWith(
                color: done
                    ? AppColors.inStock.foreground
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small icon and a piece of metadata — a reference, a date, a line count.
///
/// Several of these in a [Wrap] replace a "·"-joined string: they wrap
/// cleanly on a phone instead of cutting a reference in half.
class MetaItem extends StatelessWidget {
  const MetaItem({
    required this.icon,
    required this.label,
    this.color,
    this.emphasis = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 14, color: fg)),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: fg,
              fontWeight: emphasis ? FontWeight.w600 : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
