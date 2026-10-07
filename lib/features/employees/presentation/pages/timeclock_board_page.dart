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
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart' show BoardDay;
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/close_business_day_dialog.dart';

/// Identity, status and the buttons — the day's timestamps live in the
/// drawer behind "Voir détails", not on the card.
const double _cardHeight = 348;

/// The pointage kiosk — the journée de service's live board, one card per
/// active employee. Past midnight it stays on the journée still open; once
/// today's journée is closed, every Pointer is disabled until tomorrow.
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
  /// Filters the board to one card when set. Cleared (null) shows everyone.
  Employee? _selected;

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
    final data = asyncAll4(
      ref.watch(activeEmployeesProvider(widget.storeId)),
      ref.watch(attendanceBoardProvider(widget.storeId)),
      ref.watch(storeSettingsProvider(widget.storeId)),
      ref.watch(boardDayProvider(widget.storeId)),
      (employees, board, settings, day) => (
        employees: employees,
        board: board,
        settings: settings,
        day: day,
      ),
    );

    // On a wide screen, one line at the title's right: date | time | full
    // screen. Below 840dp the title keeps full screen at its line's end, and
    // date and time go right under it, a size smaller.
    final small = context.isSmallScreen;
    final board = AsyncContent<
      ({
        List<Employee> employees,
        Map<String, Attendance> board,
        StoreSettings settings,
        BoardDay day,
      })
    >(
      value: data,
      skeleton: const SkeletonGrid(),
      onRetry: () {
        ref.invalidate(activeEmployeesProvider(widget.storeId));
        ref.invalidate(attendanceBoardProvider(widget.storeId));
        ref.invalidate(storeSettingsProvider(widget.storeId));
        ref.invalidate(boardDayProvider(widget.storeId));
      },
      builder: (context, data) => _buildBoard(
        l10n,
        data.employees,
        data.board,
        data.settings,
        data.day,
      ),
    );

    return ShellPage(
      title: l10n.timeclockBoardTitle,
      subtitle: l10n.timeclockBoardSubtitle,
      actions: small
          ? const []
          : const [LiveDateTime(), PipeSeparator(), _FullScreenToggleButton()],
      titleTrailing: small ? const _FullScreenToggleButton() : null,
      titleBelow: small ? const LiveDateTime(small: true) : null,
      child: board,
    );
  }

  Widget _buildBoard(
    AppLocalizations l10n,
    List<Employee> employees,
    Map<String, Attendance> board,
    StoreSettings settings,
    BoardDay day,
  ) {
    final businessDay = day.businessDay;
    if (businessDay == null) {
      // No journée yet: at night Pointer waits for the auto-open hour (or a
      // manager's "Ouvrir la journée"), and unlocks by itself when it comes.
      final opensAt = businessDayAutoOpenAt(
        day.date,
        settings.businessDayAutoOpenMinutes,
      );
      return _Deadline(
        at: opensAt,
        now: ref.read(attendanceClockProvider),
        builder: (context, passed) => _buildCards(
          l10n,
          employees,
          board,
          settings,
          lock: passed ? null : _PointerLock.notOpenYet,
          notice: passed
              ? null
              : _NoBusinessDayNotice(
                  date: day.date,
                  opensAt: opensAt,
                  storeId: widget.storeId,
                ),
        ),
      );
    }
    return _buildCards(
      l10n,
      employees,
      board,
      settings,
      lock: businessDay.closedAt == null ? null : _PointerLock.dayClosed,
      notice: _BusinessDayNotice(
        businessDay: businessDay,
        storeId: widget.storeId,
      ),
    );
  }

  Widget _buildCards(
    AppLocalizations l10n,
    List<Employee> employees,
    Map<String, Attendance> board,
    StoreSettings settings, {
    required _PointerLock? lock,
    required Widget? notice,
  }) {
    // The owner does not clock in — the board shows only the staff who do.
    // Managers first, then by where each one stands, then by name.
    final all = employees.where((e) => e.role != EmployeeRole.owner).toList()
      ..sort((a, b) {
        final managerA = a.role == EmployeeRole.manager ? 0 : 1;
        final managerB = b.role == EmployeeRole.manager ? 0 : 1;
        if (managerA != managerB) return managerA.compareTo(managerB);
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

    // The selector still resolves against the live roster — an employee
    // archived while their card was pinned falls back to the whole board.
    final pinned = _selected == null
        ? null
        : all.where((e) => e.id == _selected!.id).firstOrNull;
    final shown = pinned == null ? all : [pinned];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notice != null) ...[notice, const SizedBox(height: AppSpacing.lg)],
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: EmployeeSelector(
            employees: all,
            value: pinned,
            onChanged: (e) => setState(() => _selected = e),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (pinned != null)
          // One card pinned — a lone card in a four-up grid reads as an error.
          // Full width on a phone, where 360dp is wider than the content.
          SizedBox(
            width: context.isPhone ? double.infinity : 360,
            height: _cardHeight,
            child: _EmployeeCard(
              employee: pinned,
              entry: board[pinned.id],
              settings: settings,
              storeId: widget.storeId,
              lock: lock,
            ),
          )
        else
          ResponsiveCardGrid(
            minCardWidth: 260,
            itemHeight: _cardHeight,
            children: [
              for (final employee in shown)
                _EmployeeCard(
                  employee: employee,
                  entry: board[employee.id],
                  settings: settings,
                  storeId: widget.storeId,
                  lock: lock,
                ),
            ],
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

/// The journée de service the board is on: open (with its date, which stays
/// yesterday's past midnight, and "Fermer la journée"), or closed until
/// tomorrow.
class _BusinessDayNotice extends ConsumerWidget {
  const _BusinessDayNotice({required this.businessDay, required this.storeId});

  final BusinessDay businessDay;
  final String storeId;

  /// The exits for whoever is still in, then the signed-in user's PIN, then
  /// the close — all or nothing (`BusinessDayRepository.close`).
  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final actor = ref.read(currentEmployeeProvider);
    if (actor == null) return;
    final date = _lowerFirst(Formatters.dateLongWeekday(businessDay.date));

    final board = ref.read(attendanceBoardProvider(storeId)).value ?? const {};
    final openShifts = [
      for (final entry in board.values)
        if (entry.status == AttendanceStatus.working ||
            entry.status == AttendanceStatus.onBreak)
          entry,
    ];
    // The whole roster, archived included: an archived employee's open shift
    // still has to be ended before the journée can close. Watched by [build],
    // so it is loaded by the time the button is tapped.
    final roster = ref.read(employeesProvider(storeId)).value ?? const [];

    final exits = await CloseBusinessDayDialog.show(
      context,
      businessDay: businessDay,
      openShifts: openShifts,
      employees: {for (final e in roster) e.id: e},
      now: ref.read(attendanceClockProvider)(),
    );
    if (exits == null || !context.mounted) return;

    final ok = await IdentityPromptDialog.show(
      context,
      title: l10n.identityPromptTitle,
      subtitle: l10n.identityPromptCloseDaySubtitle(date),
      verify: (pin) =>
          ref.read(credentialRepositoryProvider).verifyPin(pin, actor.id),
    );
    if (!ok || !context.mounted) return;

    final closed = await ref
        .read(businessDayRepositoryProvider)
        .close(businessDay.id, closedByEmployeeId: actor.id, exits: exits);
    if (!context.mounted) return;
    if (closed == null) {
      AppSnackBar.error(context, l10n.timeclockCloseDayFailed);
      return;
    }
    AppSnackBar.success(context, l10n.timeclockCloseDayDone(date));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final date = _lowerFirst(Formatters.dateLongWeekday(businessDay.date));
    final closedAt = businessDay.closedAt;
    if (closedAt == null) ref.watch(employeesProvider(storeId));
    // A phone or a small tablet: the short line and the lock alone at the
    // strip's right end. Wider: the journée's date and the labelled button.
    final small = context.isSmallScreen;

    if (closedAt == null) {
      // Turns amber on its own once the journée has been open too long — a
      // forgotten close, which would leave tomorrow's punches on it.
      return _Deadline(
        at: businessDayAlertAt(businessDay),
        now: ref.watch(attendanceClockProvider),
        builder: (context, overdue) => NoticeBanner(
          key: const ValueKey('timeclock-business-day-open'),
          icon: overdue ? LucideIcons.triangleAlert : LucideIcons.calendarClock,
          title: small
              ? l10n.timeclockBusinessDayOpenShort(
                  Formatters.time(businessDay.openedAt),
                )
              : l10n.timeclockBusinessDayOpen(
                  date,
                  Formatters.time(businessDay.openedAt),
                ),
          message: overdue
              ? l10n.timeclockBusinessDayOverdue(
                  AttendanceRules.businessDayAlertAfter.inHours,
                )
              : null,
          colors: overdue ? AppColors.lowStock : null,
          // The lock alone, « Fermer la journée » on hover (and the screen
          // reader's name for it).
          trailing: !small
              ? null
              : IconButton.outlined(
                  key: const ValueKey('timeclock-close-day'),
                  tooltip: l10n.timeclockCloseDay,
                  onPressed: () => _close(context, ref),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: overdue
                        ? AppColors.lowStock.foreground
                        : AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderStrong),
                  ),
                  icon: const Icon(LucideIcons.lock, size: AppSizing.iconSm),
                ),
          action: small
              ? null
              : OutlinedButton.icon(
                  key: const ValueKey('timeclock-close-day'),
                  onPressed: () => _close(context, ref),
                  icon: const Icon(LucideIcons.lock, size: AppSizing.iconSm),
                  label: Text(l10n.timeclockCloseDay),
                ),
        ),
      );
    }
    return NoticeBanner(
      key: const ValueKey('timeclock-business-day-closed'),
      icon: LucideIcons.lock,
      title: l10n.timeclockBusinessDayClosed(date, Formatters.time(closedAt)),
      message: l10n.timeclockBusinessDayClosedBody,
      // The tint of the hourly rate on a Personnel card: a closed journée is
      // the normal end of the day, not a warning.
      colors: AppColors.brandTint,
    );
  }
}

/// At night with no journée open: why Pointer waits, and "Ouvrir la
/// journée" for a real night need — opened on purpose, by the signed-in user.
class _NoBusinessDayNotice extends ConsumerWidget {
  const _NoBusinessDayNotice({
    required this.date,
    required this.opensAt,
    required this.storeId,
  });

  final DateTime date;

  /// When the first Pointer opens the journée by itself (store setting).
  final DateTime opensAt;
  final String storeId;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final actor = ref.read(currentEmployeeProvider);
    if (actor == null) return;
    final label = _lowerFirst(Formatters.dateLongWeekday(date));

    final ok = await IdentityPromptDialog.show(
      context,
      title: l10n.identityPromptTitle,
      subtitle: l10n.identityPromptOpenDaySubtitle(label),
      verify: (pin) =>
          ref.read(credentialRepositoryProvider).verifyPin(pin, actor.id),
    );
    if (!ok || !context.mounted) return;

    final opened = await ref
        .read(businessDayRepositoryProvider)
        .open(storeId, openedByEmployeeId: actor.id);
    if (!context.mounted) return;
    if (opened == null) {
      AppSnackBar.error(context, l10n.timeclockOpenDayFailed);
      return;
    }
    AppSnackBar.success(context, l10n.timeclockOpenDayDone(label));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return NoticeBanner(
      key: const ValueKey('timeclock-business-day-none'),
      icon: LucideIcons.moon,
      title: l10n.timeclockNoBusinessDay,
      message: l10n.timeclockNoBusinessDayBody(Formatters.time(opensAt)),
      action: OutlinedButton.icon(
        key: const ValueKey('timeclock-open-day'),
        onPressed: () => _open(context, ref),
        icon: const Icon(LucideIcons.lockOpen, size: AppSizing.iconSm),
        label: Text(l10n.timeclockOpenDay),
      ),
    );
  }
}

