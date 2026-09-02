import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/attendance_status.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// The pointage kiosk — today's live board, one card per active employee.
///
/// Reached from the sidebar dropdown, so it is a `goSection` destination with
/// no back control. Built for a tablet mounted by the door: a full-screen
/// toggle hides the rail and top bar, and the mode is turned back off in
/// `dispose` so it cannot leak into the next screen.
class TimeclockBoardPage extends ConsumerStatefulWidget {
  const TimeclockBoardPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<TimeclockBoardPage> createState() => _TimeclockBoardPageState();
}

class _TimeclockBoardPageState extends ConsumerState<TimeclockBoardPage> {
  String _query = '';

  // `ref` is unsafe to touch inside `dispose()` — captured on every build
  // instead. Reading a notifier is cheap and does not trigger a rebuild.
  late FullScreenMode _fullScreen;

  @override
  void dispose() {
    final notifier = _fullScreen;
    Future.microtask(() => notifier.set(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _fullScreen = ref.read(isFullScreenProvider.notifier);

    final l10n = AppLocalizations.of(context);
    final data = asyncAll3(
      ref.watch(activeEmployeesProvider(widget.storeId)),
      ref.watch(attendanceBoardProvider(widget.storeId)),
      ref.watch(storeSettingsProvider(widget.storeId)),
      (employees, board, settings) =>
          (employees: employees, board: board, settings: settings),
    );

    return ShellPage(
      title: l10n.timeclockBoardTitle,
      subtitle: l10n.timeclockBoardSubtitle,
      actions: const [_LiveClock(), _FullScreenToggleButton()],
      child: AsyncContent<
        ({
          List<Employee> employees,
          Map<String, Attendance> board,
          StoreSettings settings,
        })
      >(
        value: data,
        skeleton: const SkeletonGrid(),
        onRetry: () {
          ref.invalidate(activeEmployeesProvider(widget.storeId));
          ref.invalidate(attendanceBoardProvider(widget.storeId));
          ref.invalidate(storeSettingsProvider(widget.storeId));
        },
        builder: (context, data) =>
            _buildBoard(l10n, data.employees, data.board, data.settings),
      ),
    );
  }

  Widget _buildBoard(
    AppLocalizations l10n,
    List<Employee> employees,
    Map<String, Attendance> board,
    StoreSettings settings,
  ) {
    final all = [...employees]
      ..sort((a, b) {
        final rankA = _rank(board[a.id]);
        final rankB = _rank(board[b.id]);
        if (rankA != rankB) return rankA.compareTo(rankB);
        return employeeDisplayName(a).compareTo(employeeDisplayName(b));
      });

    if (all.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 360),
        child: EmptyState(
          icon: LucideIcons.idCard,
          title: l10n.timeclockBoardEmpty,
          message: l10n.timeclockBoardEmptyBody,
        ),
      );
    }

    final query = _query.trim().toLowerCase();
    final shown = query.isEmpty
        ? all
        : all
              .where(
                (e) =>
                    employeeDisplayName(e).toLowerCase().contains(query) ||
                    e.cin.toLowerCase().contains(query),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchField(
          hint: l10n.employeesSearchHint,
          initialValue: _query,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.md),
        if (shown.isEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: EmptyState.noResults(
              l10n,
              onClearFilters: () => setState(() => _query = ''),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.gridColumns(max: 4),
              crossAxisSpacing: AppSpacing.lg,
              mainAxisSpacing: AppSpacing.lg,
              mainAxisExtent: 320,
            ),
            itemCount: shown.length,
            itemBuilder: (context, index) => _EmployeeCard(
              employee: shown[index],
              entry: board[shown[index].id],
              settings: settings,
              storeId: widget.storeId,
            ),
          ),
      ],
    );
  }

  /// Not-yet-clocked-in first, finished last.
  static int _rank(Attendance? entry) =>
      switch (entry?.status ?? AttendanceStatus.notClockedIn) {
        AttendanceStatus.notClockedIn => 0,
        AttendanceStatus.working || AttendanceStatus.onBreak => 1,
        AttendanceStatus.done => 2,
      };
}

