import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A labelled divider between parts of a screen.
///
/// Keeps section titles consistent so a long screen — item detail, settings —
/// reads as a set of blocks rather than a wall.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.count,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Usually an action — "Associer un fournisseur", "Tout afficher".
  final Widget? trailing;

  /// Shown as a pill next to the title. Answers "how many?" before the user
  /// has to count the rows.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: trailing == null
          ? titleBlock
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: AppSpacing.lg),
                // Flexible, not a bare child. A Row lays its non-flexible
                // children out with **unbounded** main-axis room, so the
                // action button used to take its natural width whatever the
                // space — which is how "Associer un fournisseur" ran off the
                // edge of the 434dp detail pane on the inventory split view.
                //
                // Made flexible, it is capped at half the header and the
                // label ellipsizes instead. The Align keeps it against the
                // right edge: without it a short action like "Tout afficher"
                // would float in the middle of its half.
                //
                // Deliberately not a LayoutBuilder, which cannot report
                // intrinsic dimensions — the dashboard measures these headers
                // inside an IntrinsicHeight.
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
                ),
              ],
            ),
    );
  }
}
