import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../data/providers.dart';
import 'employee_avatar.dart';

/// A recorded name, with the employee's small avatar before it when the record
/// names them by id.
///
/// For the "who did it" line on a record — a receipt, a movement — which keeps
/// the name as it was on the day and, since v6/v7, the employee's id beside it.
/// The name always comes from the record, never from the employee row: someone
/// renamed or gone still reads as they did when they signed it. The id only
/// adds the face. Records from before the id existed show the name alone.
class EmployeeNameTag extends ConsumerWidget {
  const EmployeeNameTag({
    required this.name,
    this.employeeId,
    this.style,
    this.avatarSize = 20,
    super.key,
  });

  final String name;
  final String? employeeId;
  final TextStyle? style;
  final double avatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = employeeId;
    final employee = id == null ? null : ref.watch(employeeProvider(id)).value;

    final text = Text(
      name,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (employee == null) return text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmployeeAvatar(employee: employee, size: avatarSize),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: text),
      ],
    );
  }
}
