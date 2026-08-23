import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/widgets.dart';

/// One figure in an [OrderSummaryCard].
@immutable
class OrderFigure {
  const OrderFigure({
    required this.label,
    required this.value,
    this.accent,
    this.emphasis = false,
  });

  final String label;
  final String value;

  /// Tints the figure. Used for the discrepancy count, which should read as
  /// something to look at rather than as a neutral statistic — but only when it
  /// is not zero.
  final StockStatusColors? accent;

  /// The headline figure of the card. At most one.
  final bool emphasis;
}

/// A row of figures above a decision.
///
/// Used before confirming a receipt and in the order detail header. Both are
/// moments where the user is about to commit to something with a price on it,
/// and both deserve the totals stated rather than left to be added up from a
/// table.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    required this.figures,
    this.title,
    this.footnote,
    super.key,
  });

  final String? title;
  final List<OrderFigure> figures;

  /// A line under the figures — the read-only notice on a receipt, the
  /// shortfall recorded on a closed order.
  final Widget? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Wraps rather than scrolls: four French labels do not fit one row on
          // a narrow pane, and a figure that has scrolled off the edge is a
          // figure nobody checks.
          Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.lg,
            children: [
              for (final figure in figures) _Figure(figure: figure),
            ],
          ),
          if (footnote != null) ...[
            const Divider(height: AppSpacing.xl),
            footnote!,
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.figure});

  final OrderFigure figure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = figure.accent?.foreground ?? AppColors.textPrimary;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            figure.label,
            style: theme.textTheme.labelMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            figure.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (figure.emphasis
                        ? AppTypography.numericHero
                        : AppTypography.numericMedium)
                    .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
