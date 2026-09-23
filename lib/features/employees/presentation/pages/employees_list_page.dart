import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/employee_detail_drawer.dart';
import '../widgets/employee_wizard_dialog.dart';

/// The staff roster — *Personnel*.
///
/// Root screen reached from the sidebar's "Gestion Employée" dropdown, so it
/// carries no back control. Archived people are hidden by default, the same
/// instinct as items and suppliers defaulting to what is currently usable —
/// "afficher les personnels retirés" brings them back into view.
///
/// Two layouts of the same filtered roster — cards (the default) or a table —
/// behind the same toggle the inventory uses. Either way a click opens the
/// person's detail in a drawer over the list rather than navigating away.
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

  void _open(Employee employee) => showEmployeeDetailDrawer(
    context,
    storeId: widget.storeId,
    employee: employee,
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
        LayoutBuilder(
          builder: (context, constraints) {
            final search = SearchField(
              hint: l10n.employeesSearchHint,
              onChanged: (value) => setState(() => _query = value),
            );
            final pill = _ArchivedFilterPill(
              active: _showArchived,
              onTap: () => setState(() => _showArchived = !_showArchived),
            );
            final toggle = ViewModeToggle(
              mode: _viewMode,
              onSelected: (mode) => setState(() => _viewMode = mode),
            );
            // One line: the search on the left, the two controls at the right
            // edge — under the last KPI. On a phone they do not fit one line;
            // the search takes its own, the two controls sit under it.
            if (constraints.maxWidth < AppBreakpoints.compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flexible only here, where the line is short: beside
                      // an Expanded search it would split the free space and
                      // leave the controls short of the right edge.
                      Flexible(child: pill),
                      const SizedBox(width: AppSpacing.md),
                      toggle,
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: AppSpacing.md),
                pill,
                const SizedBox(width: AppSpacing.md),
                toggle,
              ],
            );
          },
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
          _EmployeeTable(employees: filtered, onOpen: _open)
        else
          _EmployeeGrid(employees: filtered, onOpen: _open),
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
        ),
      ),
    );
  }
}

/// The roster as a grid of cards — as many per line as the available width
/// allows, rather than one full-width row per employee, which wastes most of
/// a tablet or desktop screen on a two-line card. Uses the same
/// [cardGridColumns] sizing as the pointage and payroll history cards, and
/// [AdaptiveRow] inside each card stacks its own content at that width, so a
/// card reads the same whether there is 1 column or 4.
class _EmployeeGrid extends StatelessWidget {
  const _EmployeeGrid({required this.employees, required this.onOpen});

  final List<Employee> employees;
  final ValueChanged<Employee> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = cardGridColumns(constraints.maxWidth);
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
                child: _EmployeeCard(
                  employee: employee,
                  onTap: () => onOpen(employee),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.onTap});

  final Employee employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final archived = !isEmployeeActive(employee);

    return AppCard(
      onTap: onTap,
      // Avatar and identity stay together; the role badge drops to its own
      // line on a phone, where the name alone fills the row.
      child: AdaptiveRow(
        cells: [
          AdaptiveCell(
            flex: 1,
            child: Row(
              children: [
                EmployeeAvatar(employee: employee, dimmed: archived),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              employeeDisplayName(employee),
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (archived) ...[
                            const SizedBox(width: AppSpacing.sm),
                            LabelChip(
                              label: l10n.employeesArchivedPill,
                              dense: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.employeePinLabel(employee.pin),
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
          ),
          AdaptiveCell(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EmployeeRoleBadge(role: employee.role),
                const Icon(
                  LucideIcons.chevronRight,
                  size: AppSizing.iconMd,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The roster as a table — the alternative to the card grid, for scanning
/// contact details and rates side by side. Same [DataTableWrapper] as the
/// pointage history: below its minimum width it scrolls sideways rather than
/// squeezing the columns.
class _EmployeeTable extends StatelessWidget {
  const _EmployeeTable({required this.employees, required this.onOpen});

  final List<Employee> employees;
  final ValueChanged<Employee> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: 960,
      columns: [
        DataColumn(label: Text(l10n.employeesColumnName)),
        DataColumn(label: Text(l10n.employeeFormPin)),
        DataColumn(label: Text(l10n.employeesColumnRole)),
        DataColumn(label: Text(l10n.employeeFormPhone)),
        DataColumn(label: Text(l10n.employeeFormEmail)),
        DataColumn(label: Text(l10n.employeesColumnPay), numeric: true),
        DataColumn(label: Text(l10n.employeesColumnDetail)),
      ],
      rows: [for (final e in employees) _row(context, l10n, e)],
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, Employee employee) {
    final theme = Theme.of(context);
    final archived = !isEmployeeActive(employee);

    return DataRow(
      key: ValueKey('employee-row-${employee.id}'),
      onSelectChanged: (_) => onOpen(employee),
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmployeeAvatar(employee: employee, size: 32, dimmed: archived),
              const SizedBox(width: AppSpacing.md),
              Text(
                employeeDisplayName(employee),
                style: theme.textTheme.bodyMedium,
              ),
              if (archived) ...[
                const SizedBox(width: AppSpacing.sm),
                LabelChip(label: l10n.employeesArchivedPill, dense: true),
              ],
            ],
          ),
        ),
        DataCell(Text(employee.pin)),
        DataCell(EmployeeRoleBadge(role: employee.role)),
        DataCell(Text(employee.phone)),
        DataCell(Text(employee.email)),
        DataCell(Text('${Formatters.price(employee.pay)} / h')),
        DataCell(
          IconButton(
            tooltip: l10n.employeesViewDetail,
            icon: const Icon(LucideIcons.eye, size: AppSizing.iconSm),
            onPressed: () => onOpen(employee),
          ),
        ),
      ],
    );
  }
}
