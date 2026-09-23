import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/credential_status.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Create or edit a member of staff, in a [WizardDialog] over the roster.
///
/// Three steps:
///
/// 1. **Information professionnelle** — name, PIN, phone, email, and last
///    the photo.
/// 2. **Rémunération** — the hourly rate.
/// 3. **Rôle et sécurité** — the role, and the login password for a role that
///    signs in. An Employé never signs in (their pointage is done at the
///    kiosk with their PIN), so the password fields are not shown and nothing
///    is saved for one.
///
/// Creating walks the steps in order; editing may jump to any step and save
/// from each ([WizardDialog.freeNavigation]). The role picker shows what each
/// role can do rather than just its name, and only offers Gérant / Employé —
/// nobody is made Propriétaire from here. An existing owner keeps the role,
/// shown alone.
///
/// Resolves to the saved employee, or null when the dialog was closed without
/// saving.
Future<Employee?> showEmployeeWizard(
  BuildContext context, {
  required String storeId,
  Employee? employee,
}) {
  return WizardDialog.show<Employee>(
    context,
    builder: (_) => _EmployeeForm(storeId: storeId, employee: employee),
  );
}

class _EmployeeForm extends ConsumerStatefulWidget {
  const _EmployeeForm({required this.storeId, this.employee});

  final String storeId;
  final Employee? employee;

  @override
  ConsumerState<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<_EmployeeForm> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _pin = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pay = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();

  EmployeeRole _role = EmployeeRole.staff;

  /// The wizard step on screen.
  int _step = 0;

  /// A photo file just chosen from disk, not yet copied into the store. Null
  /// until the user picks one.
  String? _pickedPhotoPath;

  /// Set when the user removed the photo — clears any existing one on save.
  bool _photoCleared = false;

  /// Set when the entered PIN / email is already used by another employee.
  /// Cleared on the next keystroke so a corrected field stops complaining.
  bool _pinTaken = false;
  bool _emailTaken = false;

  bool get _isEditing => widget.employee != null;

  /// Whether the chosen role signs in to the app, and so has a password.
  bool get _needsPassword => _role != EmployeeRole.staff;

  /// The roles the picker offers. Propriétaire is never assignable from the
  /// form; an owner being edited keeps it, as the only choice, rather than
  /// being silently demoted by a save.
  List<EmployeeRole> get _selectableRoles => _initialRole == EmployeeRole.owner
      ? const [EmployeeRole.owner]
      : const [EmployeeRole.manager, EmployeeRole.staff];

  Employee? get _employee => widget.employee;

  late final Map<TextEditingController, String> _initialText;
  late EmployeeRole _initialRole;

  @override
  void initState() {
    super.initState();

    final existing = _employee;
    if (existing != null) {
      _firstName.text = existing.firstName;
      _lastName.text = existing.lastName;
      _pin.text = existing.pin;
      _phone.text = existing.phone;
      _email.text = existing.email;
      _pay.text = _formatPay(existing.pay);
      _role = existing.role;
    }

    _initialText = {
      for (final c in _controllers) c: c.text,
    };
    _initialRole = _role;
  }

