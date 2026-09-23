import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// Where a wizard is: numbered steps joined by a line, each done (✓), current,
/// or still ahead.
///
/// Below [AppBreakpoints.compact] the row of labels no longer fits, so it
/// collapses to "Étape 2 sur 3 · Rémunération" over a progress bar.
///
/// [onStepTapped] is called for a step the user may jump to — [canJumpTo]
/// decides which; the rest are not tappable.
class WizardStepIndicator extends StatelessWidget {
  const WizardStepIndicator({
    required this.labels,
    required this.current,
    this.onStepTapped,
    this.canJumpTo,
    super.key,
  });

  final List<String> labels;

  /// Zero-based index of the step being shown.
  final int current;

  final ValueChanged<int>? onStepTapped;

  /// Whether step `i` is reachable by tapping it. Defaults to the steps
  /// already passed.
  final bool Function(int index)? canJumpTo;

  bool _reachable(int i) =>
      i != current &&
      onStepTapped != null &&
      (canJumpTo?.call(i) ?? i < current);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth < AppBreakpoints.compact
          ? _compact(context)
          : _full(context),
    );
  }

  Widget _compact(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${l10n.wizardStepOf(current + 1, labels.length)} · ${labels[current]}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.pillAll,
          child: LinearProgressIndicator(
            value: (current + 1) / labels.length,
            minHeight: 6,
            color: AppColors.primary600,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    );
  }

  Widget _full(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final (i, label) in labels.indexed) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: i <= current ? AppColors.primary600 : AppColors.border,
              ),
            ),
          _StepChip(
            key: ValueKey('wizard-step-$i'),
            number: i + 1,
            label: label,
            state: i < current
                ? _StepState.done
                : i == current
                ? _StepState.current
                : _StepState.upcoming,
            onTap: _reachable(i) ? () => onStepTapped!(i) : null,
          ),
        ],
      ],
    );
  }
}

enum _StepState { done, current, upcoming }

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.label,
    required this.state,
    required this.onTap,
    super.key,
  });

  final int number;
  final String label;
  final _StepState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = state != _StepState.upcoming;

    final dot = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (state) {
          _StepState.done => AppColors.primary600,
          _StepState.current => AppColors.primaryContainer,
          _StepState.upcoming => AppColors.surface,
        },
        border: Border.all(
          color: active ? AppColors.primary600 : AppColors.borderStrong,
          width: 2,
        ),
      ),
      child: state == _StepState.done
          ? const Icon(LucideIcons.check, size: AppSizing.iconSm,
              color: Colors.white)
          : Text(
              '$number',
              style: theme.textTheme.labelLarge?.copyWith(
                color: active
                    ? AppColors.onPrimaryContainer
                    : AppColors.textSecondary,
              ),
            ),
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: state == _StepState.current ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      selected: state == _StepState.current,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: AppRadius.pillAll,
              child: content,
            ),
    );
  }
}