/// Builds with whether [at] has passed, and rebuilds by itself the moment it
/// does — one timer, not a per-second tick.
class _Deadline extends StatefulWidget {
  const _Deadline({required this.at, required this.now, required this.builder});

  final DateTime at;
  final DateTime Function() now;
  final Widget Function(BuildContext context, bool passed) builder;

  @override
  State<_Deadline> createState() => _DeadlineState();
}

class _DeadlineState extends State<_Deadline> {
  Timer? _timer;

  bool get _passed => !widget.now().isBefore(widget.at);

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_passed) return;
    _timer = Timer(widget.at.difference(widget.now()), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_Deadline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.at != widget.at) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _passed);
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

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

/// A vertical pointage card: identity, status and the action area, with
/// "Voir détails" at the top right for the day's timestamps.
class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.entry,
    required this.settings,
    required this.storeId,
    required this.lock,
  });

  final Employee employee;
  final Attendance? entry;
  final StoreSettings settings;
  final String storeId;

  /// Why Pointer is unavailable, if it is.
  final _PointerLock? lock;

  void _openDetail(BuildContext context) {
    // Bare: the day detail — date and live time included — is the heading.
    DetailDrawer.show(
      context,
      children: [_BoardDetail(storeId: storeId, employeeId: employee.id)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final status = entry?.status ?? AttendanceStatus.notClockedIn;

    return AppCard(
      // A manager's card is outlined in the brand green — the colour of the
      // « Journée fermée » notice and the hourly rate on Personnel.
      borderColor: employee.role == EmployeeRole.manager
          ? AppColors.brandTint.solid
          : null,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.md),
              EmployeeAvatar(employee: employee, size: 56),
              const SizedBox(height: AppSpacing.sm),
              Text(
                employeeDisplayName(employee),
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                employeeRoleLabel(l10n, employee.role),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              AttendanceStatusBadge(status: status),
              const Spacer(),
              const SizedBox(height: AppSpacing.md),
              _ActionArea(
                entry: entry,
                employee: employee,
                settings: settings,
                storeId: storeId,
                lock: lock,
              ),
            ],
          ),
          Positioned(
            top: -AppSpacing.sm,
            right: -AppSpacing.sm,
            child: TextButton.icon(
              key: ValueKey('timeclock-detail-${employee.id}'),
              onPressed: () => _openDetail(context),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.labelMedium,
              ),
              icon: const Icon(LucideIcons.eye, size: AppSizing.iconSm),
              label: Text(l10n.timeclockViewDetail),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drawer behind "Voir détails" — the same day detail as the history's
/// ([AttendanceDayDetail]), with the live time beside the date. Before the
/// first punch of the day: the employee, centred, asked to start their day,
/// with the card's own `Pointer` (PIN first).
///
/// Watches the board itself rather than taking a snapshot, so a punch made
/// while the drawer is open shows up in it. No PIN: this is the shared kiosk,
/// and the PIN is what confirms an action here.
class _BoardDetail extends ConsumerWidget {
  const _BoardDetail({required this.storeId, required this.employeeId});

  final String storeId;
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref
        .watch(activeEmployeesProvider(storeId))
        .value
        ?.where((e) => e.id == employeeId)
        .firstOrNull;
    final entry = ref.watch(attendanceBoardProvider(storeId)).value?[employeeId];
    final settings = ref.watch(storeSettingsProvider(storeId)).value;
    final day = ref.watch(boardDayProvider(storeId)).value;
    // The whole roster, archived included, to name whoever entered an exit.
    final roster = ref.watch(employeesProvider(storeId)).value ?? const [];
    if (employee == null || settings == null || day == null) {
      return const SizedBox.shrink();
    }

    if (entry == null || entry.sessions.isEmpty) {
      return _StartDayPrompt(
        employee: employee,
        settings: settings,
        storeId: storeId,
        date: day.date,
        lock: _pointerLock(
          day,
          ref.read(attendanceClockProvider)(),
          settings.businessDayAutoOpenMinutes,
        ),
      );
    }

    return AttendanceDayDetail(
      entry: entry,
      employee: employee,
      showPin: false,
      maxBreakMinutes: resolvedMaxBreakMinutes(
        entry,
        fallback: settings.maxBreakMinutes,
      ),
      dateLine: AttendanceDayDate(date: entry.date, trailing: const LiveTime()),
      exitAuthors: {for (final e in roster) e.id: employeeDisplayName(e)},
      openBusinessDay: day.businessDay?.closedAt == null
          ? day.businessDay?.date
          : null,
    );
  }
}

/// Not clocked in yet: avatar, name, a line inviting them to start the day
/// (dated), and `Pointer` — centred in the drawer.
class _StartDayPrompt extends StatelessWidget {
  const _StartDayPrompt({
    required this.employee,
    required this.settings,
    required this.storeId,
    required this.date,
    required this.lock,
  });

  final Employee employee;
  final StoreSettings settings;
  final String storeId;

  /// The board's day — the open journée's, not the clock's.
  final DateTime date;
  final _PointerLock? lock;

  /// The bare drawer's close bar and bottom padding — what the body's
  /// height leaves for this block to centre in.
  static const double _drawerChrome = 88;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final dayLower = _lowerFirst(Formatters.dateLongWeekday(date));

    return ConstrainedBox(
      key: const ValueKey('timeclock-start-day'),
      constraints: BoxConstraints(
        minHeight: media.size.height - media.padding.vertical - _drawerChrome,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmployeeAvatar(employee: employee, size: 72),
            const SizedBox(height: AppSpacing.md),
            Text(
              employeeDisplayName(employee),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.timeclockStartDayPrompt(dayLower),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: _ActionArea(
                entry: null,
                employee: employee,
                settings: settings,
                storeId: storeId,
                lock: lock,
              ),
            ),
          ],
        ),
      ),
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
    required this.lock,
  });

  final Attendance? entry;
  final Employee employee;
  final StoreSettings settings;
  final String storeId;

  /// Set when `Pointer` is unavailable — it gives way to a disabled button
  /// saying why. Nobody is in service on a closed journée (closing refuses
  /// until they are out) nor before one opens, so the other buttons never
  /// meet it.
  final _PointerLock? lock;

  /// Every board action is attributed to a person, so each one asks for that
  /// employee's PIN first — the dialog asks again after a wrong one, with no
  /// limit and no lockout.
  /// Only on a confirmed PIN does the pointage write run.
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
      verify: (pin) =>
          ref.read(credentialRepositoryProvider).verifyPin(pin, employee.id),
    );
    if (!ok || !context.mounted) return;

    final result = await action();
    if (!context.mounted) return;
    if (result == null) {
      // Refused by the database — the card was stale, or the journée closed
      // in between. Said aloud rather than leaving the tap looking dead.
      AppSnackBar.error(context, l10n.timeclockActionRefused);
      return;
    }
    AppSnackBar.success(context, message(employeeDisplayName(employee)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = entry;
    final repo = ref.read(attendanceRepositoryProvider);

    if (current == null) {
      if (lock != null) return _PointerLockedButton(lock: lock!);
      return _BigButton(
        label: l10n.timeclockClockIn,
        icon: LucideIcons.circle,
        outlined: true,
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
              color: AppColors.primary600,
              onPressed: () => _run(
                context,
                ref,
                l10n.timeclockStartPause,
                () => repo.startPause(current.id),
                l10n.timeclockPauseStartDone,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _BigButton(
              label: l10n.timeclockClockOut,
              icon: LucideIcons.circleCheck,
              color: AppColors.surfaceVariant,
              foreground: AppColors.textPrimary,
              onPressed: () => _run(
                context,
                ref,
                l10n.timeclockClockOut,
                () => repo.clockOut(current.id),
                l10n.timeclockClockOutDone,
              ),
            ),
          ],
        );

      case AttendanceStatus.onBreak:
        return _BigButton(
          label: l10n.timeclockEndPause,
          icon: LucideIcons.play,
          color: AppColors.primary600,
          onPressed: () => _run(
            context,
            ref,
            l10n.timeclockEndPause,
            () => repo.endPause(current.id),
            l10n.timeclockPauseEndDone,
          ),
        );

      case AttendanceStatus.done:
        // The day's cycle is closed, but not the day itself — `Pointer`
        // starts another one, for the employee who steps out and comes back.
        return Column(
          children: [
            const _DoneSummary(),
            const SizedBox(height: AppSpacing.xs),
            if (lock != null)
              _PointerLockedButton(lock: lock!)
            else
              _BigButton(
                label: l10n.timeclockClockIn,
                icon: LucideIcons.circle,
                outlined: true,
                onPressed: () => _run(
                  context,
                  ref,
                  l10n.timeclockClockIn,
                  () => repo.clockIn(employee.id, storeId),
                  l10n.timeclockClockInDone,
                ),
              ),
          ],
        );
    }
  }
}

