import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'weekday_date.dart';

/// The top line of a day card on a small screen —
/// `[calendar] Mar 07/10/2026 ……… [status]`.
///
/// Shared by the attendance and the payroll history cards so both read the
/// same way: which day, then what state it is in, with the rest of the card
/// beneath.
class CardDateHeader extends StatelessWidget {
  const CardDateHeader({required this.date, this.status, super.key});

  final DateTime date;

  /// The status badge, pinned to the right edge.
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        const Icon(
          LucideIcons.calendar,
          size: AppSizing.iconSm,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: DefaultTextStyle.merge(
            style: theme.textTheme.labelLarge?.copyWith(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: WeekdayDate(date),
          ),
        ),
        if (status != null) ...[
          const SizedBox(width: AppSpacing.sm),
          status!,
        ],
      ],
    );
  }
}
