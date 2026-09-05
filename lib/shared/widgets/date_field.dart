import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';

/// A single date shown as a tappable field that opens the platform date picker.
///
/// The caller renders its own label above it (same as every other field in the
/// app) and bounds the selectable range with [firstDate] / [lastDate] — that is
/// how "no day before the hire date" and "never a future day" are enforced.
class DateField extends StatelessWidget {
  const DateField({
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.compact = false,
    super.key,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;

  /// `28/08/2026` instead of `28 août 2026` — for a narrow filter field.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate,
          lastDate: lastDate,
          locale: const Locale('fr', 'BE'),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizing.inputHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.calendar,
              size: AppSizing.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                compact
                    ? Formatters.date(value)
                    : Formatters.dateLong(value),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const Icon(
              LucideIcons.chevronDown,
              size: AppSizing.iconSm,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
