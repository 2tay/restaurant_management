import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/employee_status.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../data/current_employee.dart';
import '../../../../../data/providers.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../models/models.dart';
import '../../../../../shared/widgets/widgets.dart';

/// "Qui enregistre ?" — the employee at the shared kitchen tablet names
/// themselves before a stock movement is saved.
///
/// The tablet stays signed in as the manager all day; the people moving stock
/// are the cooks. So every save asks who it is: tap your card, then confirm
/// with your CIN — the same dialog, and the same three-strikes lockout, as the
/// pointage board, so there is one habit to learn, not two. The signed-in
/// manager is on the grid too, marked "Moi", and confirms the same way.
///
/// Asked at the save rather than when the form opens, so the person who
/// confirms is the person who saves; and nothing is remembered between two
/// saves, so the next person always names themselves.
///
/// Resolves to the confirmed employee, or null if the sheet was dismissed.
abstract final class MovementActorSheet {
  static Future<Employee?> show(
    BuildContext context, {
    required String storeId,
    required String actionLabel,
  }) {
    final body = _ActorPicker(storeId: storeId, actionLabel: actionLabel);

    if (context.isPhone) {
      return showModalBottomSheet<Employee>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: body),
      );
    }
    return showDialog<Employee>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: body,
        ),
      ),
    );
  }
}

class _ActorPicker extends ConsumerStatefulWidget {
  const _ActorPicker({required this.storeId, required this.actionLabel});

  final String storeId;
  final String actionLabel;

  @override
  ConsumerState<_ActorPicker> createState() => _ActorPickerState();
}

class _ActorPickerState extends ConsumerState<_ActorPicker> {
  String _query = '';

  Future<void> _confirm(Employee employee) async {
    final l10n = AppLocalizations.of(context);
    final ok = await IdentityPromptDialog.show(
      context,
      title: l10n.identityPromptTitle,
      subtitle: l10n.identityPromptPointageSubtitle(
        widget.actionLabel,
        employeeDisplayName(employee),
      ),
      verify: (cin) =>
          ref.read(credentialRepositoryProvider).verifyCin(cin, employee.id),
    );
    if (ok && mounted) Navigator.of(context).pop(employee);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentEmployeeProvider);

    final active =
        ref.watch(activeEmployeesProvider(widget.storeId)).value ??
        const <Employee>[];

    // The signed-in user first, as "Moi" — an owner who spans every store is
    // not on this store's roster, so they are added rather than looked up.
    final everyone = [
      ?me,
      for (final employee in active)
        if (employee.id != me?.id) employee,
    ];

    final query = _query.trim().toLowerCase();
    final visible = [
      for (final employee in everyone)
        if (query.isEmpty ||
            employeeDisplayName(employee).toLowerCase().contains(query))
          employee,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.actorSheetTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.actorSheetSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
        ),
        if (everyone.length > 8)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: SearchField(
              hint: l10n.actorSearchHint,
              maxWidth: double.infinity,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Flexible(
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.actorNoEmployees,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 168,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisExtent: _ActorCard.heightFor(context),
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final employee = visible[index];
                    return _ActorCard(
                      employee: employee,
                      isMe: employee.id == me?.id,
                      onTap: () => _confirm(employee),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// One person on the grid: photo, name, role — big enough to hit with a
/// thumb from arm's length.
class _ActorCard extends StatelessWidget {
  const _ActorCard({
    required this.employee,
    required this.isMe,
    required this.onTap,
  });

  final Employee employee;
  final bool isMe;
  final VoidCallback onTap;

  static double heightFor(BuildContext context) {
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      2.0,
    );
    // Padding, avatar and gaps (fixed), then two lines of name and the role
    // badge (grown with the type size).
    return 104 + 72 * scale + AppCard.verticalBorderAllowance;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              EmployeeAvatar(employee: employee, size: 56),
              if (isMe)
                Positioned(
                  right: -AppSpacing.sm,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary600,
                      borderRadius: AppRadius.pillAll,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: Text(
                      l10n.actorMe,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            employeeDisplayName(employee),
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: EmployeeRoleBadge(role: employee.role),
          ),
        ],
      ),
    );
  }
}
