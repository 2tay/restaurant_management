import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// The staff roster — *Personnel*.
///
/// Root screen reached from the sidebar's "Gestion Employée" dropdown, so it
/// carries no back control. Archived people are hidden by default, the same
/// instinct as items and suppliers defaulting to what is currently usable —
/// "afficher les personnels retirés" brings them back into view.
class EmployeesListPage extends ConsumerStatefulWidget {
  const EmployeesListPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<EmployeesListPage> createState() => _EmployeesListPageState();
}

class _EmployeesListPageState extends ConsumerState<EmployeesListPage> {
  String _query = '';
  bool _showArchived = false;

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
          onPressed: () =>
              context.pushScreen(Routes.toAddEmployee(widget.storeId)),
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
        Row(
          children: [
            Expanded(
              child: SearchField(
                hint: l10n.employeesSearchHint,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _ArchivedFilterPill(
              active: _showArchived,
              onTap: () => setState(() => _showArchived = !_showArchived),
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
                    onAction: () => context.pushScreen(
                      Routes.toAddEmployee(widget.storeId),
                    ),
                  )
                : EmptyState.noResults(
                    l10n,
                    onClearFilters: () => setState(() {
                      _query = '';
                      _showArchived = false;
                    }),
                  ),
          )
        else
          _EmployeeGrid(employees: filtered, storeId: widget.storeId),
      ],
    );
  }

  List<Employee> _filtered(List<Employee> all) {
    final base = _showArchived ? all : all.where(isEmployeeActive).toList();
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return base;
    return base.where((employee) {
      return employeeDisplayName(employee).toLowerCase().contains(query) ||
          employee.cin.toLowerCase().contains(query);
    }).toList();
  }
}

/// Four counts over the whole roster (active only), independent of the search
/// below — the same split the reports pages use between a headline total and
/// a filtered result count.
class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = employees.where(isEmployeeActive).toList();
    final fixed = active
        .where((e) => e.contractType == ContractType.fixed)
        .length;
    final extra = active.length - fixed;
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

    return StatTileRow(
      tiles: [
        StatTile(
          label: l10n.employeesKpiActive,
          value: '${active.length}',
          icon: LucideIcons.users,
        ),
        StatTile(
          label: l10n.employeesKpiContractSplit,
          value: l10n.employeesKpiContractSplitValue(fixed, extra),
          icon: LucideIcons.briefcase,
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
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
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
  const _EmployeeGrid({required this.employees, required this.storeId});

  final List<Employee> employees;
  final String storeId;

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
                child: _EmployeeRow(employee: employee, storeId: storeId),
              ),
          ],
        );
      },
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.employee, required this.storeId});

  final Employee employee;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final archived = !isEmployeeActive(employee);

    return AppCard(
      onTap: () => context.pushScreen(Routes.toEmployee(storeId, employee.id)),
      // Avatar and identity stay together; the role and contract badges drop
      // to their own line on a phone, where the name alone fills the row.
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
          ),
          AdaptiveCell(
            // A Wrap, not a Row: "Gérant" and "Contrat fixe" together are
            // wider than a 360dp card even on their own line, so the two
            // badges have to be able to stack as well as move.
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EmployeeRoleBadge(role: employee.role),
                LabelChip(
                  label: contractTypeLabel(l10n, employee.contractType),
                ),
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
