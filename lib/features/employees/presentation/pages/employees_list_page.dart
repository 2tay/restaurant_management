import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/employee_actions.dart';
import '../widgets/employee_card.dart';
import '../widgets/employee_actions_menu.dart';
import '../widgets/employee_wizard_dialog.dart';

/// The staff roster — *Personnel*.
///
/// Root screen reached from the sidebar's "Gestion Employée" dropdown, so it
/// carries no back control. Archived people are hidden by default, the same
/// instinct as items and suppliers defaulting to what is currently usable —
/// "afficher les personnels retirés" brings them back into view.
///
/// Two layouts of the same filtered roster — cards (the default) or a table —
/// behind the same toggle the inventory uses. The actions — the person's
/// pointage and payment histories (opened filtered to them), Modifier,
/// Retirer / Restaurer — are on each card's ⋮ menu and in the table's Actions
/// column; nothing opens on a plain click.
class EmployeesListPage extends ConsumerStatefulWidget {
  const EmployeesListPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<EmployeesListPage> createState() => _EmployeesListPageState();
}

class _EmployeesListPageState extends ConsumerState<EmployeesListPage> {
  String _query = '';
  bool _showArchived = false;
  CollectionViewMode _viewMode = CollectionViewMode.grid;

  void _add() => showEmployeeWizard(context, storeId: widget.storeId);

