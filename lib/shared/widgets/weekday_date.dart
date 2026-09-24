import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

/// `Mar 12/10/2024` for a table's date column, the weekday a size smaller
/// than the date: it helps a manager find their way through a week, but the
/// date is what is actually read.
///
/// One [Text.rich], so the cell still reads (and is found by tests) as the
/// plain string [Formatters.dateShortWeekday] gives.
class WeekdayDate extends StatelessWidget {
  const WeekdayDate(this.value, {super.key});

  final DateTime value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = DefaultTextStyle.of(context).style;
    final size = base.fontSize ?? theme.textTheme.bodyMedium?.fontSize ?? 14;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: Formatters.weekdayShort(value),
            style: TextStyle(fontSize: size - 3),
          ),
          TextSpan(text: ' ${Formatters.date(value)}'),
        ],
      ),
    );
  }
}