/// A full-width pointage action. Three shapes:
///
/// - **filled** (default) — a coloured call to action. The board's one accent
///   per card: `Pause` / `Reprendre` in the primary teal.
/// - **neutral** (`color` = a surface tint, [foreground] set) — `Fin de
///   journée`, and the disabled `Terminé` summary; the same grey the
///   completed-work area uses.
/// - **outlined** — `Pointer`: an action with no colour weight, so the first
///   thing a not-yet-clocked-in card asks does not shout.
class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.foreground,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Fill colour when not [outlined]. Null → the neutral surface tint.
  final Color? color;

  /// Text / icon colour. Null → white on a fill, primary text otherwise.
  final Color? foreground;

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = Text(label.toUpperCase());
    final iconWidget = Icon(icon, size: AppSizing.iconSm);

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground ?? AppColors.textPrimary,
            side: const BorderSide(color: AppColors.borderStrong),
          ),
          onPressed: onPressed,
          icon: iconWidget,
          label: child,
        ),
      );
    }

    final fill = color ?? AppColors.surfaceVariant;
    final fg = foreground ?? (color == null ? AppColors.textSecondary : AppColors.white);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: fg,
          disabledBackgroundColor: fill,
          disabledForegroundColor: fg,
        ),
        onPressed: onPressed,
        icon: iconWidget,
        label: child,
      ),
    );
  }
}

