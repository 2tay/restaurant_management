import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The app's date picker — Material's calendar, drawn larger with smaller type.
///
/// Material fixes the dialog at 496×346 in landscape (360×568 in portrait) and
/// only grows it with the text scale, which would grow the digits with it. So
/// the whole dialog is scaled up by [_boxScale] instead, and every font inside
/// is shrunk by the same factor: the box gets bigger, the text does not. Where
/// the scaled box would not fit the screen, the scale falls back towards 1.
///
/// Colours and the target font sizes live in `AppTheme.datePickerTheme`.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: const Locale('fr', 'BE'),
    builder: (context, child) {
      final scale = _scaleFor(MediaQuery.sizeOf(context));
      return Theme(
        data: _scaledTheme(Theme.of(context), scale),
        child: Transform.scale(scale: scale, child: child),
      );
    },
  );
}

/// How much bigger than Material's own size the dialog is drawn.
const double _boxScale = 1.2;

/// The generic text the picker takes from the text theme — the month title,
/// the years, the buttons — ends up at this fraction of its usual size.
const double _generalTextFactor = 0.85;

double _scaleFor(Size screen) {
  final landscape = screen.width > screen.height;
  final base = landscape ? const Size(496, 346) : const Size(360, 568);
  const margin = AppSpacing.lg * 2;
  final fit = math.min(
    (screen.width - margin) / base.width,
    (screen.height - margin) / base.height,
  );
  return math.min(_boxScale, fit).clamp(1.0, _boxScale);
}

ThemeData _scaledTheme(ThemeData theme, double scale) {
  TextStyle? shrink(TextStyle? style) => style?.fontSize == null
      ? style
      : style!.copyWith(fontSize: style.fontSize! / scale);

  final picker = theme.datePickerTheme;
  final textTheme = theme.textTheme.apply(
    fontSizeFactor: _generalTextFactor / scale,
  );

  return theme.copyWith(
    textTheme: textTheme,
    datePickerTheme: picker.copyWith(
      headerHelpStyle: shrink(picker.headerHelpStyle),
      headerHeadlineStyle: shrink(picker.headerHeadlineStyle),
      weekdayStyle: shrink(picker.weekdayStyle),
      dayStyle: shrink(picker.dayStyle),
      yearStyle: shrink(picker.yearStyle),
    ),
    textButtonTheme: TextButtonThemeData(
      style: (theme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
    ),
  );
}
