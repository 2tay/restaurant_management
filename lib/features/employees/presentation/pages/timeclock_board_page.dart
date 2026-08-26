import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/timeclock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'employees_list_page.dart' show employeeInitials;

/// The pointage board — today's live status, one card per active employee.
///
/// Reached via the sidebar's "Gestion des employés" flyout, so — like
/// [EmployeesListPage] — it is a `goSection` destination and carries no back
/// control. The filterable attendance log across every employee and day
/// lives on its own page, [TimeclockHistoryPage], rather than behind a tab
/// here.
///
/// One card per **active** employee only — archived employees have nothing
/// to punch, per `docs/page_personelle.md` §2. Cards with nothing to do yet
/// (`notClockedIn`) sort first, so someone finding their own card at the
/// start of a shift does not have to scan the whole list.
class TimeclockBoardPage extends ConsumerStatefulWidget {
  const TimeclockBoardPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<TimeclockBoardPage> createState() => _TimeclockBoardPageState();
}

class _TimeclockBoardPageState extends ConsumerState<TimeclockBoardPage> {
  String _todayQuery = '';

  // `ref` is unsafe to touch inside `dispose()` — Riverpod asserts on it,
  // since the widget may already be unmounted by then. Captured on every
  // build instead: reading a notifier is cheap and does not itself trigger a
  // rebuild, and the captured object stays valid for the call in dispose.
  late FullScreenMode _fullScreenNotifier;

  @override
  void dispose() {
    // Full screen is this page's own toggle, not a global mode — leaving
    // without turning it off would carry a chrome-less shell into whatever
    // screen the user navigates to next. Deferred to a microtask because
    // Riverpod refuses to modify a provider synchronously from inside any
    // widget life-cycle method, dispose included — this runs right after
    // the current build/teardown pass finishes instead.
    final notifier = _fullScreenNotifier;
    Future.microtask(() => notifier.set(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The board is written to directly, so it has to redraw when a card's
    // status changes — including the one currently on screen.
    ref.watch(mockDataRevisionProvider);
    _fullScreenNotifier = ref.read(isFullScreenProvider.notifier);

    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.timeclockBoardTitle,
      subtitle: l10n.timeclockBoardSubtitle,
      scrollable: false,
      actions: const [_LiveClock(), _FullScreenToggleButton()],
      child: _buildToday(l10n),
    );
  }

  Widget _buildToday(AppLocalizations l10n) {
    final all = MockQueries.activeEmployeesForStore(widget.storeId)
      ..sort((a, b) {
        final rankA = _statusRank(MockQueries.timeEntryForToday(a.id));
        final rankB = _statusRank(MockQueries.timeEntryForToday(b.id));
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.fullName.compareTo(b.fullName);
      });
    final employees = _filteredToday(all);

    if (all.isEmpty) {
      return EmptyState(
        icon: LucideIcons.idCard,
        title: l10n.timeclockBoardEmpty,
        message: l10n.timeclockBoardEmptyBody,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchField(
          hint: l10n.employeesSearchHint,
          initialValue: _todayQuery,
          onChanged: (value) => setState(() => _todayQuery = value),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: employees.isEmpty
              ? EmptyState.noResults(
                  l10n,
                  onClearFilters: () => setState(() => _todayQuery = ''),
                )
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: context.gridColumns(max: 4),
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: 300,
                  ),
                  itemCount: employees.length,
                  itemBuilder: (context, index) => _EmployeeCard(
                    employee: employees[index],
                    storeId: widget.storeId,
                  ),
                ),
        ),
      ],
    );
  }

  List<Employee> _filteredToday(List<Employee> employees) {
    final query = _todayQuery.trim().toLowerCase();
    if (query.isEmpty) return employees;
    return employees
        .where(
          (employee) =>
              employee.fullName.toLowerCase().contains(query) ||
              employee.cin.toLowerCase().contains(query),
        )
        .toList();
  }

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

/// Hides the navigation rail and top bar so the board fills the whole
/// window — meant for a tablet mounted on the wall by the clock-in point,
/// where the sidebar is dead space nobody taps. Toggles [isFullScreenProvider],
/// which [AppScaffold] reads to decide whether to draw its chrome at all;
/// the page turns the mode back off in [State.dispose] so it cannot leak
/// into whatever screen is reached next.
class _FullScreenToggleButton extends ConsumerWidget {
  const _FullScreenToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isFullScreen = ref.watch(isFullScreenProvider);

