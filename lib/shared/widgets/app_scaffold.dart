import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import 'app_sidebar.dart';
import 'app_top_bar.dart';
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

/// Standard page body inside the shell: a title row and scrollable content.
///
/// Most screens use this rather than their own `Scaffold`, so page padding,
/// title placement and the primary-action slot stay identical everywhere. A
/// user who has learned where the button is on one screen has learned it on all
/// of them.
class ShellPage extends StatelessWidget {
  const ShellPage({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.scrollable = true,
    this.padding,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Buttons on the title row. The primary action goes last, nearest the
  /// right-hand edge where the thumb is.
  final List<Widget> actions;

  final Widget child;

  /// False when the child manages its own scrolling — a list, or a split view.
  final bool scrollable;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );

    // Two long French action labels plus a title do not fit across a 1024dp
    // tablet — "Enregistrer une livraison" alone is most of a button. Rather
    // than shrink the buttons or clip the title, the header stacks below a
    // threshold and puts the actions on their own row.
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (actions.isEmpty) return titleBlock;

          final actionRow = Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          );

          if (constraints.maxWidth < 820) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [titleBlock, const SizedBox(height: 16), actionRow],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: titleBlock),
              const SizedBox(width: 24),
              Flexible(flex: 2, child: actionRow),
            ],
          );
        },
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (scrollable) child else Expanded(child: child),
      ],
    );

    final padded = Padding(
      padding: padding ?? const EdgeInsets.all(24),
      child: content,
    );

    return scrollable ? SingleChildScrollView(child: padded) : padded;
  }
}
