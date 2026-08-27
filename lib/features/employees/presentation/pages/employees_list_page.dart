import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
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
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);
    final all = MockQueries.employeesForStore(widget.storeId);
    final filtered = _filtered(all);

    return ShellPage(
      title: l10n.employeesTitle,
      subtitle: l10n.employeesSubtitle,
      scrollable: false,
      actions: [
        PrimaryButton(
          label: l10n.employeesAdd,
          icon: LucideIcons.userPlus,
          onPressed: () =>
              context.pushScreen(Routes.toAddEmployee(widget.storeId)),
        ),
      ],
      child: Column(
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
          Expanded(
            child: filtered.isEmpty
                ? (all.isEmpty
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
                        ))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _EmployeeRow(
                      employee: filtered[index],
                      storeId: widget.storeId,
                    ),
                  ),
          ),
        ],
      ),
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
          (e) =>
              e.role == EmployeeRole.manager || e.role == EmployeeRole.owner,
        )
        .length;
    final now = DateTime.now();
    final hiredThisMonth = active
        .where(
          (e) => e.hireDate.year == now.year && e.hireDate.month == now.month,
        )
        .length;

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: l10n.employeesKpiActive,
            value: '${active.length}',
            icon: LucideIcons.users,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: StatTile(
            label: l10n.employeesKpiContractSplit,
            value: l10n.employeesKpiContractSplitValue(fixed, extra),
            icon: LucideIcons.briefcase,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: StatTile(
            label: l10n.employeesKpiManagers,
            value: '$managers',
            icon: LucideIcons.shieldCheck,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: StatTile(
            label: l10n.employeesKpiHiredThisMonth,
            value: '$hiredThisMonth',
            icon: LucideIcons.userPlus,
          ),
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
      child: Row(
        children: [
          EmployeeAvatar(employee: employee, dimmed: archived),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      _ArchivedPill(label: l10n.employeesArchivedPill),
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
          const SizedBox(width: AppSpacing.md),
          EmployeeRoleBadge(role: employee.role),
          const SizedBox(width: AppSpacing.sm),
          _ContractChip(type: employee.contractType),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            LucideIcons.chevronRight,
            size: AppSizing.iconMd,
            color: AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}

class _ContractChip extends StatelessWidget {
  const _ContractChip({required this.type});

  final ContractType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        contractTypeLabel(l10n, type),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ArchivedPill extends StatelessWidget {
  const _ArchivedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
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
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
