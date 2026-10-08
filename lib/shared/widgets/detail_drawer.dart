import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'adaptive_row.dart';

/// A panel that slides in from the right for a row's detail — the attendance
/// and payment history both open one instead of navigating away or throwing a
/// full-screen modal.
///
/// ~440px on a desktop, near full-width below 600. Dismissed by the close
/// button, the scrim, or Échap.
///
/// With no [title] the panel is bare: the close button alone at the top
/// right, no rule under it — the content is its own heading (the pointage
/// drawers).
class DetailDrawer extends StatelessWidget {
  const DetailDrawer({required this.children, this.title, super.key});

  /// The panel's heading, over a hairline. Null for a bare panel.
  final String? title;
  final List<Widget> children;

  static Future<void> show(
    BuildContext context, {
    required List<Widget> children,
    String? title,
  }) =>
      _slideIn(context, (_) => DetailDrawer(title: title, children: children));

  /// The same panel around content that brings its own header — a view that
  /// is also a page or a pane elsewhere, like a product's detail. [width] on
  /// a tablet and up.
  ///
  /// On a phone it is a bottom sheet instead: a panel sliding in from the
  /// right at full width is a page with no way to swipe it away, and the
  /// sheet's handle is the gesture a phone user already reaches for.
  static Future<void> showCustom(
    BuildContext context, {
    required WidgetBuilder builder,
    double width = 440,
  }) {
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.compact) {
      return _sheet(context, builder);
    }
    return _slideIn(
      context,
      (context) => _DrawerPanel(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: builder(context),
        ),
      ),
    );
  }

  /// Most of the screen's height, so the content under it still shows above
  /// and reads as "this is over the list", not as a new page.
  static Future<void> _sheet(BuildContext context, WidgetBuilder builder) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => DrawerScope(
        close: () => Navigator.of(context).pop(),
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: builder(context),
          ),
        ),
      ),
    );
  }

  static Future<void> _slideIn(BuildContext context, WidgetBuilder builder) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: AppMotion.duration(context, AppMotion.page),
      // A link inside closes the drawer before it navigates — see
      // [DrawerScope] — so the page it opens is not hidden behind it.
      pageBuilder: (context, _, _) => DrawerScope(
        close: () => Navigator.of(context).pop(),
        child: builder(context),
      ),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: AppMotion.enter)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bare = title == null;

    return _DrawerPanel(
      width: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              bare ? AppSpacing.sm : AppSpacing.md,
              AppSpacing.sm,
              bare ? 0 : AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: bare
                      ? const SizedBox.shrink()
                      : Text(title!, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x),
                  tooltip: l10n.actionClose,
                ),
              ],
            ),
          ),
          if (!bare)
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
          Expanded(
            child: ListView(
              padding: bare
                  ? const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    )
                  : const EdgeInsets.all(AppSpacing.xl),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// The sheet itself: pinned right, full height, [width] wide — at most 480 on
/// a tablet in portrait, where 560 would cover most of the list it opened
/// from — or the whole screen on a phone.
class _DrawerPanel extends StatelessWidget {
  const _DrawerPanel({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < AppBreakpoints.compact
        ? screenWidth
        : screenWidth < AppBreakpoints.medium
        ? width.clamp(0.0, 480.0)
        : width.clamp(0.0, screenWidth);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        elevation: 16,
        color: AppColors.surface,
        child: SizedBox(
          width: panelWidth,
          height: double.infinity,
          child: SafeArea(child: child),
        ),
      ),
    );
  }
}

/// A `label — value` line for the drawer body. `value` may be a string or,
/// via [valueWidget], any widget (a badge, an amount).
class DrawerRow extends StatelessWidget {
  const DrawerRow({
    required this.label,
    this.value,
    this.valueWidget,
    super.key,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The 140dp label gutter is right in a 440dp panel and wrong in the
    // full-width one a phone gets, where it leaves a French label like
    // "Heures supplémentaires" wrapping to three lines beside a one-word
    // value. Below the threshold the label sits above the value instead.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AdaptiveRow(
        breakpoint: 320,
        crossAxisAlignment: CrossAxisAlignment.start,
        runSpacing: AppSpacing.xxs,
        cells: [
          AdaptiveCell(
            width: AppSizing.drawerLabelWidth,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          AdaptiveCell(
            flex: 1,
            child:
                valueWidget ??
                Text(value ?? '—', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
