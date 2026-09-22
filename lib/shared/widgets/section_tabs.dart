import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// One destination in a [SectionTabs] bar.
@immutable
class SectionTab {
  const SectionTab({
    required this.label,
    required this.path,
    this.icon,
    this.description,
    this.attention,
  });

  final String label;
  final String path;

  /// Shown before the label. Optional so the two-tab bars (Catégories |
  /// Unités, Lignes | Réceptions) can stay text only.
  final IconData? icon;

  /// A one-line summary, shown only in the vertical layout where there is room
  /// for it — "what is behind this tab" before tapping it.
  final String? description;

  /// When set, a dot marks the tab and this is read out to a screen reader —
  /// the sync tab uses it while offline or with changes waiting.
  final String? attention;
}

/// How a [SectionTabs] lays itself out, set by the page around it.
///
/// An inherited scope rather than a constructor argument because the bar is
/// usually built by a wrapper (the settings tabs are a `ConsumerWidget` that
/// adds the sync dot) and [ShellPage] decides where it goes without knowing
/// what that wrapper is.
class SectionTabsAxis extends InheritedWidget {
  const SectionTabsAxis({required this.axis, required super.child, super.key});

  final Axis axis;

  static Axis of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SectionTabsAxis>()?.axis ??
      Axis.horizontal;

  @override
  bool updateShouldNotify(SectionTabsAxis oldWidget) => axis != oldWidget.axis;
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
/// One line that scrolls sideways rather than wrapping: a bar broken over two
/// lines reads as two bars. When a page asks for it (see
/// [ShellPage.sideTabsOnWide]) and the window is wide enough, the same tabs
/// become a vertical list beside the content instead.
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

  void _select(BuildContext context, SectionTab tab) =>
      onSelected == null ? context.goSection(tab.path) : onSelected!(tab.path);

  @override
  Widget build(BuildContext context) {
    if (SectionTabsAxis.of(context) == Axis.vertical) {
      return FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tab in tabs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _SideTab(
                  tab: tab,
                  selected: tab.path == currentPath,
                  onTap: () => _select(context, tab),
                ),
              ),
          ],
        ),
      );
    }

    // Measured against the space the bar actually has rather than the
    // window: the supplier detail puts it in half a split view, and at 150%
    // text four French labels outgrow a tablet too.
    return LayoutBuilder(
      builder: (context, constraints) {
        // When the labels do not fit, the tabs that are not open shrink to
        // their icon — only when every tab has one, since a bar mixing icons
        // and words reads worse than either. Without icons the row scrolls
        // sideways instead of breaking onto a second line.
        final compact =
            tabs.every((tab) => tab.icon != null) &&
            _fullWidth(context) > constraints.maxWidth;

        return FocusTraversalGroup(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.mdAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, tab) in tabs.indexed) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.xs),
                    _Tab(
                      tab: tab,
                      selected: tab.path == currentPath,
                      iconOnly: compact && tab.path != currentPath,
                      onTap: () => _select(context, tab),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Width of the bar with every label shown, at the current text scale.
  /// Labels are measured at the selected weight, the widest they get.
  double _fullWidth(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
    final scaler = MediaQuery.textScalerOf(context);
    var width = AppSpacing.xs * 2 + AppSpacing.xs * (tabs.length - 1);
    for (final tab in tabs) {
      final painter = TextPainter(
        text: TextSpan(text: tab.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      width += painter.width + AppSpacing.lg * 2;
      if (tab.icon != null) width += AppSizing.iconSm + AppSpacing.sm;
      painter.dispose();
    }
    return width;
  }
}

const _tabAnimation = Duration(milliseconds: 180);

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.selected,
    required this.iconOnly,
    required this.onTap,
  });

  final SectionTab tab;
  final bool selected;
  final bool iconOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tab.icon != null)
          _Dotted(
            show: tab.attention != null,
            child: Icon(
              tab.icon,
              size: AppSizing.iconSm,
              color: selected ? AppColors.primary600 : color,
            ),
          ),
        if (!iconOnly) ...[
          if (tab.icon != null) const SizedBox(width: AppSpacing.sm),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (tab.icon == null && tab.attention != null) ...[
            const SizedBox(width: AppSpacing.sm),
            const _Dot(),
          ],
        ],
      ],
    );

    if (iconOnly) content = Tooltip(message: tab.label, child: content);

    return Semantics(
      selected: selected,
      button: true,
      label: iconOnly ? tab.label : null,
      hint: tab.attention,
      child: AnimatedContainer(
        duration: _tabAnimation,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : AppColors.surfaceVariant,
          borderRadius: AppRadius.smAll,
          boxShadow: [
            if (selected)
              BoxShadow(
                color: AppColors.neutral950.withValues(alpha: 0.10),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: selected ? null : onTap,
            borderRadius: AppRadius.smAll,
            // A minimum rather than a fixed height. 48dp is the floor the
            // brief sets for a tap target; at 150% text the label needs more
            // than that and a fixed height would clip it instead of growing.
            child: AnimatedSize(
              duration: _tabAnimation,
              curve: Curves.easeOut,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSizing.minTapTarget,
                  minWidth: AppSizing.minTapTarget,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: iconOnly ? AppSpacing.md : AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tab in the vertical layout: icon, label and its one-line description.
class _SideTab extends StatelessWidget {
  const _SideTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final SectionTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      selected: selected,
      button: true,
      hint: tab.attention,
      child: AnimatedContainer(
        duration: _tabAnimation,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: AppRadius.mdAll,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: selected ? null : onTap,
            borderRadius: AppRadius.mdAll,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSizing.minTapTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tab.icon != null) ...[
                    _Dotted(
                      show: tab.attention != null,
                      child: Icon(
                        tab.icon,
                        size: AppSizing.iconMd,
                        color: selected
                            ? AppColors.primary700
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tab.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: selected
                                ? AppColors.primary700
                                : AppColors.textPrimary,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        if (tab.description != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            tab.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts a small warning dot on the top-right corner of [child].
class _Dotted extends StatelessWidget {
  const _Dotted({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        const Positioned(top: -2, right: -3, child: _Dot()),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: AppColors.warning,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.surface, width: 1.5),
    ),
  );
}