/// Why `Pointer` is unavailable on the board.
enum _PointerLock {
  /// Today's journée is closed — until tomorrow.
  dayClosed,

  /// No journée open, and before the store's auto-open time.
  notOpenYet,
}

/// The board's lock for [day] at [now], or null when Pointer is available.
/// [autoOpenMinutes] is the store's `businessDayAutoOpenMinutes`.
_PointerLock? _pointerLock(BoardDay day, DateTime now, int autoOpenMinutes) {
  final businessDay = day.businessDay;
  if (businessDay == null) {
    return now.isBefore(businessDayAutoOpenAt(day.date, autoOpenMinutes))
        ? _PointerLock.notOpenYet
        : null;
  }
  return businessDay.closedAt == null ? null : _PointerLock.dayClosed;
}

/// `JOURNÉE FERMÉE` / `JOURNÉE NON OUVERTE`, disabled, where `Pointer` would
/// be.
class _PointerLockedButton extends StatelessWidget {
  const _PointerLockedButton({required this.lock});

  final _PointerLock lock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _BigButton(
      key: ValueKey(switch (lock) {
        _PointerLock.dayClosed => 'timeclock-day-closed',
        _PointerLock.notOpenYet => 'timeclock-day-not-open',
      }),
      label: switch (lock) {
        _PointerLock.dayClosed => l10n.timeclockDayClosed,
        _PointerLock.notOpenYet => l10n.timeclockDayNotOpen,
      },
      icon: LucideIcons.lock,
      outlined: true,
      onPressed: null,
    );
  }
}

/// The finished day's disabled `TERMINÉ` — the hours themselves are in the
/// drawer, not on the card.
class _DoneSummary extends StatelessWidget {
  const _DoneSummary();

  @override
  Widget build(BuildContext context) {
    return _BigButton(
      label: AppLocalizations.of(context).attendanceStatusDone,
      icon: LucideIcons.circleCheck,
      color: AppColors.surfaceVariant,
      onPressed: null,
    );
  }
}
