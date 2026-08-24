import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/timeclock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/time_entry_history_list.dart' show TimeEntryRow;
import 'employees_list_page.dart' show employeeInitials;

/// A rolling window for the Historique tab's period filter — a page-local
/// equivalent of `stock_history_page.dart`'s `HistoryPeriod`, duplicated
/// rather than imported so this feature does not reach sideways into
/// `stock_movement/`.
enum _HistoryPeriod {
  last7(7),
  last30(30),
  last90(90),
  all(null);

  const _HistoryPeriod(this.days);

  final int? days;
}

/// The pointage board — *Aujourd'hui* / *Historique*.
///
/// Reached via the sidebar's Employés flyout, so — like [EmployeesListPage] —
/// it is a `goSection` destination and carries no back control.
///
/// The two tabs are views of one screen, not two routes, so they switch in
/// place through local state exactly like `order_detail_page.dart`'s
/// Lignes/Réceptions — per the brief's assumption 5.
///
/// *Aujourd'hui*: one card per **active** employee only — archived employees
/// have nothing to punch, per `docs/page_personelle.md` §2. Cards with
/// nothing to do yet (`notClockedIn`) sort first, so someone finding their
/// own card at the start of a shift does not have to scan the whole list.
///
/// *Historique*: the filterable attendance log across every employee and
/// day, built on [MockQueries.timeEntriesForStore] and [TimeEntryRow] —
/// mirrors `stock_history_page.dart`'s filter-pills-plus-list shape rather
/// than a `DataTableWrapper` grid.
class TimeclockBoardPage extends ConsumerStatefulWidget {
  const TimeclockBoardPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<TimeclockBoardPage> createState() => _TimeclockBoardPageState();
}

class _TimeclockBoardPageState extends ConsumerState<TimeclockBoardPage> {
  static const String _tabToday = 'today';
  static const String _tabHistory = 'history';

  String _tab = _tabToday;

  _HistoryPeriod _period = _HistoryPeriod.last30;
  TimeEntryStatus? _status;
  String _employeeQuery = '';

