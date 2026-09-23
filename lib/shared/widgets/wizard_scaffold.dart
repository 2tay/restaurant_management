import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'form_scaffold.dart';
import 'app_text_field.dart';
import 'primary_button.dart';
import 'wizard_step_indicator.dart';

/// One page of a [WizardScaffold].
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

/// A form split into steps, on top of [FormScaffold] — so the pinned action
/// bar, the dismissive-left / constructive-right order and the unsaved-input
/// guard are exactly the ones every other form has.
///
/// - **Header:** [title], the [description] paragraph under it, and the way
///   back as a link on the right of the title row.
/// - **Body:** the [WizardStepIndicator], then the current step.
/// - **Bar:** Annuler on the left; Précédent, then Suivant — or [submitLabel]
///   on the last step — on the right.
///
/// Controlled: the parent holds [currentStep] and moves it in
/// [onStepChanged], so it can also send the user back to a step (a field
/// refused on save, for instance).
///
/// With [freeNavigation] (editing an existing record) any step is reachable
/// from the indicator once the steps before it are valid, and the submit is on
/// every step — there is nothing to walk through, only something to change.
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    required this.title,
    required this.description,
    required this.back,
    required this.backLinkLabel,
    required this.steps,
    required this.currentStep,
    required this.onStepChanged,
    required this.submitLabel,
    required this.onSubmit,
    this.submitIcon,
    this.isDirty = false,
    this.freeNavigation = false,
    this.maxWidth = 1280,
    super.key,
  }) : assert(steps.length > 1, 'a wizard has at least two steps');

  final String title;
  final String description;

  /// Where Annuler and the header link lead.
  final BackDestination back;
  final String backLinkLabel;

  final List<WizardStep> steps;
  final int currentStep;
  final ValueChanged<int> onStepChanged;

  final String submitLabel;
  final IconData? submitIcon;

  /// Called once every step is valid; null disables the submit.
  final VoidCallback? onSubmit;

  final bool isDirty;
  final bool freeNavigation;
  final double maxWidth;

  bool get _isLast => currentStep == steps.length - 1;

  bool get _allValid => steps.every((s) => s.isValid);

  bool _stepsBeforeValid(int index) =>
      steps.take(index).every((s) => s.isValid);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step = steps[currentStep];

    final canSubmit = onSubmit != null && _allValid;
    final showSubmit = _isLast || freeNavigation;

    final next = SecondaryButton(
      key: const ValueKey('wizard-next'),
      label: l10n.wizardNext,
      icon: LucideIcons.arrowRight,
      tone: SecondaryButtonTone.surface,
      onPressed: step.isValid ? () => onStepChanged(currentStep + 1) : null,
    );

    return FormScaffold(
      title: title,
      subtitle: description,
      // The paragraph explains the screen; on a phone the step indicator says
      // enough, and the form is what the room is for.
      keepSubtitle: false,
      back: back,
      headerBackLinkLabel: backLinkLabel,
      centered: true,
      centerVertically: true,
      inlineActions: true,
      isDirty: isDirty,
      maxWidth: maxWidth,
      forwardActions: [
        if (currentStep > 0)
          SecondaryButton(
            key: const ValueKey('wizard-previous'),
            label: l10n.wizardPrevious,
            icon: LucideIcons.arrowLeft,
            tone: SecondaryButtonTone.surface,
            onPressed: () => onStepChanged(currentStep - 1),
          ),
        // Not last and not free: Suivant *is* the primary action, below.
        if (!_isLast && freeNavigation) next,
      ],
      submitLabel: showSubmit ? submitLabel : l10n.wizardNext,
      submitIcon: showSubmit ? submitIcon : LucideIcons.arrowRight,
      // Suivant moves on; only the final save is the solid commit.
      submitTonal: !showSubmit,
      onSubmit: showSubmit
          ? (canSubmit ? onSubmit : null)
          : next.onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WizardStepIndicator(
            labels: [for (final s in steps) s.label],
            current: currentStep,
            onStepTapped: onStepChanged,
            canJumpTo: (i) => freeNavigation
                ? _stepsBeforeValid(i)
                : i < currentStep,
          ),
          const SizedBox(height: AppSpacing.xxl),
          KeyedSubtree(
            key: ValueKey('wizard-page-$currentStep'),
            // Wizard steps lie on the page background, not in a card, so
            // their fields are the white, borderless variant.
            child: AppTextFieldVariantScope(
              variant: AppTextFieldVariant.plain,
              child: step.child,
            ),
          ),
        ],
      ),
    );
  }
}