/// Today's date and a ticking clock, isolated so the once-a-second tick
/// redraws only this header, not the employee grid.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
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

class _FullScreenToggleButton extends ConsumerWidget {
  const _FullScreenToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isFull = ref.watch(isFullScreenProvider);

    return IconButton(
      tooltip: isFull ? l10n.actionExitFullScreen : l10n.actionFullScreen,
      icon: Icon(
        isFull ? LucideIcons.minimize2 : LucideIcons.maximize2,
        size: AppSizing.iconMd,
      ),
      onPressed: () => ref.read(isFullScreenProvider.notifier).toggle(),
    );
  }
}

/// A vertical pointage card: identity, status, the day's timestamp log, and
/// the action area.
class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.entry,
    required this.settings,
    required this.storeId,
  });

  final Employee employee;
  final Attendance? entry;
  final StoreSettings settings;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final status = entry?.status ?? AttendanceStatus.notClockedIn;
    final lateBreak =
        entry != null && hasLateBreak(entry!, settings.maxBreakMinutes);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeAvatar(employee: employee),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeDisplayName(employee),
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      employeeRoleLabel(l10n, employee.role),
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
          Row(
            children: [
              AttendanceStatusBadge(status: status),
              if (lateBreak) ...[
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: l10n.attendanceBreakOverrun,
                  child: Icon(
                    LucideIcons.coffee,
                    size: AppSizing.iconSm,
                    color: AppColors.lowStock.foreground,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (entry != null)
            _TimestampLog(
              entry: entry!,
              maxBreakMinutes: settings.maxBreakMinutes,
            ),
          const Spacer(),
          _ActionArea(
            entry: entry,
            employee: employee,
            settings: settings,
            storeId: storeId,
          ),
        ],
      ),
    );
  }
}

/// The day's events laid out left to right — Arrivée · Pause · Reprise ·
/// Pause · … · Départ — wrapping to the next line only when the card runs out
/// of width. Each chip is a coloured dot, a time and a short label. An
/// over-allowance break turns its `Reprise` chip amber.
class _TimestampLog extends StatelessWidget {
  const _TimestampLog({required this.entry, required this.maxBreakMinutes});

  final Attendance entry;
  final int maxBreakMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chips = <Widget>[];

    void add(DateTime at, String label, Color color) {
      chips.add(_LogChip(time: at, label: label, color: color));
    }

    if (entry.clockInAt != null) {
      add(entry.clockInAt!, l10n.timeclockLogArrival, AppColors.inStock.solid);
    }
    for (final pause in entry.pauses) {
      add(pause.startAt, l10n.timeclockLogBreak, AppColors.lowStock.solid);
      if (pause.endAt != null) {
        final over = breakOverrun(pause, maxBreakMinutes) > Duration.zero;
        add(
          pause.endAt!,
          l10n.timeclockLogResume,
          over ? AppColors.lowStock.solid : AppColors.inStock.solid,
        );
      }
    }
    if (entry.clockOutAt != null) {
      add(
        entry.clockOutAt!,
        l10n.timeclockLogDeparture,
        AppColors.textSecondary,
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: chips,
    );
  }
}

class _LogChip extends StatelessWidget {
  const _LogChip({
    required this.time,
    required this.label,
    required this.color,
  });

  final DateTime time;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          Formatters.time(time),
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
        const SizedBox(width: 2),
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

/// The buttons, or a read-only summary once the day is finished.
class _ActionArea extends ConsumerWidget {
  const _ActionArea({
    required this.entry,
    required this.employee,
    required this.settings,
    required this.storeId,
  });

  final Attendance? entry;
  final Employee employee;
  final StoreSettings settings;
  final String storeId;

