import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A labelled text field.
///
/// The label sits above the field rather than floating inside it. Floating
/// labels save vertical space, which a tablet does not need, and cost legibility
/// at arm's length when the field is filled — the label shrinks to about 12pt,
/// under this app's readable floor.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixText,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.textInputAction,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final String? suffixText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  /// A money field. Accepts a comma decimal separator, because that is what a
  /// Belgian keyboard and a Belgian brain both produce.
  factory AppTextField.currency({
    required String label,
    TextEditingController? controller,
    String? helperText,
    String? errorText,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    Key? key,
  }) {
    return AppTextField(
      key: key,
      label: label,
      controller: controller,
      hint: '0,00',
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      suffixText: '€',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          autofocus: autofocus,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: suffixText == '€' ? AppTypography.numeric : null,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            suffixText: suffixText,
            suffixStyle: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
