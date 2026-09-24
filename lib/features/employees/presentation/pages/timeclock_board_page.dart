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

/// Identity, status and the buttons — the day's timestamps live in the
/// drawer behind "Voir détails", not on the card.
const double _cardHeight = 348;

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
      // One line at the title's right: the live date and time, then full
      // screen.
      actions: const [LiveDateTime(), _FullScreenToggleButton()],
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

    // The selector still resolves against the live roster — an employee
    // archived while their card was pinned falls back to the whole board.
    final pinned = _selected == null
        ? null
        : all.where((e) => e.id == _selected!.id).firstOrNull;
    final shown = pinned == null ? all : [pinned];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          SizedBox(
            width: 360,
            height: _cardHeight,
            child: _EmployeeCard(
              employee: pinned,
              entry: board[pinned.id],
              settings: settings,
              storeId: widget.storeId,
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
              mainAxisExtent: _cardHeight,
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
  });

  final Employee employee;
  final Attendance? entry;
  final StoreSettings settings;
  final String storeId;

  void _openDetail(BuildContext context) {
    DetailDrawer.show(
      context,
      // The live date and time as the heading — icons, no labels — over a
      // dashed rule.
      header: const LiveDateTime(showLabels: false),
      dashedRule: true,
      children: [_BoardDetail(storeId: storeId, employeeId: employee.id)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final status = entry?.status ?? AttendanceStatus.notClockedIn;

    return AppCard(
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

/// The drawer behind "Voir détails": who this is, where their day stands,
/// its timestamps session by session, and the time worked.
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final employee = ref
        .watch(activeEmployeesProvider(storeId))
        .value
        ?.where((e) => e.id == employeeId)
        .firstOrNull;
    final entry = ref.watch(attendanceBoardProvider(storeId)).value?[employeeId];
    final settings = ref.watch(storeSettingsProvider(storeId)).value;
    if (employee == null || settings == null) return const SizedBox.shrink();

    final status = entry?.status ?? AttendanceStatus.notClockedIn;
    final worked = entry == null ? null : workedDuration(entry);

    Widget sectionTitle(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: AppSizing.iconSm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(text, style: theme.textTheme.titleSmall)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                  ),
                  Text(
                    employeeRoleLabel(l10n, employee.role),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AttendanceStatusBadge(status: status),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        sectionTitle(LucideIcons.clock, l10n.timeclockSchedule),
        const SizedBox(height: AppSpacing.md),
        if (entry == null || entry.sessions.isEmpty)
          Text(
            l10n.timeclockNoPunchYet,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          AttendanceSessions(
            entry: entry,
            maxBreakMinutes: resolvedMaxBreakMinutes(
              entry,
              fallback: settings.maxBreakMinutes,
            ),
          ),
        // The day's total closes the Horaires section.
        if (worked != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.md),
          Row(
            key: const ValueKey('timeclock-detail-worked'),
            children: [
              Expanded(
                child: Text(
                  l10n.attendanceColumnWorked,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                Formatters.duration(worked),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ],
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
  /// employee's PIN first — the dialog owns the wrong-attempt / lockout loop.
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
