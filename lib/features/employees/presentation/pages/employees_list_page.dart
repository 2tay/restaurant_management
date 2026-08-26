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
/// Root screen reached from the sidebar's "Gestion des employés" entry, so it
/// carries no back control. Archived employees are hidden by default, the same instinct
/// as items and suppliers defaulting to what is currently usable — "afficher
/// les personnels retirés" brings them back into view.
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
    // Employees are creatable, editable and archivable.
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      : EmptyState.noResults(l10n))
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
    return base
        .where((employee) => employee.fullName.toLowerCase().contains(query))
        .toList();
  }
}

/// The "afficher les personnels retirés" toggle.
///
/// A plain on/off switch rather than a [PopupMenuButton]-paired filter — there
/// is nothing to pick from a menu, just a state to flip — so [FilterPill] is
/// reused for its look without the popup that normally accompanies it.
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
          _Avatar(employee: employee, dimmed: archived),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        employee.fullName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (archived) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _Pill(
                        label: l10n.employeesArchivedPill,
                        colors: const StockStatusColors(
                          solid: AppColors.textSecondary,
                          foreground: AppColors.textSecondary,
                          container: AppColors.surfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  employee.email,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _TypeChip(type: employee.type),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.employee, required this.dimmed});

  final Employee employee;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = employee.photoAsset;

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dimmed ? AppColors.neutral100 : AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: photo != null
          ? Image.asset(photo, fit: BoxFit.cover, width: 48, height: 48)
          : Text(
              employeeInitials(employee.fullName),
              style: theme.textTheme.labelLarge?.copyWith(
                color: dimmed
                    ? AppColors.textDisabled
                    : AppColors.onPrimaryContainer,
              ),
            ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final EmployeeType type;

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
        employeeTypeLabel(l10n, type),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.colors});

  final String label;
  final StockStatusColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.foreground),
      ),
    );
  }
}

/// First letters of up to two name parts — "Amélie Vandenberghe" → "AV".
/// Shared with the detail page's larger avatar.
String employeeInitials(String fullName) => fullName
    .split(' ')
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0])
    .join()
    .toUpperCase();

/// Shared type naming, so the list, the form and the detail page agree.
String employeeTypeLabel(AppLocalizations l10n, EmployeeType type) =>
    switch (type) {
      EmployeeType.fixedSalary => l10n.employeeTypeFixedSalary,
      EmployeeType.student => l10n.employeeTypeStudent,
      EmployeeType.extra => l10n.employeeTypeExtra,
    };

/// Shared pay-type naming.
String payTypeLabel(AppLocalizations l10n, PayType payType) =>
    switch (payType) {
      PayType.monthlySalary => l10n.payTypeMonthlySalary,
      PayType.hourlyRate => l10n.payTypeHourlyRate,
    };
