import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// One tab of a [CountTabs] row: what it selects, what it says, and how many
/// rows it would show. A null [count] is still loading, and shows a dash — a
/// zero would be a claim made before anything was read.
class CountTab<T> {
  const CountTab({required this.value, required this.label, this.count});

  final T value;
  final String label;
  final int? count;
}

/// A row of pill tabs, each with the number of rows it would show — the
/// status switch above the commandes and the alerts.
///
/// Scrolls sideways rather than wrapping, so a phone keeps them on one line
/// and the list below starts at the same height whatever is selected.
class CountTabs<T> extends StatelessWidget {
  const CountTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<CountTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, tab) in tabs.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Builder(
              builder: (context) {
                final on = tab.value == selected;
                return Semantics(
                  button: true,
                  selected: on,
                  child: InkWell(
                    onTap: () => onSelected(tab.value),
                    borderRadius: AppRadius.pillAll,
                    child: AnimatedContainer(
                      duration: AppMotion.duration(context, AppMotion.fast),
                      constraints: const BoxConstraints(
                        minHeight: AppSizing.minTapTarget,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: on
                            ? AppColors.primaryContainer
                            : AppColors.surface,
                        borderRadius: AppRadius.pillAll,
                        border: Border.all(
                          color: on ? AppColors.primary600 : AppColors.border,
                          width: on ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tab.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: on
                                  ? AppColors.onPrimaryContainer
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: on
                                  ? AppColors.surface
                                  : AppColors.surfaceVariant,
                              borderRadius: AppRadius.pillAll,
                            ),
                            child: Text(
                              tab.count == null ? '–' : '${tab.count}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