  /// Every board action is attributed to a person, so each one asks for that
  /// employee's CIN first — the dialog owns the wrong-attempt / lockout loop.
  /// Only on a confirmed CIN does the pointage write run.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    String actionLabel,
    Future<Attendance?> Function() action,
    String Function(String name) message,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await IdentityPromptDialog.show(
      context,
      title: l10n.identityPromptTitle,
      subtitle: l10n.identityPromptPointageSubtitle(
        actionLabel,
        employeeDisplayName(employee),
      ),
      verify: (cin) =>
          ref.read(credentialRepositoryProvider).verifyCin(cin, employee.id),
    );
    if (!ok || !context.mounted) return;

    final result = await action();
    if (!context.mounted || result == null) return;
    AppSnackBar.success(context, message(employeeDisplayName(employee)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = entry;
    final repo = ref.read(attendanceRepositoryProvider);

    if (current == null) {
      return _BigButton(
        label: l10n.timeclockClockIn,
        icon: LucideIcons.circle,
        color: AppColors.inStock.solid,
        onPressed: () => _run(
          context,
          ref,
          l10n.timeclockClockIn,
          () => repo.clockIn(employee.id, storeId),
          l10n.timeclockClockInDone,
        ),
      );
    }

    switch (current.status) {
      case AttendanceStatus.notClockedIn:
        return const SizedBox.shrink();

      case AttendanceStatus.working:
        return Column(
          children: [
            _BigButton(
              label: l10n.timeclockStartPause,
              icon: LucideIcons.pause,
              color: AppColors.lowStock.solid,
              onPressed: () => _run(
                context,
                ref,
                l10n.timeclockStartPause,
                () => repo.startPause(current.id),
                l10n.timeclockPauseStartDone,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: () => _run(
                context,
                ref,
                l10n.timeclockClockOut,
                () => repo.clockOut(current.id),
                l10n.timeclockClockOutDone,
              ),
              icon: const Icon(LucideIcons.circleCheck, size: AppSizing.iconSm),
              label: Text(l10n.timeclockClockOut),
            ),
          ],
        );

      case AttendanceStatus.onBreak:
        return _BigButton(
          label: l10n.timeclockEndPause,
          icon: LucideIcons.play,
          color: AppColors.inStock.solid,
          onPressed: () => _run(
            context,
            ref,
            l10n.timeclockEndPause,
            () => repo.endPause(current.id),
            l10n.timeclockPauseEndDone,
          ),
        );

      case AttendanceStatus.done:
        return _DoneSummary(
          entry: current,
          employee: employee,
          settings: settings,
        );
    }
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
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

class _DoneSummary extends StatelessWidget {
  const _DoneSummary({
    required this.entry,
    required this.employee,
    required this.settings,
  });

  final Attendance entry;
  final Employee employee;
  final StoreSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final schedule = resolvedSchedule(
      employee,
      storeOpenMinutes: settings.openMinutes,
      storeCloseMinutes: settings.closeMinutes,
    );
    final worked = workedDuration(entry);
    final over = overtimeBy(entry, schedule.endMinutes) ?? Duration.zero;
    final late = isLate(entry, schedule.startMinutes);
    final lateBreak = hasLateBreak(entry, settings.maxBreakMinutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (worked != null)
          Text(
            l10n.timeclockWorked(Formatters.duration(worked)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        if (over > Duration.zero || late) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (late) ...[
                Icon(
                  LucideIcons.triangleAlert,
                  size: AppSizing.iconSm,
                  color: AppColors.lowStock.foreground,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              if (over > Duration.zero)
                Text(
                  l10n.timeclockOvertimeMark(Formatters.duration(over)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              if (late && over <= Duration.zero)
                Text(
                  l10n.attendanceLate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
        if (lateBreak) ...[
          const SizedBox(height: 2),
          Text(
            l10n.attendanceBreakOverrun,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.lowStock.foreground,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
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
            label: Text(l10n.attendanceStatusDone.toUpperCase()),
          ),
        ),
      ],
    );
  }
}
