import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// A detail view inside a panel: its own header, pinned, over a scrolling body.
///
/// A panel has no page header to carry the title, so the view draws one. It
/// stays put while the body scrolls, for the same reason the product panel's
/// does: a 560dp column of summary, lines and notes is long, and what you are
/// reading and the way out must not scroll away from you halfway down it.
///
/// The back arrow appears only when the panel has somewhere to go back to —
/// a réception opened from inside a commande. It sits where the close button
/// would be on a first panel, which is why it belongs to the view rather than
/// to a frame drawn around it.
class PanelScaffold extends StatelessWidget {
  const PanelScaffold({
    required this.panel,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.status,
    super.key,
  });

  final PanelController panel;
  final String title;
  final String? subtitle;

  /// Buttons, in the top right beside the close control.
  ///
  /// They sat on a row of their own under the title, which cost a line of a
  /// panel before the content had said anything — and at 560dp two French
  /// labels and a badge wrapped onto two lines of their own. Up here they are
  /// where an action is looked for, and the panel publishes a density so they
  /// shrink themselves rather than being measured from outside.
  final List<Widget> actions;

  /// Shown under the subtitle. For a status badge — information, not an
  /// action, so it does not belong in the button row.
  final Widget? status;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (panel.canGoBack) ...[
              IconButton(
                onPressed: panel.back,
                tooltip: l10n.actionBack,
                icon: const Icon(LucideIcons.arrowLeft, size: AppSizing.iconMd),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (status != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Align(alignment: Alignment.centerLeft, child: status!),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              // The panel says how much room it can afford and each button
              // decides what that means for it — the same bargain a page
              // header makes with `ShellPage`. A phone-width panel drops the
              // supporting labels; the teal primary keeps its words either
              // way, because it is the answer to "what do I do here".
              ActionDensityScope(
                density: context.isPhone
                    ? ActionDensity.iconOnly
                    : ActionDensity.short,
                child: Wrap(
                  spacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              onPressed: panel.close,
              tooltip: l10n.actionClose,
              icon: const Icon(LucideIcons.x, size: AppSizing.iconMd),
            ),
          ],
        ),
        const Divider(height: AppSpacing.lg, color: AppColors.hairline),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: child,
          ),
        ),
      ],
    );
  }
}