  late final _actions = _RosterActions(
    onAttendance: (e) => context.goSection(
      Routes.toAttendanceHistory(widget.storeId, employeeId: e.id),
    ),
    onPayroll: (e) => context.goSection(
      Routes.toPayroll(widget.storeId, employeeId: e.id),
    ),
    onEdit: (e) =>
        showEmployeeWizard(context, storeId: widget.storeId, employee: e),
    onArchive: (e) => confirmArchiveEmployee(context, ref, e),
    onRestore: (e) => restoreEmployee(context, ref, e),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final employees = ref.watch(employeesProvider(widget.storeId));

    return ShellPage(
      title: l10n.employeesTitle,
      subtitle: l10n.employeesSubtitle,
      actions: [
        PrimaryButton(
          label: l10n.employeesAdd,
          shortLabel: l10n.shortAddEmployee,
          icon: LucideIcons.userPlus,
          onPressed: _add,
        ),
      ],
      child: AsyncContent<List<Employee>>(
        value: employees,
        onRetry: () => ref.invalidate(employeesProvider(widget.storeId)),
        builder: (context, all) => _content(context, l10n, all),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l10n,
    List<Employee> all,
  ) {
    final filtered = _filtered(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiRow(employees: all),
        const SizedBox(height: AppSpacing.lg),
        FilterToolbar(
          search: SearchField(
            hint: l10n.employeesSearchHint,
            onChanged: (value) => setState(() => _query = value),
          ),
          filters: [
            _ArchivedFilterPill(
              active: _showArchived,
              onTap: () => setState(() => _showArchived = !_showArchived),
            ),
            ViewModeToggle(
              mode: _viewMode,
              onSelected: (mode) => setState(() => _viewMode = mode),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (filtered.isEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 360),
            child: all.isEmpty
                ? EmptyState(
                    icon: LucideIcons.idCard,
                    title: l10n.employeesEmpty,
                    message: l10n.employeesEmptyBody,
                    actionLabel: l10n.employeesAdd,
                    actionIcon: LucideIcons.userPlus,
                    onAction: _add,
                  )
                : EmptyState.noResults(
                    l10n,
                    onClearFilters: () => setState(() {
                      _query = '';
                      _showArchived = false;
                    }),
                  ),
          )
        else if (_viewMode == CollectionViewMode.list)
          _EmployeeTable(
            // The owner is the account, not staff to manage here — neither a
            // card nor a row.
            employees: [
              for (final e in filtered)
                if (e.role != EmployeeRole.owner) e,
            ],
            actions: _actions,
          )
        else
          _EmployeeGrid(
            // The owner is the account, not a member of staff to manage from
            // here — no card for them (nor a table row).
            employees: [
              for (final e in filtered)
                if (e.role != EmployeeRole.owner) e,
            ],
            actions: _actions,
          ),
      ],
    );
  }

  List<Employee> _filtered(List<Employee> all) {
    final base = _showArchived ? all : all.where(isEmployeeActive).toList();
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return base;
    return base.where((employee) {
      return employeeDisplayName(employee).toLowerCase().contains(query) ||
          employee.pin.toLowerCase().contains(query);
    }).toList();
  }
}

/// Five figures over the whole roster (active only) — three counts, the
/// average and the highest hourly rate — independent of the search
/// below — the same split the reports pages use between a headline total and
/// a filtered result count.
class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = employees.where(isEmployeeActive).toList();
    final managers = active
        .where(
          (e) => e.role == EmployeeRole.manager || e.role == EmployeeRole.owner,
        )
        .length;
    final now = DateTime.now();
    final hiredThisMonth = active
        .where(
          (e) => e.hireDate.year == now.year && e.hireDate.month == now.month,
        )
        .length;
    // Mean hourly rate of the active roster — what an hour of staff costs on
    // average. A dash, not "0,00 €", when nobody is active.
    final averageRate = active.isEmpty
        ? null
        : active.map((e) => e.pay).reduce((a, b) => a + b) / active.length;
    final maxRate = active.isEmpty
        ? null
        : active.map((e) => e.pay).reduce((a, b) => a > b ? a : b);

    return StatTileRow(
      tiles: [
        StatTile(
          label: l10n.employeesKpiActive,
          value: '${active.length}',
          icon: LucideIcons.users,
        ),
        StatTile(
          label: l10n.employeesKpiManagers,
          value: '$managers',
          icon: LucideIcons.shieldCheck,
        ),
        StatTile(
          label: l10n.employeesKpiHiredThisMonth,
          value: '$hiredThisMonth',
          icon: LucideIcons.userPlus,
        ),
        StatTile(
          key: const ValueKey('kpi-average-rate'),
          label: l10n.employeesKpiAverageRate,
          value: averageRate == null
              ? '—'
              : '${Formatters.price(averageRate)} /h',
          icon: LucideIcons.wallet,
        ),
        StatTile(
          key: const ValueKey('kpi-max-rate'),
          label: l10n.employeesKpiMaxRate,
          value: maxRate == null ? '—' : '${Formatters.price(maxRate)} /h',
          icon: LucideIcons.trendingUp,
        ),
      ],
    );
  }
}

/// The "afficher les personnels retirés" toggle — a plain on/off flip, so
/// [FilterPill] is reused for its look without the popup that usually
/// accompanies it.
class _ArchivedFilterPill extends StatelessWidget {
  const _ArchivedFilterPill({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: FilterPill(
          label: l10n.employeesShowArchived,
          selectedLabel: active ? l10n.employeesShowArchived : null,
          icon: LucideIcons.archive,
          // Red, like the retired cards it brings into view.
          activeColors: AppColors.outOfStock,
        ),
      ),
    );
  }
}

/// The roster as a grid of vertical [EmployeeCard]s — as many per line as
/// the width allows (300dp minimum, up to four), sized by
/// the same [cardGridColumns] as the pointage and payroll history cards.
class _EmployeeGrid extends StatelessWidget {
  const _EmployeeGrid({required this.employees, required this.actions});

