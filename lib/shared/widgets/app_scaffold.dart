import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/navigation.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'action_density.dart';
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
/// remaining area. There is no top bar on a tablet — the store selector and the
/// user menu live in the sidebar (see `app_sidebar.dart`).
///
/// Used by the go_router `ShellRoute`, so the sidebar persists across
/// navigations instead of rebuilding — the store selector keeps its place and
/// there is no flash of chrome between screens.
///
/// On a phone ([AppBreakpoints.compact] and below) the sidebar cannot stay on
/// screen: even the 88dp icon strip is a quarter of a 360dp window. It moves
/// into a drawer, and a slim bar appears to open it — the one place the app has
/// a top bar, because without it navigation would have no affordance at all.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({required this.store, required this.child, super.key});

  final Store store;

  /// The routed page.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFullScreen = ref.watch(isFullScreenProvider);

    if (isFullScreen) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: child),
      );
    }

    final content = Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );

    if (context.isPhone) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _PhoneAppBar(store: store),
        drawer: Drawer(
          width: AppSizing.sidebarWidthExpanded,
          backgroundColor: AppColors.steel800,
          child: AppSidebar(store: store, variant: SidebarVariant.drawer),
        ),
        body: SafeArea(top: false, child: content),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            AppSidebar(store: store),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

/// The phone-only bar: open the drawer, see which establishment you are in,
/// reach the notifications. Everything else stays in the drawer.
class _PhoneAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _PhoneAppBar({required this.store});

  final Store store;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unread = ref.watch(unreadCountProvider(store.id)).value ?? 0;

    return AppBar(
      backgroundColor: AppColors.steel800,
      foregroundColor: AppColors.white,
      elevation: 0,
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: AppColors.neutral300),
      title: Row(
        children: [
          const Icon(LucideIcons.store, size: AppSizing.iconMd),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              store.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.goSection(Routes.toNotifications(store.id)),
          tooltip: l10n.topBarNotifications,
          color: AppColors.neutral300,
          icon: unread > 0
              ? Badge.count(
                  count: unread,
                  backgroundColor: AppColors.error,
                  textColor: AppColors.white,
                  child: const Icon(LucideIcons.bell, size: AppSizing.iconMd),
                )
              : const Icon(LucideIcons.bell, size: AppSizing.iconMd),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
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
    // On a phone the real shell has no sidebar on screen, so neither does its
    // placeholder — a steel strip here would be chrome that vanishes the moment
    // the establishment resolves.
    if (context.isPhone) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.steel800,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const SizedBox(
            width: 140,
            child: _SidebarSkeletonBlock(height: 16),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: context.pageInsets,
            child: const SkeletonList(),
          ),
        ),
      );
    }

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
    this.keepSubtitle = false,
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

  /// Keeps [subtitle] on a phone, where it is otherwise dropped.
  ///
  /// For the handful of screens whose subtitle is information rather than
  /// description — an unread count, whose price history this is, who is signed
  /// in. Everywhere else the subtitle explains a screen the title has already
  /// named, and three lines of that is a poor trade for the content underneath.
  final bool keepSubtitle;

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
            keepSubtitle: keepSubtitle,
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

    // Page padding tightens on a phone: 24dp a side is a seventh of a 360dp
    // window, and this is dense content that needs the room more than the
    // margin needs the air.
    final insets = padding ?? context.pageInsets;

    final content = scrollable
        ? SingleChildScrollView(padding: insets, child: body)
        : Padding(padding: insets, child: body);

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
    required this.keepSubtitle,
    required this.actions,
    required this.theme,
  });

  final String title;
  final String? subtitle;
  final bool keepSubtitle;
  final List<Widget> actions;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // The subtitle is commentary, not information — "Historique de toutes les
    // entrées, sorties et corrections." under a title that already says
    // Mouvements de stock. On a phone it costs three lines before any stock
    // appears, so it goes. A button's label has to be *moved* when it will not
    // fit, because it is the action; a sentence explaining the screen can
    // simply be dropped.
    //
    // The four screens whose subtitle is real information — an unread count,
    // which product's price history this is — opt out with [keepSubtitle].
    final showSubtitle =
        subtitle != null && (keepSubtitle || !context.isPhone);

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        if (showSubtitle) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );

    if (actions.isEmpty) return titleBlock;

    // Measured against the header's own width rather than the window's: this
    // header is the full width of the page on most screens and half of it in
    // the inventory split view, and the actions have to fit the space they are
    // actually in.
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionRow = ActionDensityScope(
          density: _densityFor(constraints.maxWidth),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        );

        // One `Wrap` rather than a width threshold deciding between a row and a
        // column. A threshold cannot know how much the actions need: at 700dp
        // it pushed Produits' single "Ajouter" onto its own line with half the
        // header sitting empty beside the title, while Mouvements de stock's
        // three genuinely did need the second line.
        //
        // Letting them wrap answers that per page instead of guessing. When
        // both fit, `spaceBetween` holds the title left and the actions hard
        // right — the layout the wide branch used to build by hand. When they
        // do not, the actions take the next line, at its left edge: on a phone
        // that is where the thumb and the eye already are.
        //
        // Stretched to the header's full width, because a `Wrap` otherwise
        // sizes itself to its children and the header's Column hands it loose
        // constraints — leaving `spaceBetween` no free space to distribute and
        // the action tucked against the title instead of out at the right edge.
        return SizedBox(
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.lg,
            children: [
              ConstrainedBox(
                // Keeps a long subtitle from eating the whole line and forcing
                // a wrap on its own — it wraps to a second line instead, which
                // is cheaper than pushing the actions down. The floor stops the
                // rule squeezing the *title* on a narrow header, where 60% is
                // not enough for "Mouvements de stock" on one line.
                constraints: BoxConstraints(
                  maxWidth: math.max(constraints.maxWidth * 0.6, 320),
                ),
                child: titleBlock,
              ),
              actionRow,
            ],
          ),
        );
      },
    );
  }

  /// Header width below which the actions shorten, and then collapse.
  ///
  /// [ActionDensity.iconOnly] only ever reaches the supporting actions —
  /// `PrimaryButton` refuses it — so the teal button keeps its words on a
  /// phone while Modifier, Archiver and Exporter become icons beside it.
  ///
  /// The exception is a header with a single action. Whatever its type, that
  /// button is the only thing the screen offers, and collapsing it to a glyph
  /// leaves the user with nothing to read.
  ActionDensity _densityFor(double width) {
    if (width >= 820) return ActionDensity.full;
    if (width >= AppBreakpoints.compact || actions.length == 1) {
      return ActionDensity.short;
    }
    return ActionDensity.iconOnly;
  }
}
