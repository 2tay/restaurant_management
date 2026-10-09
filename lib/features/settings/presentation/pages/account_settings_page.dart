import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/restaurant_account_section.dart';
import '../widgets/settings_tabs.dart';

/// The signed-in employee's own profile, security and linked stores.
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // The session is resolved synchronously (`currentEmployeeProvider` is a
    // `Notifier` hydrated before the first frame); only the establishment list
    // is a query.
    final user = ref.watch(currentEmployeeProvider);
    final stores = ref.watch(storesProvider);

    return ShellPage(
      tabs: SettingsTabs(
        storeId: storeId,
        currentPath: Routes.toAccountSettings(storeId),
      ),
      tabsAboveTitle: true,
      showTitle: false,
      title: l10n.accountSettingsTitle,
      child: AsyncContent<List<Store>>(
        value: stores,
        skeleton: const SkeletonList(rows: 3, rowHeight: 140),
        onRetry: () => ref.invalidate(storesProvider),
        builder: (context, stores) {
          // No signed-in employee. Phase 2 always has one by the time this
          // screen is reachable — the guard sees to that — so this is the
          // branch Phase 3 will reach when nobody is signed in.
          if (user == null) return const ErrorState();
          // The owner spans stores; everyone else is scoped to their own.
          final visible = visibleStores(user, stores);
          return _body(context, l10n, theme, user, visible);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Employee user,
    List<Store> stores,
  ) {
    // The établissement page's look: blocks straight on the page, fields in
    // the search bar's white borderless style.
    return AppTextFieldVariantScope(
      variant: AppTextFieldVariant.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Keyed on the employee so a session change refills the fields.
          _ProfileSection(key: ValueKey(user.id), user: user),
          const SizedBox(height: AppSpacing.xxl),

          const RestaurantAccountSection(),
          const SizedBox(height: AppSpacing.xxl),

          SettingsSectionTitle(
            title: l10n.accountSecurity,
            description: l10n.accountSecurityDescription,
          ),
          FieldGrid(
            children: [
              ReadOnlyValueField(
                label: l10n.accountChangePassword,
                value: '••••••••',
                icon: LucideIcons.lock,
                // The pencil, as on the blocks' titles: it fits at any text
                // size where « Modifier » in words did not.
                trailing: IconButton(
                  onPressed: () => context.goSection(Routes.forgotPassword),
                  tooltip: l10n.actionEdit,
                  icon: const Icon(LucideIcons.pencil, size: AppSizing.iconSm),
                  color: AppColors.primary600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          SettingsSectionTitle(
            title: '${l10n.accountLinkedStores} (${stores.length})',
            description: l10n.accountLinkedStoresDescription,
          ),
          // One card per establishment, as on the notification settings.
          ResponsiveCardGrid(
            maxColumns: 2,
            equalRowHeights: true,
            children: [
              for (final store in stores)
                IconInfoCard(
                  icon: LucideIcons.store,
                  title: store.name,
                  value:
                      '${store.addressLine}, ${store.postalCode} ${store.city}',
                  highlighted: store.id == storeId,
                  trailing: store.id == storeId
                      ? const Icon(
                          LucideIcons.circleCheck,
                          color: AppColors.primary600,
                        )
                      : const Icon(
                          LucideIcons.chevronRight,
                          color: AppColors.textSecondary,
                        ),
                  onTap: () => context.goSection(Routes.toDashboard(store.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The signed-in employee's own name and contact details, read-only until the
/// pencil is pressed. The role is shown but never edited here: changing one's
/// own access is the personnel page's business, and an owner's.
class _ProfileSection extends ConsumerStatefulWidget {
  const _ProfileSection({required this.user, super.key});

  final Employee user;

  @override
  ConsumerState<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<_ProfileSection> {
  late final _firstName = TextEditingController(text: widget.user.firstName);
  late final _lastName = TextEditingController(text: widget.user.lastName);
  late final _email = TextEditingController(text: widget.user.email);
  late final _phone = TextEditingController(text: widget.user.phone);

  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_firstName, _lastName, _email, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return EditableSection(
      title: l10n.accountProfile,
      description: l10n.accountProfileDescription,
      editKey: const ValueKey('account-edit-profile'),
      editing: _editing,
      saving: _saving,
      onEdit: () => setState(() => _editing = true),
      onCancel: _cancel,
      onSave: _save,
      child: FieldGrid(
        children: [
          AppTextField(
            label: l10n.employeeFormFirstName,
            controller: _firstName,
            readOnly: !_editing,
          ),
          AppTextField(
            label: l10n.employeeFormLastName,
            controller: _lastName,
            readOnly: !_editing,
          ),
          AppTextField(
            label: l10n.employeeFormEmail,
            controller: _email,
            prefixIcon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            readOnly: !_editing,
          ),
          AppTextField(
            label: l10n.employeeFormPhone,
            controller: _phone,
            prefixIcon: LucideIcons.phone,
            keyboardType: TextInputType.phone,
            readOnly: !_editing,
          ),
          ReadOnlyValueField(
            label: l10n.accountRole,
            value: employeeRoleLabel(l10n, widget.user.role),
            icon: LucideIcons.shieldCheck,
          ),
        ],
      ),
    );
  }

  void _cancel() {
    final user = widget.user;
    _firstName.text = user.firstName;
    _lastName.text = user.lastName;
    _email.text = user.email;
    _phone.text = user.phone;
    setState(() => _editing = false);
  }

  /// Writes the four fields, then re-reads the session so the sidebar and
  /// this page show the new name. Refused as a whole when a field is blank or
  /// the email belongs to someone else.
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    final updated = await ref
        .read(employeeRepositoryProvider)
        .update(
          widget.user.id,
          firstName: _firstName.text,
          lastName: _lastName.text,
          email: _email.text,
          // A profile that never had a phone may keep none.
          phone: _phone.text.trim().isEmpty && widget.user.phone.isEmpty
              ? null
              : _phone.text,
        );
    if (updated != null) {
      await ref.read(currentEmployeeProvider.notifier).hydrate();
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (updated != null) _editing = false;
    });
    if (updated == null) {
      AppSnackBar.warning(context, l10n.accountProfileInvalid);
    } else {
      AppSnackBar.success(context, l10n.accountProfileSaved);
    }
  }
}
