import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'app_breadcrumbs.dart';
import 'app_sidebar.dart';
import 'app_top_bar.dart';
import 'back_control.dart';
import 'error_state.dart';
import 'loading_state.dart';
import 'offline_banner.dart';

/// The application shell: navigation rail on the left, top bar above, content
/// in the remaining area.
///
/// Used by the go_router `ShellRoute`, so the rail and top bar persist across
/// navigations instead of rebuilding — the store switcher keeps its place and
/// there is no flash of chrome between screens.
class AppScaffold extends StatelessWidget {
  const AppScaffold({required this.store, required this.child, super.key});

  final Store store;

  /// The routed page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            AppSidebar(storeId: store.id),
            Expanded(
              child: Column(
                children: [
                  AppTopBar(store: store),
                  const OfflineBanner(),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shell before the establishment has resolved.
///
/// The rail and the top bar are drawn as placeholders rather than left blank,
/// so switching establishments does not flash empty chrome and then paint it
/// back — the page changes underneath a frame that stays where it is.
///
/// The placeholders are deliberately not the real [AppSidebar] and [AppTopBar]:
/// both need a store to navigate to, and a rail that can be tapped before the
/// destination exists is a rail that navigates nowhere.
class AppScaffoldSkeleton extends StatelessWidget {
  const AppScaffoldSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final double railWidth = context.isRailCollapsed
        ? AppSizing.railWidthCollapsed
        : AppSizing.railWidthExpanded;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: railWidth,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(height: 20),
                  SizedBox(height: AppSpacing.xxl),
                  SkeletonBlock(height: 14),
                  SizedBox(height: AppSpacing.lg),
                  SkeletonBlock(height: 14),
                  SizedBox(height: AppSpacing.lg),
                  SkeletonBlock(height: 14),
                  SizedBox(height: AppSpacing.lg),
                  SkeletonBlock(height: 14),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: AppSizing.topBarHeight,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: const Row(
                      children: [
                        SkeletonBlock(width: 180, height: 18),
                        Spacer(),
                        SkeletonBlock(width: 32, height: 32),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: AppSpacing.pageInsets,
                      child: SkeletonList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shell when the database holds no establishments at all.
///
/// Phase 1 could not reach this: `storeByIdOrFirst` read a list that was
/// compiled in and always had three. A database can genuinely be empty — a
/// failed seed, or a Phase 3 account whose first establishment has not been
/// created yet — and showing the chrome around a blank page would leave
/// somebody tapping a rail that leads nowhere.
class AppScaffoldNoStore extends StatelessWidget {
  const AppScaffoldNoStore({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ErrorState(
          title: l10n.shellNoStoreTitle,
          message: l10n.shellNoStoreBody,
        ),
      ),
    );
  }
}

/// Standard page body inside the shell.
///
/// Every screen uses this, which is what makes the header convention hold
/// without exception:
///
/// - **Left**: back control, breadcrumbs, title, subtitle
/// - **Right**: actions — create, save, export, search, filter
///
/// A user who has learned where the button is on one screen has learned it on
/// all of them, which is the whole point during a busy shift.
class ShellPage extends StatelessWidget {
  const ShellPage({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.scrollable = true,
    this.padding,
    this.back,
    this.crumbs = const [],
    this.onBack,
    this.tabs,
    this.footer,
    this.maxContentWidth,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Buttons on the title row. The primary action goes last, nearest the
  /// right-hand edge.
  final List<Widget> actions;

  final Widget child;

  /// False when the child manages its own scrolling — a list, or a split view.
  final bool scrollable;

  final EdgeInsetsGeometry? padding;

  /// Null on root screens reached from the sidebar: the rail is their
  /// navigation, and a back control there would be lying about the stack.
  final BackDestination? back;

  /// Shown when the screen is more than one level deep.
  final List<Crumb> crumbs;

  /// Intercepts back — forms use it to confirm before discarding input.
  final Future<void> Function()? onBack;

  /// Sub-navigation within a section, e.g. Catégories | Unités.
  final Widget? tabs;

  /// Pinned to the bottom of the content area, above the page edge. Used for
  /// form action bars so they stay reachable on a long form.
  final Widget? footer;

  /// Caps line length on very wide screens. Text measured across 1600dp is
  /// uncomfortable to read regardless of how much room there is.
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (back != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: BackControl(destination: back!, onBack: onBack),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (crumbs.length > 1) ...[
            AppBreadcrumbs(crumbs: crumbs),
            const SizedBox(height: AppSpacing.sm),
          ],
          _TitleRow(
            title: title,
            subtitle: subtitle,
            actions: actions,
            theme: theme,
          ),
          if (tabs != null) ...[const SizedBox(height: AppSpacing.lg), tabs!],
        ],
      ),
    );

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (scrollable) child else Expanded(child: child),
      ],
    );

    if (maxContentWidth != null) {
      body = Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth!),
          child: body,
        ),
      );
    }

    final content = scrollable
        ? SingleChildScrollView(
            padding: padding ?? AppSpacing.pageInsets,
            child: body,
          )
        : Padding(padding: padding ?? AppSpacing.pageInsets, child: body);

    if (footer == null) return content;

    // The footer sits outside the scroll view so it stays put while the form
    // scrolls under it.
    return Column(
      children: [
        Expanded(child: content),
        footer!,
      ],
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.theme,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );

    if (actions.isEmpty) return titleBlock;

    return LayoutBuilder(
      builder: (context, constraints) {
        final actionRow = Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );

        // Two long French action labels plus a title do not fit across a
        // 1024dp tablet. Below this the actions take their own row rather than
        // squeezing the title.
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              const SizedBox(height: AppSpacing.lg),
              actionRow,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: titleBlock),
            const SizedBox(width: AppSpacing.xl),
            Flexible(flex: 2, child: actionRow),
          ],
        );
      },
    );
  }
}