    return IconButton(
      tooltip: isFullScreen
          ? l10n.actionExitFullScreen
          : l10n.actionFullScreen,
      icon: Icon(
        isFullScreen ? LucideIcons.minimize2 : LucideIcons.maximize2,
        size: AppSizing.iconMd,
      ),
      onPressed: () => ref.read(isFullScreenProvider.notifier).toggle(),
    );
  }
}

/// A vertical pointage card: identity, status, the day's timestamp log, and
/// one full-width action button — mirrors the "Pointage RH" board reference
/// design rather than the earlier row layout.
class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.storeId});

  final Employee employee;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final entry = MockQueries.timeEntryForToday(employee.id);
    final status = entry?.status ?? TimeEntryStatus.notClockedIn;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(employee: employee),
              const SizedBox(width: AppSpacing.md),
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
                    Text(
                      l10n.employeeCinLabel(employee.cin),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TimeEntryStatusBadge(status: status),
          const SizedBox(height: AppSpacing.sm),
          if (entry != null) _TimestampLog(entry: entry),
          const Spacer(),
          _ActionArea(entry: entry, employee: employee, storeId: storeId),
        ],
      ),
    );
  }
}

/// The card's timestamp log — one dot-marked line per timestamp the day's
/// entry has recorded so far, oldest first. A day with fewer events (e.g.
/// still on the first shift, no break yet) simply shows fewer lines; the
/// [Spacer] above the action button absorbs the difference so every card in
/// the grid still lines up.
class _TimestampLog extends StatelessWidget {
  const _TimestampLog({required this.entry});

  final TimeEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final rows = <Widget>[];
    void addRow(DateTime? at, String label, Color dotColor) {
      if (at == null) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(_LogLine(time: at, label: label, dotColor: dotColor));
    }

    addRow(entry.clockInAt, l10n.timeclockLogClockIn, AppColors.inStock.solid);
    addRow(
      entry.breakStartAt,
      l10n.timeclockLogBreakStart,
      AppColors.lowStock.solid,
    );
    addRow(
      entry.breakEndAt,
      l10n.timeclockLogBreakEnd,
      AppColors.inStock.solid,
    );
    addRow(
      entry.clockOutAt,
      l10n.timeclockLogClockOut,
      AppColors.textSecondary,
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.time, required this.label, required this.dotColor});

  final DateTime time;
  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(Formatters.time(time), style: theme.textTheme.bodySmall),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
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
      return _TimeclockActionButton(
        label: l10n.timeclockButtonClockIn,
        icon: LucideIcons.circle,
        color: AppColors.inStock.solid,
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
          return _TimeclockActionButton(
            label: l10n.timeclockButtonStartBreak,
            icon: LucideIcons.pause,
            color: AppColors.inStock.solid,
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
        return _TimeclockActionButton(
          label: l10n.timeclockButtonClockOut,
          icon: LucideIcons.circleCheck,
          color: AppColors.steel700,
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
        return _TimeclockActionButton(
          label: l10n.timeclockButtonEndBreak,
          icon: LucideIcons.play,
          color: AppColors.lowStock.solid,
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

/// The full-width, status-coloured button one card offers at a time — never
/// more than one per card, so the "at most one call to action" rule still
/// holds locally even though the grid shows many cards at once. Colours are
/// existing palette tokens, not new ones: green for the two "keep going"
/// actions ([AppColors.inStock]), amber for "on a break" ([AppColors.lowStock]),
/// and the chrome [AppColors.steel700] for the one action that ends the day.
class _TimeclockActionButton extends StatelessWidget {
  const _TimeclockActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: AppSizing.iconSm),
        label: Text(label.toUpperCase()),
      ),
    );
  }
}

/// A finished day's card: a disabled "Terminé" button, plus what happened
/// above it when there is something worth flagging (a late break, overtime).
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (entry.isLate || (over != null && over > Duration.zero)) ...[
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
              if (worked != null)
                Text(
                  l10n.timeclockWorkedDuration(Formatters.duration(worked)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surfaceVariant,
              foregroundColor: AppColors.textSecondary,
              disabledBackgroundColor: AppColors.surfaceVariant,
              disabledForegroundColor: AppColors.textSecondary,
            ),
            onPressed: null,
            icon: const Icon(LucideIcons.circleCheck, size: AppSizing.iconSm),
            label: Text(l10n.timeEntryStatusClockedOut.toUpperCase()),
          ),
        ),
      ],
    );
  }
}
