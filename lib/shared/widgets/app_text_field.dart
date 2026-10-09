import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// How an [AppTextField] is drawn.
enum AppTextFieldVariant {
  /// The theme's field: grey fill, hairline border.
  standard,

  /// White and borderless, with a green border only on focus — for
  /// fields laid straight on the page background rather than inside a card
  /// (the wizard forms).
  plain,
}

/// Sets the [AppTextFieldVariant] for every [AppTextField] below it that does
/// not choose one itself — so a whole form (a wizard step) switches style in
/// one place instead of field by field.
class AppTextFieldVariantScope extends InheritedWidget {
  const AppTextFieldVariantScope({
    required this.variant,
    required super.child,
    super.key,
  });

  final AppTextFieldVariant variant;

  static AppTextFieldVariant of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppTextFieldVariantScope>()
          ?.variant ??
      AppTextFieldVariant.standard;

  @override
  bool updateShouldNotify(AppTextFieldVariantScope oldWidget) =>
      variant != oldWidget.variant;
}

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
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.textInputAction,
    this.variant,
    this.readOnly = false,
    this.onTap,
    this.helperMaxLines,
    this.labelHelp,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final String? suffixText;

  /// A control inside the trailing edge of the field.
  ///
  /// Exists so the barcode field can reserve the slot its future scan button
  /// will occupy. Holding the space now means adding the camera later is a
  /// widget swap rather than a reflow of the form around a control that
  /// suddenly appeared.
  final Widget? suffixIcon;

  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  /// Null inherits from the nearest [AppTextFieldVariantScope].
  final AppTextFieldVariant? variant;

  /// Shows the value without letting it be typed over — unlike [enabled]
  /// false, the text keeps its normal colour (a settings block before its
  /// pencil is pressed). Not focusable unless [onTap] is set.
  final bool readOnly;

  /// Called on a tap — with [readOnly], a field that opens a picker.
  final VoidCallback? onTap;

  /// Lines the [helperText] may wrap to. Null keeps it on one line.
  final int? helperMaxLines;

  /// An explanation behind a help icon beside the label, shown on hover (or
  /// a tap on a touch screen) instead of as a helper line under the field.
  final String? labelHelp;

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
    final plain =
        (variant ?? AppTextFieldVariantScope.of(context)) ==
        AppTextFieldVariant.plain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label: label, help: labelHelp),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          canRequestFocus: !readOnly || onTap != null,
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
            // Plain: white on the page's grey, no outline at rest, the brand
            // green only while typing.
            filled: plain ? true : null,
            fillColor: plain ? AppColors.surface : null,
            contentPadding: plain
                ? const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md + AppSpacing.xxs,
                  )
                : null,
            enabledBorder: plain ? _plainBorder(BorderSide.none) : null,
            disabledBorder: plain ? _plainBorder(BorderSide.none) : null,
            focusedBorder: plain
                ? _plainBorder(
                    BorderSide(color: theme.colorScheme.primary, width: 2),
                  )
                : null,
            hintText: hint,
            hintStyle: plain
                ? theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.placeholder,
                  )
                : null,
            helperText: helperText,
            helperMaxLines: helperMaxLines,
            errorText: errorText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            suffixIcon: suffixIcon,
            suffixText: suffixText,
            suffixStyle: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _plainBorder(BorderSide side) =>
      OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: side);
}

/// A field's label above it, with an optional help icon whose tooltip carries
/// the explanation — for settings whose meaning needs a sentence but whose
/// form should not be a wall of helper lines.
class FieldLabel extends StatelessWidget {
  const FieldLabel({required this.label, this.help, super.key});

  final String label;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: Theme.of(context).textTheme.labelMedium);
    if (help == null) return text;

    return Row(
      children: [
        Flexible(child: text),
        const SizedBox(width: AppSpacing.xs),
        Tooltip(
          message: help,
          // A tap too, so a touch screen without hover still reaches it.
          triggerMode: TooltipTriggerMode.tap,
          showDuration: const Duration(seconds: 6),
          waitDuration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(maxWidth: 320),
          child: const Icon(
            LucideIcons.circleQuestionMark,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