  final List<Employee> employees;
  final _RosterActions actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = cardGridColumns(
          constraints.maxWidth,
          minCardWidth: 300,
          maxColumns: 4,
        );
        const spacing = AppSpacing.lg;
        final cardWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final employee in employees)
              SizedBox(
                width: cardWidth,
                child: EmployeeCard(
                  key: ValueKey('employee-card-${employee.id}'),
                  employee: employee,
                  onAttendance: () => actions.onAttendance(employee),
                  onPayroll: () => actions.onPayroll(employee),
                  onEdit: () => actions.onEdit(employee),
                  onArchive: () => actions.onArchive(employee),
                  onRestore: () => actions.onRestore(employee),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// What a card or a table row can do for one person — built once by the page.
class _RosterActions {
  const _RosterActions({
    required this.onAttendance,
    required this.onPayroll,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final ValueChanged<Employee> onAttendance;
  final ValueChanged<Employee> onPayroll;
  final ValueChanged<Employee> onEdit;
  final ValueChanged<Employee> onArchive;
  final ValueChanged<Employee> onRestore;
}

/// The roster as a table — the alternative to the card grid, for scanning
/// contact details, rates and hire dates side by side. The Actions column
/// opens the two histories directly and holds the same ⋮ menu as a card.
/// Same [DataTableWrapper] as the pointage history: below its minimum width
/// it scrolls sideways rather than squeezing the columns.
class _EmployeeTable extends StatelessWidget {
  const _EmployeeTable({required this.employees, required this.actions});

  final List<Employee> employees;
  final _RosterActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: 960,
      columns: [
        DataColumn(label: Text(l10n.employeesColumnName)),
        DataColumn(label: Text(l10n.employeesColumnRole)),
        DataColumn(label: Text(l10n.employeeFormPhone)),
        DataColumn(label: Text(l10n.employeeFormEmail)),
        DataColumn(label: Text(l10n.employeesColumnPay), numeric: true),
        DataColumn(label: Text(l10n.employeesColumnHired)),
        DataColumn(label: Text(l10n.employeesColumnActions)),
      ],
      rows: [for (final e in employees) _row(context, l10n, e)],
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, Employee employee) {
    final archived = !isEmployeeActive(employee);

    return DataRow(
      key: ValueKey('employee-row-${employee.id}'),
      // A retired person's row hovers red, like their card and badge.
      color: archived
          ? WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.hovered)
                  ? AppColors.error.withValues(alpha: 0.08)
                  : null,
            )
          : null,
      // Nothing opens on a row click; the handler only keeps the hover
      // highlight (red for the retired), with the ordinary arrow cursor.
      onSelectChanged: (_) {},
      mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
      cells: [
        DataCell(
          EmployeeCell(
            employee: employee,
            dimmed: archived,
            trailing: archived
                ? LabelChip(
                    key: const ValueKey('employee-row-retired'),
                    label: l10n.employeesArchivedPill,
                    background: AppColors.outOfStock.container,
                    foreground: AppColors.outOfStock.foreground,
                    dense: true,
                    borderRadius: AppRadius.smAll,
                  )
                : null,
          ),
        ),
        DataCell(EmployeeRoleBadge(role: employee.role)),
        DataCell(Text(employee.phone)),
        DataCell(Text(employee.email)),
        DataCell(Text('${Formatters.price(employee.pay)} / h')),
        DataCell(Text(Formatters.dateShortWeekday(employee.hireDate))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: ValueKey('employee-row-attendance-${employee.id}'),
                tooltip: l10n.employeeActionAttendance,
                icon: const Icon(LucideIcons.history, size: AppSizing.iconSm),
                color: AppColors.primary600,
                onPressed: () => actions.onAttendance(employee),
              ),
              IconButton(
                key: ValueKey('employee-row-payroll-${employee.id}'),
                tooltip: l10n.employeeActionPayroll,
                icon: const Icon(LucideIcons.wallet, size: AppSizing.iconSm),
                color: AppColors.primary600,
                onPressed: () => actions.onPayroll(employee),
              ),
              EmployeeActionsMenu(
                employee: employee,
                includeHistories: false,
                onAttendance: () => actions.onAttendance(employee),
                onPayroll: () => actions.onPayroll(employee),
                onEdit: () => actions.onEdit(employee),
                onArchive: () => actions.onArchive(employee),
                onRestore: () => actions.onRestore(employee),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
