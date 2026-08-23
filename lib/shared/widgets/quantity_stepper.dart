import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';

/// Quantity entry, built for wet hands and no patience.
///
/// The brief asks for minimal typing, and this is where that is won or lost —
/// it is the single most-tapped control in the app. So:
///
/// - The +/- targets are 64dp, well over the 48dp floor
/// - Holding a button repeats, so 40 taps is one long press
/// - The field is still editable, because typing 96 beats tapping 96 times
/// - The step size adapts to the unit: whole numbers for pieces and crates,
///   halves for kilos and litres
class QuantityStepper extends StatefulWidget {
  const QuantityStepper({
    required this.value,
    required this.onChanged,
    this.unitAbbreviation = '',
    this.step,
    this.min = 0,
    this.max = 99999,
    this.allowDecimals = true,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Shown as a suffix — "kg", "bac". Purely a label.
  final String unitAbbreviation;

  /// Defaults to 1, or 0.5 when [allowDecimals] and the value is small enough
  /// that half-units are plausible.
  final double? step;

  final double min;
  final double max;

  /// False for units that cannot be fractional — pieces, crates.
  final bool allowDecimals;

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final TextEditingController _controller = TextEditingController(
    text: Formatters.quantity(widget.value),
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Reformat on blur so a half-typed "12," becomes "12" rather than sitting
    // there looking broken.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _syncControllerToValue();
    });
  }

  @override
  void didUpdateWidget(QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _syncControllerToValue();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncControllerToValue() {
    _controller.text = Formatters.quantity(widget.value);
  }

  double get _step {
    if (widget.step != null) return widget.step!;
    if (!widget.allowDecimals) return 1;
    return widget.value < 10 ? 0.5 : 1;
  }

  void _nudge(double delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    if (next == widget.value) return;

    // Light haptic on every increment: with the tablet on a noisy pass, touch
    // is the only feedback channel that reliably gets through.
    HapticFeedback.selectionClick();
    widget.onChanged(_round(next));
  }

  double _round(double value) {
    if (!widget.allowDecimals) return value.roundToDouble();
    return (value * 100).roundToDouble() / 100;
  }

  void _onFieldChanged(String raw) {
    // Belgian input uses a comma decimal separator; accept either.
    final normalised = raw.replaceAll(',', '.').trim();
    final parsed = double.tryParse(normalised);
    if (parsed == null) return;
    widget.onChanged(_round(parsed.clamp(widget.min, widget.max)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: LucideIcons.minus,
          onPressed: widget.value > widget.min ? () => _nudge(-_step) : null,
          semanticLabel: l10n.a11yDecrease,
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 132,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            style: AppTypography.numeric,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: _onFieldChanged,
            decoration: InputDecoration(
              suffixText: widget.unitAbbreviation.isEmpty
                  ? null
                  : widget.unitAbbreviation,
              suffixStyle: Theme.of(context).textTheme.bodyMedium,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.lg,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _StepperButton(
          icon: LucideIcons.plus,
          onPressed: widget.value < widget.max ? () => _nudge(_step) : null,
          semanticLabel: l10n.a11yIncrease,
        ),
      ],
    );
  }
}

/// An oversized, hold-to-repeat +/- button.
class _StepperButton extends StatefulWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  bool _isHeld = false;

  Future<void> _startRepeating() async {
    setState(() => _isHeld = true);

    // Wait before repeating so a normal tap doesn't fire twice, then accelerate
    // — receiving 40 crates should not take 40 taps or 40 seconds.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    var interval = 120;

    while (_isHeld && mounted && widget.onPressed != null) {
      widget.onPressed!();
      await Future<void>.delayed(Duration(milliseconds: interval));
      interval = (interval * 0.85).round().clamp(35, 120);
    }
  }

  void _stopRepeating() {
    if (_isHeld) setState(() => _isHeld = false);
  }

  @override
  void dispose() {
    _isHeld = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onLongPressStart: enabled ? (_) => _startRepeating() : null,
        onLongPressEnd: enabled ? (_) => _stopRepeating() : null,
        onLongPressCancel: _stopRepeating,
        child: Material(
          color: enabled ? AppColors.surfaceVariant : AppColors.neutral100,
          borderRadius: AppRadius.mdAll,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: AppRadius.mdAll,
            child: Container(
              width: AppSizing.stepperButton,
              height: AppSizing.inputHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: enabled ? AppColors.borderStrong : AppColors.border,
                ),
              ),
              child: Icon(
                widget.icon,
                size: AppSizing.iconLg,
                color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
