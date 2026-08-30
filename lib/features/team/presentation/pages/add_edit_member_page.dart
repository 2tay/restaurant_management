import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'team_list_page.dart';

/// Invite a new member, or edit an existing one.
///
/// The role picker shows what each role can actually do rather than just its
/// name. "Gérant" means nothing on its own, and picking the wrong one is how
/// someone ends up unable to record a delivery mid-service.
class AddEditMemberPage extends ConsumerWidget {
  const AddEditMemberPage({required this.storeId, this.memberId, super.key});

  final String storeId;

  /// Null when inviting.
  final String? memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (memberId == null) {
      return _MemberForm(storeId: storeId, existing: null);
    }

    final l10n = AppLocalizations.of(context);
    final asyncMember = ref.watch(teamMemberProvider(memberId!));
    final existing = asyncMember.value;

    if (existing == null) {
      return ShellPage(
        title: l10n.teamTitle,
        child: asyncMember.isLoading
            ? const SkeletonList(rows: 3, rowHeight: 90)
            : ErrorState(
                onRetry: () => context.goSection(Routes.toTeam(storeId)),
              ),
      );
    }

    return _MemberForm(
      key: ValueKey(memberId),
      storeId: storeId,
      existing: existing,
    );
  }
}

class _MemberForm extends ConsumerStatefulWidget {
  const _MemberForm({
    required this.storeId,
    required this.existing,
    super.key,
  });

  final String storeId;
  final TeamMember? existing;

  @override
  ConsumerState<_MemberForm> createState() => _AddEditMemberPageState();
}

class _AddEditMemberPageState extends ConsumerState<_MemberForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  TeamRole _role = TeamRole.staff;

  /// Set when the entered email is already on the team. Cleared on the next
  /// keystroke so a corrected field stops complaining immediately.
  bool _emailTaken = false;
  late Set<String> _storeIds = {widget.storeId};

  // Snapshot of how the form opened, for the unsaved-changes check.
  String _initialName = '';
  String _initialEmail = '';
  TeamRole _initialRole = TeamRole.staff;
  Set<String> _initialStoreIds = {};

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.fullName;
      _email.text = existing.email;
      _role = existing.role;
      _storeIds = existing.storeIds.toSet();
    }

    _initialName = _name.text.trim();
    _initialEmail = _email.text.trim();
    _initialRole = _role;
    _initialStoreIds = _storeIds.toSet();
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

  bool get _isDirty =>
      _name.text.trim() != _initialName ||
      _email.text.trim() != _initialEmail ||
      _role != _initialRole ||
      !_setEquals(_storeIds, _initialStoreIds);

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.every(b.contains);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FormScaffold(
      title: _isEditing ? l10n.editMemberTitle : l10n.inviteTitle,
      back: BackDestination(
        label: l10n.teamTitle,
        path: Routes.toTeam(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.teamTitle, Routes.toTeam(widget.storeId)),
        Crumb(_isEditing ? l10n.editMemberTitle : l10n.inviteTitle),
      ],
      submitLabel: _isEditing ? l10n.actionSave : l10n.teamInvite,
      submitIcon: _isEditing ? LucideIcons.check : LucideIcons.mail,
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _isDirty,
      maxWidth: 720,
      secondaryAction: _isEditing
          ? DestructiveButton(
              label: l10n.actionDelete,
              icon: LucideIcons.trash2,
              filled: false,
              onPressed: _confirmRemove,
            )
          : null,
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
                  errorText: _emailTaken ? l10n.memberEmailTaken : null,
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
                for (final store
                    in ref.watch(storesProvider).value ?? const [])
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
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final account = ref.read(accountRepositoryProvider);

    final result = _isEditing
        ? await account.updateMember(
            widget.existing!.id,
            fullName: _name.text,
            email: _email.text,
            role: _role,
            storeIds: _storeIds.toList(),
          )
        : await account.invite(
            fullName: _name.text,
            email: _email.text,
            role: _role,
            storeIds: _storeIds.toList(),
          );

    if (!mounted) return;

    // Null means the email is already on the team — the only validation here
    // that can fail. Flagged under the field rather than in a snackbar, so
    // there is something to correct.
    if (result == null) {
      setState(() => _emailTaken = true);
      return;
    }

    AppSnackBar.success(
      context,
      _isEditing ? l10n.memberUpdated : l10n.memberInvited,
    );
    context.goSection(Routes.toTeam(widget.storeId));
  }

  Future<void> _confirmRemove() async {
    final l10n = AppLocalizations.of(context);
    final account = ref.read(accountRepositoryProvider);
    final id = widget.existing?.id;
    if (id == null) return;

    // An account nobody can administer is not a state to be able to reach by
    // accident — there is no way back to it from inside the app. The repository
    // refuses it too; this is the sentence that explains why.
    final lastOwner = await account.isLastOwner(id);
    if (!mounted) return;

    if (lastOwner) {
      await ConfirmDialog.blocked(
        context,
        title: l10n.memberRemoveBlockedTitle(_name.text.trim()),
        message: l10n.memberRemoveBlockedBody,
      );
      return;
    }

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: _name.text.trim(),
      extraWarning: l10n.memberRemoveWarning,
    );
    if (!confirmed || !mounted) return;

    await account.removeMember(id);

    if (!mounted) return;
    AppSnackBar.success(context, l10n.memberRemoved);
    context.goSection(Routes.toTeam(widget.storeId));
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
