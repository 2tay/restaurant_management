import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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
    this.crumbs = const [],
    this.submitIcon,
    this.isDirty = false,
    this.secondaryAction,
    this.submitSecondary,
    this.maxWidth = 760,
    super.key,
  });

  final String title;
  final String? subtitle;

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
        back: back,
        crumbs: crumbs,
        onBack: () => _leave(context),
        maxContentWidth: maxWidth,
        footer: _ActionBar(
          maxWidth: maxWidth,
          leading: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SecondaryButton(
                label: l10n.actionCancel,
                onPressed: () => _leave(context),
              ),
              ?secondaryAction,
            ],
          ),
          trailing: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ?submitSecondary,
              PrimaryButton(
                label: submitLabel,
                icon: submitIcon,
                onPressed: onSubmit,
              ),
            ],
          ),
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

/// The pinned bar along the bottom of a form.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.leading,
    required this.trailing,
    required this.maxWidth,
  });

  final Widget leading;
  final Widget trailing;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // An edit form carries three controls — Cancel, Delete, Save —
              // and three French labels do not fit one bar on a narrow pane.
              // Stacking keeps the convention readable: the constructive
              // action stays on top and full width, dismissive ones below.
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    trailing,
                    const SizedBox(height: AppSpacing.md),
                    Align(alignment: Alignment.centerLeft, child: leading),
                  ],
                );
              }

              // The convention, enforced structurally: dismissive left,
              // constructive right, with the gap between them so neither is
              // mistaken for the other in a hurry.
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: leading),
                  const SizedBox(width: AppSpacing.lg),
                  Flexible(child: trailing),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
