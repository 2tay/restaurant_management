import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'team_list_page.dart';

/// Invite a new member, or edit an existing one.
///
/// The role picker shows what each role can actually do rather than just its
/// name. "Gérant" means nothing on its own, and picking the wrong one is how
/// someone ends up unable to record a delivery mid-service.
class AddEditMemberPage extends StatefulWidget {
  const AddEditMemberPage({required this.storeId, this.memberId, super.key});

  final String storeId;

  /// Null when inviting.
  final String? memberId;

  @override
  State<AddEditMemberPage> createState() => _AddEditMemberPageState();
}

class _AddEditMemberPageState extends State<AddEditMemberPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  TeamRole _role = TeamRole.staff;
  late Set<String> _storeIds = {widget.storeId};

  bool get _isEditing => widget.memberId != null;

  TeamMember? get _member {
    if (widget.memberId == null) return null;
    for (final member in mockTeam) {
      if (member.id == widget.memberId) return member;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final existing = _member;
    if (existing != null) {
      _name.text = existing.fullName;
      _email.text = existing.email;
      _role = existing.role;
      _storeIds = existing.storeIds.toSet();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _name.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      _storeIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: _isEditing ? l10n.editMemberTitle : l10n.inviteTitle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    label: l10n.memberFormName,
                    controller: _name,
                    prefixIcon: LucideIcons.user,
                    autofocus: !_isEditing,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: l10n.memberFormEmail,
                    controller: _email,
                    prefixIcon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isEditing,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            SectionHeader(title: l10n.memberFormRole),
            for (final role in TeamRole.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RoleOption(
                  role: role,
                  selected: _role == role,
                  onTap: () => setState(() => _role = role),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),

            SectionHeader(title: l10n.memberFormStores),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final store in mockStores)
                    CheckboxListTile(
                      value: _storeIds.contains(store.id),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _storeIds.add(store.id);
                        } else {
                          _storeIds.remove(store.id);
                        }
                      }),
                      title: Text(store.name),
                      subtitle: Text(store.city),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isEditing) ...[
                  DestructiveButton(
                    label: l10n.actionDelete,
                    icon: LucideIcons.trash2,
                    filled: false,
                    onPressed: _confirmRemove,
                  ),
                  const Spacer(),
                ],
                SecondaryButton(
                  label: l10n.actionCancel,
                  onPressed: () => context.go(Routes.toTeam(widget.storeId)),
                ),
                const SizedBox(width: AppSpacing.md),
                PrimaryButton(
                  label: _isEditing ? l10n.actionSave : l10n.teamInvite,
                  icon: _isEditing ? LucideIcons.check : LucideIcons.mail,
                  onPressed: _canSubmit ? _submit : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    AppSnackBar.success(
      context,
      _isEditing ? l10n.memberUpdated : l10n.memberInvited,
    );
    context.go(Routes.toTeam(widget.storeId));
  }

  Future<void> _confirmRemove() async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: _name.text.trim(),
      extraWarning: l10n.memberRemoveWarning,
    );

    if (confirmed && mounted) {
      AppSnackBar.success(context, l10n.memberRemoved);
      context.go(Routes.toTeam(widget.storeId));
    }
  }
}

/// A role choice showing name and description together.
class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final TeamRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      selected: selected,
      child: Row(
        children: [
          // A drawn indicator rather than a Radio widget: Flutter deprecated
          // Radio's groupValue in favour of a RadioGroup ancestor, and the
          // whole card is the tap target here anyway.
          Icon(
            selected ? LucideIcons.circleCheck : LucideIcons.circle,
            size: AppSizing.iconLg,
            color: selected ? AppColors.primary600 : AppColors.borderStrong,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roleLabel(l10n, role), style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  roleDescription(l10n, role),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
