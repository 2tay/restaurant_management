import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// One destination in a [SectionTabs] bar.
@immutable
class SectionTab {
  const SectionTab({required this.label, required this.path});

  final String label;
  final String path;
}

/// Sub-navigation within a sidebar section.
///
/// Added because four screens shipped in Phase 1 with routes but no way to
/// reach them: units of measure, notification preferences, sync status, and
/// stock adjustment. They were built, routed, tested — and invisible.
///
/// A segmented bar rather than more sidebar entries: the rail is already nine
/// deep, and these are variations within a section rather than sections of
/// their own.
///
/// Switching tabs uses `go` rather than `push` — moving between peers should
/// replace, not stack, or back would walk through every tab the user browsed.
class SectionTabs extends StatelessWidget {
  const SectionTabs({
    required this.tabs,
    required this.currentPath,
    this.onSelected,
    super.key,
  });

  final List<SectionTab> tabs;

  /// The path of the tab currently shown.
  final String currentPath;

  /// Switches tabs in place instead of navigating.
  ///
  /// The order detail's Lines / Receipts tabs are two views of one screen
  /// rather than two screens, so they have no routes of their own — but they
  /// should look and behave exactly like the tabs that do. When this is set,
  /// [SectionTab.path] is just an identifier.
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdAll,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final tab in tabs)
            _Tab(
              tab: tab,
              selected: tab.path == currentPath,
              onTap: () => onSelected == null
                  ? context.goSection(tab.path)
                  : onSelected!(tab.path),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.selected, required this.onTap});

  final SectionTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: AppRadius.smAll,
      elevation: selected ? 1 : 0,
      shadowColor: AppColors.neutral950.withValues(alpha: 0.12),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          height: AppSizing.minTapTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          child: Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
