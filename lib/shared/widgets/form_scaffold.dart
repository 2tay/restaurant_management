import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'app_scaffold.dart';
import 'confirm_dialog.dart';
import 'primary_button.dart';

/// Every form screen in the app.
///
/// Exists so three rules hold everywhere without each screen re-implementing
/// them:
///
/// 1. **Cancel bottom-left, submit bottom-right.** Dismissive actions left,
///    constructive right, on every form without exception.
/// 2. **The action bar is pinned.** On a long form — add item, add supplier —
///    the submit button must not require scrolling to reach.
/// 3. **Unsaved input is never lost silently.** Leaving a dirty form confirms
///    first, and the same guard covers the on-screen back control, the Cancel
///    button, and the Android system back gesture. A guard that only catches
///    one of the three is worse than none, because it teaches the user the app
///    protects them when it does not.
class FormScaffold extends StatelessWidget {
  const FormScaffold({
    required this.title,
    required this.back,
    required this.submitLabel,
    required this.onSubmit,
    required this.child,
    this.subtitle,
    this.keepSubtitle = false,
    this.crumbs = const [],
    this.submitIcon,
    this.isDirty = false,
    this.secondaryAction,
    this.submitSecondary,
    this.forwardActions = const [],
    this.headerBackLinkLabel,
    this.centered = false,
    this.maxWidth = 760,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Keeps [subtitle] on a phone — see [ShellPage.keepSubtitle]. True on the
  /// forms whose subtitle names the record being edited.
  final bool keepSubtitle;

  /// Where Cancel and back lead.
  final BackDestination back;

  final List<Crumb> crumbs;

  final String submitLabel;
  final IconData? submitIcon;

  /// Null disables the submit button — the form is incomplete.
  final VoidCallback? onSubmit;

  /// Whether the user has typed anything worth protecting.
  final bool isDirty;

  /// An extra action on the left of the bar, beside Cancel. Used for Delete on
  /// edit forms, which is dismissive-adjacent and belongs on that side.
  final Widget? secondaryAction;

  /// A second forward action, placed to the left of the primary submit.
  ///
  /// The order form needs it: `Save draft` and `Send order` are both
  /// constructive, so both belong on the right, with the more consequential one
  /// nearest the edge. Putting `Save draft` on the left with Cancel would file
  /// it as a way out of the form, which is the opposite of what it does.
  final Widget? submitSecondary;

  /// Further constructive actions, placed left of [submitSecondary] and the
  /// primary submit — a wizard's Précédent / Suivant.
  final List<Widget> forwardActions;

  /// When set, the way back is a link on the right of the title row with this
  /// label, instead of the back control above the title (and no breadcrumbs).
  /// It goes through the same unsaved-input guard.
  final String? headerBackLinkLabel;

  /// Centres the form column — header, body and the action bar's buttons —
  /// in the window, instead of holding it to the left edge.
  final bool centered;

  final double maxWidth;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      // Taking control of pops so the Android back gesture runs through the
      // same confirmation as everything else.
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard(context);
        if (leave && context.mounted) context.backTo(back.path);
      },
      child: ShellPage(
        title: title,
        subtitle: subtitle,
        keepSubtitle: keepSubtitle,
        back: headerBackLinkLabel == null ? back : null,
        crumbs: headerBackLinkLabel == null ? crumbs : const [],
        actions: [
          if (headerBackLinkLabel != null)
            _HeaderBackLink(
              label: headerBackLinkLabel!,
              onPressed: () => _leave(context),
            ),
        ],
        onBack: () => _leave(context),
        maxContentWidth: maxWidth,
        centerContent: centered,
        // A centred form keeps a root-screen header: title left, the way back
        // at the page's right edge (see Personnel and its Ajouter button).
        fullWidthHeader: centered,
        footer: _ActionBar(
          maxWidth: maxWidth,
          centered: centered,
          leading: [
            SecondaryButton(
              label: l10n.actionCancel,
              onPressed: () => _leave(context),
            ),
            ?secondaryAction,
          ],
          trailing: [
            ...forwardActions,
            ?submitSecondary,
            PrimaryButton(
              label: submitLabel,
              icon: submitIcon,
              onPressed: onSubmit,
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Future<void> _leave(BuildContext context) async {
    if (!isDirty) {
      context.backTo(back.path);
      return;
    }
    final leave = await _confirmDiscard(context);
    if (leave && context.mounted) context.backTo(back.path);
  }

  Future<bool> _confirmDiscard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConfirmDialog.show(
      context,
      title: l10n.discardChangesTitle,
      message: l10n.discardChangesBody,
      confirmLabel: l10n.discardChangesConfirm,
      cancelLabel: l10n.discardChangesCancel,
    );
  }
}

/// The way back as a link on the title row — see
/// [FormScaffold.headerBackLinkLabel].
class _HeaderBackLink extends StatelessWidget {
  const _HeaderBackLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(LucideIcons.arrowLeft, size: AppSizing.iconSm),
      label: Text(label),
    );
  }
}

/// The pinned bar along the bottom of a form.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.leading,
    required this.trailing,
    required this.maxWidth,
    required this.centered,
  });

  /// Dismissive actions, left to right. Cancel first.
  final List<Widget> leading;

  /// Constructive actions, with the most consequential last.
  final List<Widget> trailing;

  final double maxWidth;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.isPhone ? AppSpacing.lg : AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Align(
        alignment: centered ? Alignment.topCenter : Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Phone: one action per line, full width, constructive on top.
              // Half-width buttons side by side at 360dp leave French labels
              // like "Enregistrer les modifications" nowhere to go, and the
              // submit is the reason the user is on this screen.
              if (constraints.maxWidth < AppBreakpoints.compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, action) in [
                      ...trailing.reversed,
                      ...leading,
                    ].indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      action,
                    ],
                  ],
                );
              }

              // An edit form carries three controls — Cancel, Delete, Save —
              // and three French labels do not fit one bar on a narrow pane.
              // Stacking keeps the convention readable: the constructive
              // action stays on top and full width, dismissive ones below.
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _wrap(trailing, WrapAlignment.end),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _wrap(leading, WrapAlignment.start),
                    ),
                  ],
                );
              }

              // The convention, enforced structurally: dismissive left,
              // constructive right, with the gap between them so neither is
              // mistaken for the other in a hurry.
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: _wrap(leading, WrapAlignment.start)),
                  const SizedBox(width: AppSpacing.lg),
                  Flexible(child: _wrap(trailing, WrapAlignment.end)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _wrap(List<Widget> children, WrapAlignment alignment) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.sm,
    alignment: alignment,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
}
