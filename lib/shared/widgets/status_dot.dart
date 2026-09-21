import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A status in a table cell: a small dot in the status colour, then the word
/// in ordinary text.
///
/// The quiet form of a status pill. A column of filled, tinted pills turns a
/// table into a patchwork; a column of dots keeps the colour as the signal
/// and lets the text stay text. [compact] keeps the dot alone, with the word
/// in a tooltip, for a narrow column.
class StatusDot extends StatelessWidget {
  const StatusDot({
    required this.color,
    required this.label,
    this.compact = false,
    super.key,
  });

  final Color color;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (compact) return Tooltip(message: label, child: dot);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
