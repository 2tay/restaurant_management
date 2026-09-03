import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'app_breadcrumbs.dart';
import 'app_sidebar.dart';
import 'back_control.dart';
import 'error_state.dart';
import 'loading_state.dart';
import 'offline_banner.dart';

/// Whether the shell's navigation sidebar is hidden so the current page's
/// content fills the whole window.
///
/// Local UI state — see `offline_banner.dart`'s `OfflineMode` for the same
/// reasoning: this is the only thing Riverpod is permitted to hold in Phase
/// 1, and a `Notifier<bool>` rather than a page's own `State` because the
/// toggle lives on a page (the pointage kiosk board) while the thing it
/// controls, [AppScaffold], is that page's ancestor.
///
/// Off by default. A page offering the toggle owns turning it back off in its
/// `dispose`, so full screen never leaks into an unrelated screen reached by
/// navigating away.
///
/// The pointage kiosk board toggles this — a tablet by the door wants the
/// whole screen for the attendance grid.
class FullScreenMode extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  // `ref.mounted` guards the call a page's `dispose` defers to a microtask —
  // by the time it runs, a fast enough sequence of navigations (or a test
  // tearing its `ProviderScope` down) may have already disposed this provider,
  // and writing to a disposed provider throws.
  // ignore: use_setters_to_change_properties
  void set(bool value) {
    if (ref.mounted) state = value;
  }
}

final isFullScreenProvider = NotifierProvider<FullScreenMode, bool>(
  FullScreenMode.new,
);

/// The application shell: navigation sidebar on the left, content in the
/// remaining area. There is no top bar — the store selector and the user menu
/// live in the sidebar (see `app_sidebar.dart`).
///
/// Used by the go_router `ShellRoute`, so the sidebar persists across
/// navigations instead of rebuilding — the store selector keeps its place and
/// there is no flash of chrome between screens.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({required this.store, required this.child, super.key});

  final Store store;

  /// The routed page.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFullScreen = ref.watch(isFullScreenProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isFullScreen
            ? child
            : Row(
                children: [
                  AppSidebar(store: store),
                  Expanded(
                    child: Column(
                      children: [
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
/// The sidebar is drawn as a steel placeholder rather than left blank, so
/// switching establishments does not flash empty chrome and then paint it back
/// — the page changes underneath a frame that stays where it is.
///
/// The placeholder is deliberately not the real [AppSidebar]: it needs a store
/// to navigate to, and a sidebar that can be tapped before the destination
/// exists is one that navigates nowhere.
class AppScaffoldSkeleton extends StatelessWidget {
  const AppScaffoldSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = context.isSidebarCollapsed
        ? AppSizing.sidebarWidthCollapsed
        : AppSizing.sidebarWidthExpanded;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: sidebarWidth,
              decoration: const BoxDecoration(
                color: AppColors.steel800,
                border: Border(right: BorderSide(color: AppColors.steel700)),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SidebarSkeletonBlock(height: 20),
                  SizedBox(height: AppSpacing.xxl),
                  _SidebarSkeletonBlock(height: 14),
                  SizedBox(height: AppSpacing.lg),
                  _SidebarSkeletonBlock(height: 14),
                  SizedBox(height: AppSpacing.lg),
                  _SidebarSkeletonBlock(height: 14),
                  SizedBox(height: AppSpacing.lg),
                  _SidebarSkeletonBlock(height: 14),
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
    );
  }
}

/// A muted bar on the steel sidebar ground — [SkeletonBlock] is tuned for
/// light surfaces and washes out here.
class _SidebarSkeletonBlock extends StatelessWidget {
  const _SidebarSkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: const BoxDecoration(
      color: AppColors.steel700,
      borderRadius: AppRadius.smAll,
    ),
  );
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
    final titleText = Text(title, style: theme.textTheme.headlineMedium);
    final subtitleText = subtitle == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(subtitle!, style: theme.textTheme.bodyMedium),
          );

    if (actions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleText, ?subtitleText],
      );
    }

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
              Align(alignment: Alignment.centerLeft, child: titleText),
              if (subtitleText != null)
                Align(alignment: Alignment.centerLeft, child: subtitleText),
              const SizedBox(height: AppSpacing.lg),
              actionRow,
            ],
          );
        }

        // The actions sit on the title's line — vertically centred on it, hard
        // against the right edge — and the description runs under both.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: titleText),
                const SizedBox(width: AppSpacing.xl),
                Flexible(flex: 2, child: actionRow),
              ],
            ),
            ?subtitleText,
          ],
        );
      },
    );
  }
}