  List<TextEditingController> get _controllers => [
    _firstName,
    _lastName,
    _pin,
    _phone,
    _email,
    _pay,
    _password,
    _passwordConfirm,
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _parsedPay =>
      double.tryParse(_pay.text.replaceAll(',', '.').trim());

  bool get _passwordTouched =>
      _password.text.trim().isNotEmpty || _passwordConfirm.text.trim().isNotEmpty;

  /// Both password fields hold the same valid password.
  bool get _passwordComplete =>
      isValidPassword(_password.text) && _password.text.trim() == _passwordConfirm.text.trim();

  /// Not asked for an Employé. Otherwise required when creating, optional when
  /// editing (blank keeps the current password).
  bool get _passwordValid {
    if (!_needsPassword) return true;
    return _isEditing
        ? (!_passwordTouched || _passwordComplete)
        : _passwordComplete;
  }

  bool get _passwordMismatch =>
      _passwordConfirm.text.trim().isNotEmpty &&
      _password.text.trim() != _passwordConfirm.text.trim();

  bool get _identityValid =>
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      _pin.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      !_pinTaken &&
      !_emailTaken;

  bool get _payValid => _parsedPay != null;

  bool get _isDirty =>
      _initialText.entries.any((e) => e.key.text.trim() != e.value.trim()) ||
      _role != _initialRole ||
      _pickedPhotoPath != null ||
      _photoCleared;

  /// The photo the tile should show right now: a fresh pick first, then the
  /// saved one (unless it was just removed), then null → initials.
  ImageProvider? get _photoPreview {
    if (_pickedPhotoPath != null) return FileImage(File(_pickedPhotoPath!));
    if (_photoCleared) return null;
    final existing = _employee?.photoAsset;
    return existing == null ? null : employeePhotoImage(existing);
  }

  bool get _hasPhoto => _photoPreview != null;

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context);
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(type: FileType.image);
    } catch (_) {
      if (mounted) AppSnackBar.warning(context, l10n.employeeFormPhotoReadError);
      return;
    }
    final path = picked.singleOrNull?.path;
    if (path == null) return;
    setState(() {
      _pickedPhotoPath = path;
      _photoCleared = false;
    });
  }

  void _removePhoto() {
    setState(() {
      _pickedPhotoPath = null;
      _photoCleared = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final existing = _employee;

    return WizardDialog(
      title: _isEditing ? l10n.editEmployeeTitle : l10n.addEmployeeTitle,
      description: existing == null
          ? l10n.employeeFormDescription
          : l10n.employeeFormEditDescription(employeeDisplayName(existing)),
      currentStep: _step,
      onStepChanged: (step) => setState(() => _step = step),
      freeNavigation: _isEditing,
      submitLabel: l10n.actionSave,
      submitIcon: LucideIcons.check,
      onSubmit: _submit,
      isDirty: _isDirty,
      steps: [
        WizardStep(
          label: l10n.employeeWizardStepInfo,
          isValid: _identityValid,
          child: _identityStep(l10n),
        ),
        WizardStep(
          label: l10n.employeeWizardStepPay,
          isValid: _payValid,
          child: _payStep(l10n),
        ),
        WizardStep(
          label: l10n.employeeWizardStepRole,
          isValid: _passwordValid,
          child: _roleStep(l10n),
        ),
      ],
    );
  }

  /// Step 1 — who the person is and how to reach them; the photo, optional,
  /// comes last.
  Widget _identityStep(AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: l10n.employeeFormFirstName,
                hint: l10n.employeeFormFirstNameHint,
                controller: _firstName,
                prefixIcon: LucideIcons.user,
                autofocus: !_isEditing,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: AppTextField(
                label: l10n.employeeFormLastName,
                hint: l10n.employeeFormLastNameHint,
                controller: _lastName,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: l10n.employeeFormPin,
          hint: l10n.loginPinHint,
          controller: _pin,
          prefixIcon: LucideIcons.idCard,
          errorText: _pinTaken ? l10n.employeePinTaken : null,
          onChanged: (_) => setState(() => _pinTaken = false),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: l10n.employeeFormPhone,
                hint: l10n.employeeFormPhoneHint,
                controller: _phone,
                prefixIcon: LucideIcons.phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: AppTextField(
                label: l10n.employeeFormEmail,
                hint: l10n.employeeFormEmailHint,
                controller: _email,
                prefixIcon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailTaken ? l10n.employeeEmailTaken : null,
                onChanged: (_) => setState(() => _emailTaken = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            _PhotoTile(
              image: _photoPreview,
              onTap: _pickPhoto,
              tooltip: _hasPhoto
                  ? l10n.employeeFormPhotoReplace
                  : l10n.employeeFormPhotoAction,
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.employeeFormPhoto,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.employeeFormPhotoHelp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_hasPhoto)
                    TextButton.icon(
                      onPressed: _removePhoto,
                      icon: const Icon(
                        LucideIcons.trash2,
                        size: AppSizing.iconSm,
                      ),
                      label: Text(l10n.employeeFormPhotoRemove),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Step 2 — the hourly rate.
  Widget _payStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: l10n.employeeFormPayHourly,
          hint: l10n.employeeFormPayHint,
          controller: _pay,
          prefixIcon: LucideIcons.wallet,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.employeeFormPayHelp,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Step 3 — the role, and the password only for a role that signs in.
  Widget _roleStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.employeeFormRole),
        _RolePicker(
          roles: _selectableRoles,
          selected: _role,
          onChanged: (role) => setState(() => _role = role),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_needsPassword) ...[
          SectionHeader(title: l10n.employeeFormCredentials),
          _passwordCard(l10n),
        ] else
          NoticeBanner(
            key: const ValueKey('staff-no-password'),
            icon: LucideIcons.info,
            title: l10n.employeeFormStaffNoPassword,
          ),
      ],
    );
  }

  Widget _passwordCard(AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: l10n.employeeFormPassword,
                hint: l10n.loginPasswordHint,
                controller: _password,
                prefixIcon: LucideIcons.lock,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(AuthRules.passwordLength),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: AppTextField(
                label: l10n.employeeFormPasswordConfirm,
                hint: l10n.employeeFormPasswordConfirmHint,
                controller: _passwordConfirm,
                prefixIcon: LucideIcons.lock,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(AuthRules.passwordLength),
                ],
                errorText: _passwordMismatch
                    ? l10n.employeeFormPasswordMismatch
                    : null,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _isEditing
                ? l10n.employeeFormPasswordEditHelp
                : l10n.employeeFormPasswordHelp,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final pay = _parsedPay;
    if (pay == null) return;

    final employees = ref.read(employeeRepositoryProvider);
    final existingId = widget.employee?.id;

    final Employee? result;
    if (existingId != null) {
      result = await employees.update(
        existingId,
        firstName: _firstName.text,
        lastName: _lastName.text,
        pin: _pin.text,
        phone: _phone.text,
        email: _email.text,
        role: _role,
        pay: pay,
      );
      // The password, when the fields were filled — a nested write, not part of the
      // update transaction, but a refused password there is only a validation miss
      // and the details have already saved.
      if (result != null && _needsPassword && _passwordTouched) {
        await ref
            .read(credentialRepositoryProvider)
            .setPassword(result.id, _password.text);
      }
    } else {
      result = await employees.create(
        storeId: widget.storeId,
        firstName: _firstName.text,
        lastName: _lastName.text,
        pin: _pin.text,
        phone: _phone.text,
        email: _email.text,
        role: _role,
        pay: pay,
        password: _needsPassword ? _password.text : null,
      );
    }

    if (!mounted) return;

    if (result == null) {
      // The only failures that reach here are the two uniqueness guards.
      final byPin = await employees.employeeByPin(
        _pin.text.trim(),
        excludingId: existingId,
      );
      final byEmail = await employees.employeeByEmail(
        _email.text.trim(),
        excludingId: existingId,
      );
      if (!mounted) return;
      setState(() {
        _pinTaken = byPin != null;
        _emailTaken = byEmail != null;
        if (_pinTaken || _emailTaken) _step = 0;
      });
      return;
    }

    // The photo — copied into the store and written onto the row now that the
    // id exists. A separate write from the details, like the password above.
    final photoStore = ref.read(employeePhotoStoreProvider);
    if (_pickedPhotoPath != null) {
      final stored = await photoStore.save(
        employeeId: result.id,
        sourcePath: _pickedPhotoPath!,
      );
      await employees.update(result.id, photoAsset: stored);
    } else if (_photoCleared && widget.employee?.photoAsset != null) {
      await photoStore.deleteFor(result.id);
      await employees.update(result.id, clearPhoto: true);
    }

    if (!mounted) return;

    AppSnackBar.success(
      context,
      _isEditing ? l10n.employeeUpdated : l10n.employeeCreated,
    );
    // Close the dialog — Navigator.pop, not maybePop: the save is the one
    // way out that must not ask "abandonner les modifications ?".
    Navigator.of(context).pop(result);
  }

  static String _formatPay(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString().replaceAll('.', ',');
}

/// The photo tile on the form — and the picker: a grey circle with an upload
/// icon until a photo is chosen, then the photo. Tapping it opens the file
/// picker either way.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.image,
    required this.onTap,
    required this.tooltip,
  });

  static const double _size = 80;

  final ImageProvider? image;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    const upload = Icon(
      LucideIcons.upload,
      size: AppSizing.iconLg,
      color: AppColors.placeholder,
    );

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          key: const ValueKey('employee-photo-picker'),
          color: AppColors.surfaceVariant,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: _size,
              height: _size,
              child: image == null
                  ? const Center(child: upload)
                  : Image(
                      image: image!,
                      width: _size,
                      height: _size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(child: upload),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The role choices: side by side when there is room for two readable cards,
/// stacked on a phone.
class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.roles,
    required this.selected,
    required this.onChanged,
  });

  final List<EmployeeRole> roles;
  final EmployeeRole selected;
  final ValueChanged<EmployeeRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final role in roles)
        _RoleOption(
          key: ValueKey('role-option-${role.name}'),
          role: role,
          selected: selected == role,
          onTap: () => onChanged(role),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (options.length < 2 || constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, option) in options.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                option,
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, option) in options.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: option),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A role choice showing name and description together — "Gérant" means
/// nothing on its own, and picking the wrong one is how someone ends up
/// unable to do their job.
class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final EmployeeRole role;
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
                Text(
                  employeeRoleLabel(l10n, role),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  employeeRoleDescription(l10n, role),
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
