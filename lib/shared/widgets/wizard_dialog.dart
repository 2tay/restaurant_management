import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'action_density.dart';
import 'app_text_field.dart';
import 'confirm_dialog.dart';
import 'primary_button.dart';
import 'wizard_step_indicator.dart';

/// One page of a [WizardDialog].
class WizardStep {
  const WizardStep({
    required this.label,
    required this.child,
    this.isValid = true,
  });

  /// Shown in the step indicator.
  final String label;

  final Widget child;

  /// Whether this step's input is complete — gates Suivant, and (all steps
  /// together) the final submit.
  final bool isValid;
}

/// A form split into steps, in a pop-up over the screen it was opened from —
/// the list stays in place behind it.
///
/// - **Header:** [title], the [description] paragraph under it (dropped on a
///   phone, where the step indicator says enough), and a close button.
/// - **Body:** the [WizardStepIndicator], then the current step, scrolling on
///   its own when it is taller than the dialog. Fields in a step are the
///   plain (white, borderless) variant, on the dialog's page-grey surface.
/// - **Actions:** Réinitialiser on the left (the close button is the way
///   out); Précédent, then Suivant — or [submitLabel] on the last step — on
///   the right.
///
/// On a phone the dialog is full screen and the actions stay on one line:
/// the secondary ones collapse to icons, the primary keeps its words and
/// takes the rest of the width.
///
/// Controlled: the parent holds [currentStep] and moves it in
/// [onStepChanged], so it can also send the user back to a step (a field
/// refused on save, for instance).
///
/// With [freeNavigation] (editing an existing record) any step is reachable
/// from the indicator once the steps before it are valid, and the submit is on
/// every step.
///
/// **Unsaved input is never lost silently:** with [isDirty], the close
/// button, Annuler, Échap, a tap on the barrier and the system back all ask
/// first — the same promise `FormScaffold` makes for a form page.
class WizardDialog extends StatelessWidget {
  const WizardDialog({
    required this.title,
    required this.steps,
    required this.currentStep,
    required this.onStepChanged,
    required this.submitLabel,
    required this.onSubmit,
    this.description,
    this.submitIcon,
    this.isDirty = false,
    this.freeNavigation = false,
    this.onReset,
    this.maxWidth = 880,
    super.key,
  }) : assert(steps.length > 1, 'a wizard has at least two steps');

  final String title;
  final String? description;

  final List<WizardStep> steps;
  final int currentStep;
  final ValueChanged<int> onStepChanged;

  final String submitLabel;
  final IconData? submitIcon;

  /// Called once every step is valid; null disables the submit.
  final VoidCallback? onSubmit;

  final bool isDirty;
  final bool freeNavigation;

  /// Puts the form back to where it started. Asked for first, and only
  /// offered once something has been typed ([isDirty]).
  final VoidCallback? onReset;

  final double maxWidth;

  /// Opens the dialog [builder] returns. A tap outside it closes it — through
  /// the dialog's own unsaved-input guard.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return showDialog<T>(context: context, builder: builder);
  }

  bool get _isLast => currentStep == steps.length - 1;

  bool get _allValid => steps.every((s) => s.isValid);

  bool _stepsBeforeValid(int index) =>
      steps.take(index).every((s) => s.isValid);

  Future<void> _confirmReset(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final reset = await ConfirmDialog.show(
      context,
      title: l10n.wizardResetTitle,
      message: l10n.wizardResetBody,
      confirmLabel: l10n.wizardReset,
    );
    if (reset) onReset?.call();
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

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;

    final content = Padding(
      padding: EdgeInsets.all(phone ? AppSpacing.lg : AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(title: title, description: phone ? null : description),
          const SizedBox(height: AppSpacing.xl),
          WizardStepIndicator(
            labels: [for (final s in steps) s.label],
            current: currentStep,
            onStepTapped: onStepChanged,
            canJumpTo: (i) =>
                freeNavigation ? _stepsBeforeValid(i) : i < currentStep,
          ),
          const SizedBox(height: AppSpacing.xl),
          Flexible(
            child: SingleChildScrollView(
              child: AppTextFieldVariantScope(
                variant: AppTextFieldVariant.plain,
                child: KeyedSubtree(
                  key: ValueKey('wizard-page-$currentStep'),
                  child: steps[currentStep].child,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _actions(context, phone: phone),
        ],
      ),
    );

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard(context);
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: phone
          ? Dialog.fullscreen(
              backgroundColor: AppColors.background,
              child: SafeArea(child: content),
            )
          : Dialog(
              backgroundColor: AppColors.background,
              insetPadding: const EdgeInsets.all(AppSpacing.xl),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.lgAll,
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: content,
              ),
            ),
    );
  }

  Widget _actions(BuildContext context, {required bool phone}) {
    final l10n = AppLocalizations.of(context);
    final step = steps[currentStep];
    final showSubmit = _isLast || freeNavigation;
    final goNext = step.isValid ? () => onStepChanged(currentStep + 1) : null;

    final reset = SecondaryButton(
      key: const ValueKey('wizard-reset'),
      label: l10n.wizardReset,
      icon: LucideIcons.rotateCcw,
      tone: SecondaryButtonTone.quiet,
      onPressed: onReset != null && isDirty
          ? () => _confirmReset(context)
          : null,
    );
    final previous = currentStep == 0
        ? null
        : SecondaryButton(
            key: const ValueKey('wizard-previous'),
            label: l10n.wizardPrevious,
            icon: LucideIcons.arrowLeft,
            tone: SecondaryButtonTone.surface,
            onPressed: () => onStepChanged(currentStep - 1),
          );
    // Editing: Suivant is a plain way on, next to the always-there save.
    final secondaryNext = !_isLast && freeNavigation
        ? SecondaryButton(
            key: const ValueKey('wizard-next'),
            label: l10n.wizardNext,
            icon: LucideIcons.arrowRight,
            tone: SecondaryButtonTone.surface,
            onPressed: goNext,
          )
        : null;
    final primary = showSubmit
        ? PrimaryButton(
            label: submitLabel,
            icon: submitIcon,
            onPressed: onSubmit != null && _allValid ? onSubmit : null,
          )
        // Suivant moves on; only the final save is the solid commit.
        : PrimaryButton(
            label: l10n.wizardNext,
            icon: LucideIcons.arrowRight,
            tonal: true,
            onPressed: goNext,
          );

    final forward = [?previous, ?secondaryNext, primary];

    if (phone) {
      // One line: the secondary buttons as icons (their names move to
      // tooltips — see ActionDensity.iconOnly), the primary keeps its words
      // and takes whatever width is left.
      return ActionDensityScope(
        density: ActionDensity.iconOnly,
        child: Row(
          children: [
            if (onReset != null) ...[
              reset,
              const SizedBox(width: AppSpacing.sm),
            ],
            ?previous,
            if (previous != null) const SizedBox(width: AppSpacing.sm),
            ?secondaryNext,
            if (secondaryNext != null) const SizedBox(width: AppSpacing.sm),
            Expanded(child: primary),
          ],
        ),
      );
    }
    // Editing carries four buttons; when their French labels do not fit one
    // line, the forward ones wrap under each other at the right rather than
    // overflow.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onReset != null) reset,
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: forward,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(description!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        IconButton(
          key: const ValueKey('wizard-close'),
          tooltip: l10n.actionClose,
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