  @override
  Widget build(BuildContext context) {
    // The board is written to directly, so it has to redraw when a card's
    // status changes — including the one currently on screen — and the
    // Historique tab has to pick up the same writes immediately.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.timeclockBoardTitle,
      subtitle: l10n.timeclockBoardSubtitle,
      scrollable: false,
      actions: const [_LiveClock()],
      tabs: SectionTabs(
        currentPath: _tab,
        onSelected: (value) => setState(() => _tab = value),
        tabs: [
          SectionTab(label: l10n.timeclockTabToday, path: _tabToday),
          SectionTab(label: l10n.timeclockTabHistory, path: _tabHistory),
        ],
      ),
      child: _tab == _tabToday ? _buildToday(l10n) : _buildHistory(l10n),
    );
  }

  Widget _buildToday(AppLocalizations l10n) {
    final employees = MockQueries.activeEmployeesForStore(widget.storeId)
      ..sort((a, b) {
        final rankA = _statusRank(MockQueries.timeEntryForToday(a.id));
        final rankB = _statusRank(MockQueries.timeEntryForToday(b.id));
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.fullName.compareTo(b.fullName);
      });

    return employees.isEmpty
        ? EmptyState(
            icon: LucideIcons.idCard,
            title: l10n.timeclockBoardEmpty,
            message: l10n.timeclockBoardEmptyBody,
          )
        : ListView.separated(
            itemCount: employees.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _EmployeeCard(
              employee: employees[index],
              storeId: widget.storeId,
            ),
          );
  }

  Widget _buildHistory(AppLocalizations l10n) {
    final allEntries = MockQueries.timeEntriesForStore(widget.storeId);
    final entries = _filteredHistory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SearchField(
                hint: l10n.employeesSearchHint,
                initialValue: _employeeQuery,
                onChanged: (value) => setState(() => _employeeQuery = value),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _Menu<_HistoryPeriod>(
              label: l10n.movementsFilterPeriod,
              selectedLabel: _periodLabel(l10n, _period),
              entries: {
                for (final period in _HistoryPeriod.values)
                  period: _periodLabel(l10n, period),
              },
              onSelected: (value) => setState(() => _period = value),
            ),
            const SizedBox(width: AppSpacing.sm),
            _Menu<TimeEntryStatus?>(
              label: l10n.ordersFilterStatus,
              selectedLabel: _status == null
                  ? null
                  : timeEntryStatusLabel(l10n, _status!),
              entries: {
                null: l10n.ordersFilterAllStatuses,
                for (final status in TimeEntryStatus.values)
                  status: timeEntryStatusLabel(l10n, status),
              },
              onSelected: (value) => setState(() => _status = value),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.timeclockHistoryCount(entries.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: LucideIcons.history,
                  title: allEntries.isEmpty
                      ? l10n.timeclockHistoryEmpty
                      : l10n.emptyStateNoResultsTitle,
                  message: allEntries.isEmpty
                      ? l10n.timeclockHistoryEmptyBody
                      : l10n.emptyStateNoResultsBody,
                  actionLabel: allEntries.isEmpty
                      ? null
                      : l10n.inventoryClearFilters,
                  onAction: allEntries.isEmpty ? null : _clearHistoryFilters,
                )
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final name =
                        MockQueries.employeeById(entry.employeeId)?.fullName ??
                        '—';
                    return TimeEntryRow(
                      entry: entry,
                      employeeName: name,
                      useStatusBadge: true,
                      asCard: true,
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<TimeEntry> _filteredHistory() => MockQueries.timeEntriesForStore(
    widget.storeId,
    withinDays: _period.days,
    status: _status,
    employeeQuery: _employeeQuery.trim().isEmpty ? null : _employeeQuery,
  );

  void _clearHistoryFilters() {
    setState(() {
      _period = _HistoryPeriod.all;
      _status = null;
      _employeeQuery = '';
    });
  }

  String _periodLabel(AppLocalizations l10n, _HistoryPeriod period) =>
      switch (period) {
        _HistoryPeriod.last7 => l10n.periodLast7Days,
        _HistoryPeriod.last30 => l10n.periodLast30Days,
        _HistoryPeriod.last90 => l10n.periodLast90Days,
        _HistoryPeriod.all => l10n.periodAll,
      };

  /// Not-yet-clocked-in first, finished last — see the class doc.
  static int _statusRank(TimeEntry? entry) {
    switch (entry?.status ?? TimeEntryStatus.notClockedIn) {
      case TimeEntryStatus.notClockedIn:
        return 0;
      case TimeEntryStatus.onShift:
      case TimeEntryStatus.onBreak:
        return 1;
      case TimeEntryStatus.clockedOut:
        return 2;
    }
  }
}

/// A chip-shaped dropdown filter — the same pairing `stock_history_page.dart`
/// uses: [FilterPill] as the [PopupMenuButton]'s `child`, not its menu.
class _Menu<T> extends StatelessWidget {
  const _Menu({
    required this.label,
    required this.selectedLabel,
    required this.entries,
    required this.onSelected,
  });

  final String label;
  final String? selectedLabel;
  final Map<T, String> entries;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (index) => onSelected(entries.keys.elementAt(index)),
      itemBuilder: (context) => [
        for (var i = 0; i < entries.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(entries.values.elementAt(i)),
          ),
      ],
      child: FilterPill(label: label, selectedLabel: selectedLabel),
    );
  }
}

/// Today's date and a ticking clock.
///
/// Isolated in its own [StatefulWidget] with its own [Timer.periodic] so the
/// once-a-second tick redraws only this small header, not the employee list
/// beneath it — that only needs to redraw on [mockDataRevisionProvider]
/// changes, same as every other screen in the app.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Formatters.dateLong(_now),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(Formatters.time(_now), style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.storeId});

  final Employee employee;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = MockQueries.timeEntryForToday(employee.id);
    final status = entry?.status ?? TimeEntryStatus.notClockedIn;

    return AppCard(
      child: Row(
        children: [
          _Avatar(employee: employee),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                TimeEntryStatusBadge(status: status),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _ActionArea(entry: entry, employee: employee, storeId: storeId),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = employee.photoAsset;

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: photo != null
          ? Image.asset(photo, fit: BoxFit.cover, width: 48, height: 48)
          : Text(
              employeeInitials(employee.fullName),
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
    );
  }
}

/// The 4-state button, or a read-only summary once the day is finished.
///
/// Reflects whatever [TimeEntryStatus] today's entry reports rather than
/// tracking its own state — the one-break-per-day rule is enforced by
/// `TimeclockMutations`, and this widget just renders the result. "No break
/// yet" versus "break already taken" is told apart by whether `breakEndAt`
/// is set, per the brief.
class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.entry,
    required this.employee,
    required this.storeId,
  });

  final TimeEntry? entry;
  final Employee employee;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = entry;

    if (current == null) {
      return PrimaryButton(
        label: l10n.timeclockButtonClockIn,
        icon: LucideIcons.logIn,
        onPressed: () {
          final created = TimeclockMutations.clockIn(employee.id, storeId);
          if (created == null) return;
          AppSnackBar.success(
            context,
            l10n.timeclockClockInSuccess(employee.fullName),
          );
        },
      );
    }

    switch (current.status) {
      // Never actually stored on a real entry — see the TimeEntry model doc.
      // Kept only so this switch is exhaustive.
      case TimeEntryStatus.notClockedIn:
        return const SizedBox.shrink();

      case TimeEntryStatus.onShift:
        if (current.breakEndAt == null) {
          return PrimaryButton(
            label: l10n.timeclockButtonStartBreak,
            icon: LucideIcons.coffee,
            onPressed: () {
              final updated = TimeclockMutations.startBreak(current.id);
              if (updated == null) return;
              AppSnackBar.success(
                context,
                l10n.timeclockBreakStartSuccess(employee.fullName),
              );
            },
          );
        }
        return PrimaryButton(
          label: l10n.timeclockButtonClockOut,
          icon: LucideIcons.doorOpen,
          onPressed: () {
            final updated = TimeclockMutations.clockOut(current.id);
            if (updated == null) return;
            AppSnackBar.success(
              context,
              l10n.timeclockClockOutSuccess(employee.fullName),
            );
          },
        );

      case TimeEntryStatus.onBreak:
        return PrimaryButton(
          label: l10n.timeclockButtonEndBreak,
          icon: LucideIcons.logIn,
          onPressed: () {
            final updated = TimeclockMutations.endBreak(current.id);
            if (updated == null) return;
            AppSnackBar.success(
              context,
              l10n.timeclockBreakEndSuccess(employee.fullName),
            );
          },
        );

      case TimeEntryStatus.clockedOut:
        return _ClockedOutSummary(entry: current);
    }
  }
}

/// A finished day's card: no button, just what happened.
class _ClockedOutSummary extends StatelessWidget {
  const _ClockedOutSummary({required this.entry});

  final TimeEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final worked = workedDuration(entry);
    final over = overtime(entry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.isLate) ...[
              Tooltip(
                message: l10n.employeeHistoryLate,
                child: Icon(
                  LucideIcons.triangleAlert,
                  size: AppSizing.iconSm,
                  color: AppColors.lowStock.foreground,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              worked == null
                  ? '—'
                  : l10n.timeclockWorkedDuration(Formatters.duration(worked)),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        if (over != null && over > Duration.zero) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.timeclockOvertime(Formatters.duration(over)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
