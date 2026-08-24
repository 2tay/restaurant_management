import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/timeclock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// One employee's attendance, rendered as rows.
///
/// A shared widget taking `List<TimeEntry>` rather than page-only logic, per
/// the employees brief — [EmployeeDetailPage] uses this scoped to one
/// employee. Stage 3's Historique tab builds on the same [TimeEntryRow]
/// rather than duplicating its layout.
class TimeEntryHistoryList extends StatelessWidget {
  const TimeEntryHistoryList({required this.entries, super.key});

  /// Already sorted by the caller — most recent day first, matching every
  /// other history list in the app.
  final List<TimeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          l10n.employeeHistoryEmpty,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [for (final entry in entries) TimeEntryRow(entry: entry)],
    );
  }
}

/// One day's attendance row: date, times, worked duration, status and the
/// late-break marker.
///
/// Shared by [TimeEntryHistoryList] (one employee, scoped, so no
/// [employeeName] and the plain neutral [_StatusPill] — a closed history row
/// for someone whose page you are already on has no urgency to signal, only
/// a fact to state) and the pointage board's Historique tab (all employees,
/// so [employeeName] is set and [useStatusBadge] shows the full
/// [TimeEntryStatusBadge] instead, since that table can include today's
/// still-in-progress entries alongside finished ones).
///
/// [asCard] switches the wrapper from the bordered-row-in-one-card look
/// [TimeEntryHistoryList] uses to a standalone [AppCard] per row, matching
/// how every other filterable history list in the app (e.g. `MovementRow`)
/// renders inside a separated, scrollable list.
class TimeEntryRow extends StatelessWidget {
  const TimeEntryRow({
    required this.entry,
    this.employeeName,
    this.useStatusBadge = false,
    this.asCard = false,
    super.key,
  });

  final TimeEntry entry;
  final String? employeeName;
  final bool useStatusBadge;
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final worked = workedDuration(entry);
    final name = employeeName;

    final content = Row(
      children: [
        if (name != null) ...[
          SizedBox(
            width: 160,
            child: Text(
              name,
              style: theme.textTheme.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        SizedBox(
          width: 100,
          child: Text(
            Formatters.date(entry.date),
            style: theme.textTheme.bodyLarge,
          ),
        ),
        Expanded(
          child: Text(
            _timesLine(l10n, entry),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            worked == null ? '—' : Formatters.duration(worked),
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: useStatusBadge ? 140 : 96,
          child: Align(
            alignment: Alignment.centerLeft,
            child: useStatusBadge
                ? TimeEntryStatusBadge(status: entry.status)
                : _StatusPill(status: entry.status),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: AppSizing.iconLg,
          child: entry.isLate
              ? Tooltip(
                  message: l10n.employeeHistoryLate,
                  child: Icon(
                    LucideIcons.triangleAlert,
                    size: AppSizing.iconSm,
                    color: AppColors.lowStock.foreground,
                  ),
                )
              : null,
        ),
      ],
    );

    if (asCard) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: content,
    );
  }

  String _timesLine(AppLocalizations l10n, TimeEntry entry) {
    final parts = <String>[];
    if (entry.clockInAt != null) {
      parts.add(Formatters.time(entry.clockInAt!));
    }
    if (entry.breakStartAt != null) {
      final end = entry.breakEndAt == null
          ? '…'
          : Formatters.time(entry.breakEndAt!);
      parts.add('${Formatters.time(entry.breakStartAt!)}–$end');
    }
    if (entry.clockOutAt != null) {
      parts.add(Formatters.time(entry.clockOutAt!));
    }
    return parts.join(' · ');
  }
}

/// A plain neutral pill naming the day's status — icon-free by design here,
/// unlike the badge Stage 2 introduces for the live board, because a closed
/// history row has no urgency to signal, only a fact to state.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TimeEntryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        timeEntryStatusLabel(l10n, status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
