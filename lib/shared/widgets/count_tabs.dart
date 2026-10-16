import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// One tab of a [CountTabs] row: what it selects, what it says, and how many
/// rows it would show. A null [count] is still loading, and shows a dash — a
/// zero would be a claim made before anything was read.
class CountTab<T> {
  const CountTab({
    required this.value,
    required this.label,
    this.count,
    this.icon,
    this.colors,
  });

  final T value;
  final String label;
  final int? count;

  /// Beside the count in the segmented bar.
  final IconData? icon;

  /// The tab's own colour in the segmented bar — red for Rupture, amber for
  /// Stock bas. Null takes the brand's.
  final StockStatusColors? colors;
}

/// A row of pill tabs, each with the number of rows it would show — the
/// status switch above the commandes and the alerts.
///
/// Where the pills fit, a row of them — scrolling sideways at a pinch rather
/// than wrapping. Narrower than [_segmentedBelow] (a phone) they become one
/// segmented bar instead: every tab an equal share of the width, its count
/// over its label, so all of them are in reach without a sideways scroll and
/// the list below starts at the same height whatever is selected.
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

  /// The width under which the tabs become a segmented bar.
  static const double _segmentedBelow = 560;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < _segmentedBelow
          ? _segmented(context)
          : _pills(context),
    );
  }

  /// One bar, the tabs sharing it equally: the icon and the count, the label
  /// under them. The chosen one lifts out as a white card in its own colour;
  /// the others stay flat, muted when there is nothing in them.
  Widget _segmented(BuildContext context) {
    final theme = Theme.of(context);
    final duration = AppMotion.duration(context, AppMotion.normal);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          for (final (i, tab) in tabs.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Builder(
                builder: (context) {
                  final on = tab.value == selected;
                  final colors = tab.colors ?? AppColors.brandTint;
                  final count = tab.count;
                  // Muted when empty, so the eye goes to the tabs holding
                  // something.
                  final empty = count == 0;
                  final iconColor = on
                      ? colors.solid
                      : empty
                      ? AppColors.textDisabled
                      : colors.solid;

                  return Semantics(
                    button: true,
                    selected: on,
                    child: AnimatedContainer(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: on ? AppColors.surface : Colors.transparent,
                        borderRadius: AppRadius.mdAll,
                        boxShadow: on
                            ? [
                                BoxShadow(
                                  color: AppColors.neutral950.withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : const [],
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: () => onSelected(tab.value),
                          borderRadius: AppRadius.mdAll,
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: AppSizing.minTapTarget + 4,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: AppSpacing.sm,
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (tab.icon != null) ...[
                                        AnimatedContainer(
                                          duration: duration,
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: on
                                                ? colors.container
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            tab.icon,
                                            size: 13,
                                            color: iconColor,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                      ],
                                      Text(
                                        count == null ? '–' : '$count',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              height: 1.1,
                                              color: on
                                                  ? colors.foreground
                                                  : empty
                                                  ? AppColors.textSecondary
                                                  : AppColors.textPrimary,
                                            ),
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs + 1),
                                // Shrinks rather than cuts: « Jours chargés »
                                // is the longest, and a quarter of a phone is
                                // short of it at the largest text sizes.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tab.label,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 11,
                                      letterSpacing: 0.1,
                                      fontWeight: on
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: on
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The pills, side by side.
  Widget _pills(BuildContext context) {
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
