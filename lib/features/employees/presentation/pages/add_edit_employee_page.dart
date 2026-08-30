import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/credential_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Create or edit a member of staff.
///
/// One form for both modes, same shape as `add_edit_supplier_page.dart`. The
/// pay label switches between "Salaire mensuel (€)" and "Tarif horaire (€/h)"
/// as the contract type changes — reactive form state, not two fields, since
/// exactly one applies. The role picker shows what each role can do rather
/// than just its name.
class AddEditEmployeePage extends StatefulWidget {
  const AddEditEmployeePage({required this.storeId, this.employeeId, super.key});

  final String storeId;

  /// Null when creating.
  final String? employeeId;

  @override
  State<AddEditEmployeePage> createState() => _AddEditEmployeePageState();
}

class _AddEditEmployeePageState extends State<AddEditEmployeePage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _cin = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pay = TextEditingController();
  final _scheduleStart = TextEditingController();
  final _scheduleEnd = TextEditingController();
  final _pin = TextEditingController();
  final _pinConfirm = TextEditingController();

  EmployeeRole _role = EmployeeRole.staff;
  ContractType _contract = ContractType.fixed;

  /// Set when the entered CIN / email is already used by another employee.
  /// Cleared on the next keystroke so a corrected field stops complaining.
  bool _cinTaken = false;
  bool _emailTaken = false;

  bool get _isEditing => widget.employeeId != null;

  Employee? get _employee => widget.employeeId == null
      ? null
      : MockQueries.employeeById(widget.employeeId!);

  late final Map<TextEditingController, String> _initialText;
  late EmployeeRole _initialRole;
  late ContractType _initialContract;

  @override
  void initState() {
    super.initState();

    final existing = _employee;
    if (existing != null) {
      _firstName.text = existing.firstName;
      _lastName.text = existing.lastName;
      _cin.text = existing.cin;
      _phone.text = existing.phone;
      _email.text = existing.email;
      _pay.text = _formatPay(existing.pay);
      _role = existing.role;
      _contract = existing.contractType;
      if (existing.scheduledStartMinutes != null) {
        _scheduleStart.text = Formatters.minutesToClock(
          existing.scheduledStartMinutes!,
        );
      }
      if (existing.scheduledEndMinutes != null) {
        _scheduleEnd.text = Formatters.minutesToClock(
          existing.scheduledEndMinutes!,
        );
      }
    }

    _initialText = {
      for (final c in _controllers) c: c.text,
    };
    _initialRole = _role;
    _initialContract = _contract;
  }

  List<TextEditingController> get _controllers => [
    _firstName,
    _lastName,
    _cin,
    _phone,
    _email,
    _pay,
    _scheduleStart,
    _scheduleEnd,
    _pin,
    _pinConfirm,
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

  /// Null when the field is blank (→ use store hours); a value when it parses;
  /// the sentinel -1 when it is filled but invalid (→ block submit).
  int? _parsedTime(TextEditingController c) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    return Formatters.clockToMinutes(text) ?? -1;
  }

  bool get _scheduleValid =>
      _parsedTime(_scheduleStart) != -1 && _parsedTime(_scheduleEnd) != -1;

  bool get _pinTouched =>
      _pin.text.trim().isNotEmpty || _pinConfirm.text.trim().isNotEmpty;

  /// Both PIN fields hold the same valid PIN.
  bool get _pinComplete =>
      isValidPin(_pin.text) && _pin.text.trim() == _pinConfirm.text.trim();

  /// Required when creating; optional when editing (blank keeps the old code).
  bool get _pinValid =>
      _isEditing ? (!_pinTouched || _pinComplete) : _pinComplete;

  bool get _pinMismatch =>
      _pinConfirm.text.trim().isNotEmpty &&
      _pin.text.trim() != _pinConfirm.text.trim();

  bool get _canSubmit =>
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      _cin.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      _parsedPay != null &&
      _scheduleValid &&
      _pinValid;

  bool get _isDirty =>
      _initialText.entries.any((e) => e.key.text.trim() != e.value.trim()) ||
      _role != _initialRole ||
      _contract != _initialContract;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FormScaffold(
      title: _isEditing ? l10n.editEmployeeTitle : l10n.addEmployeeTitle,
      back: BackDestination(
        label: l10n.employeesTitle,
        path: Routes.toEmployees(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.employeesTitle, Routes.toEmployees(widget.storeId)),
        Crumb(_isEditing ? l10n.editEmployeeTitle : l10n.addEmployeeTitle),
      ],
      submitLabel: l10n.actionSave,
      submitIcon: LucideIcons.check,
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _isDirty,
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: l10n.employeeFormPhoto),
          AppCard(
            child: Row(
              children: [
                _PhotoTile(
                  firstName: _firstName.text,
                  lastName: _lastName.text,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: SecondaryButton(
                    label: l10n.employeeFormPhotoAction,
                    icon: LucideIcons.camera,
                    onPressed: () => AppSnackBar.warning(
                      context,
                      l10n.employeeFormPhotoMockNotice,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: l10n.employeeFormFirstName,
                        controller: _firstName,
                        prefixIcon: LucideIcons.user,
                        autofocus: !_isEditing,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: l10n.employeeFormLastName,
                        controller: _lastName,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l10n.employeeFormCin,
                  controller: _cin,
                  prefixIcon: LucideIcons.idCard,
                  errorText: _cinTaken ? l10n.employeeCinTaken : null,
                  onChanged: (_) => setState(() => _cinTaken = false),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: l10n.employeeFormPhone,
                        controller: _phone,
                        prefixIcon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: l10n.employeeFormEmail,
                        controller: _email,
                        prefixIcon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailTaken
                            ? l10n.employeeEmailTaken
                            : null,
                        onChanged: (_) => setState(() => _emailTaken = false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(title: l10n.employeeFormRole),
          for (final role in EmployeeRole.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RoleOption(
                role: role,
                selected: _role == role,
                onTap: () => setState(() => _role = role),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(title: l10n.employeeFormEmployment),
          AppCard(
            child: Column(
              children: [
                AppDropdown<ContractType>(
                  label: l10n.employeeFormContractType,
                  value: _contract,
                  options: [
                    for (final t in ContractType.values)
                      DropdownOption(
                        value: t,
                        label: contractTypeLabel(l10n, t),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _contract = value ?? _contract),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: _contract == ContractType.fixed
                      ? l10n.employeeFormPayMonthly
                      : l10n.employeeFormPayHourly,
                  controller: _pay,
                  prefixIcon: LucideIcons.wallet,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(title: l10n.employeeFormSchedule),
          AppCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: l10n.employeeFormScheduleStart,
                        controller: _scheduleStart,
                        hint: '08:00',
                        prefixIcon: LucideIcons.sunrise,
                        errorText: _parsedTime(_scheduleStart) == -1
                            ? l10n.employeeFormScheduleInvalid
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: l10n.employeeFormScheduleEnd,
                        controller: _scheduleEnd,
                        hint: '17:00',
                        prefixIcon: LucideIcons.sunset,
                        errorText: _parsedTime(_scheduleEnd) == -1
                            ? l10n.employeeFormScheduleInvalid
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
                    l10n.employeeFormScheduleHelp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(title: l10n.employeeFormCredentials),
          AppCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: l10n.employeeFormPin,
                        controller: _pin,
                        prefixIcon: LucideIcons.lock,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(AuthRules.pinLength),
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: l10n.employeeFormPinConfirm,
                        controller: _pinConfirm,
                        prefixIcon: LucideIcons.lock,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(AuthRules.pinLength),
                        ],
                        errorText: _pinMismatch
                            ? l10n.employeeFormPinMismatch
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
                        ? l10n.employeeFormPinEditHelp
                        : l10n.employeeFormPinHelp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final pay = _parsedPay;
    if (pay == null) return;

    final start = _parsedTime(_scheduleStart);
    final end = _parsedTime(_scheduleEnd);
    if (start == -1 || end == -1) return;

    final result = _isEditing
        ? EmployeeMutations.update(
            widget.employeeId!,
            firstName: _firstName.text,
            lastName: _lastName.text,
            cin: _cin.text,
            phone: _phone.text,
            email: _email.text,
            role: _role,
            contractType: _contract,
            pay: pay,
            scheduledStartMinutes: start,
            scheduledEndMinutes: end,
            clearSchedule: start == null && end == null,
          )
        : EmployeeMutations.create(
            storeId: widget.storeId,
            firstName: _firstName.text,
            lastName: _lastName.text,
            cin: _cin.text,
            phone: _phone.text,
            email: _email.text,
            role: _role,
            contractType: _contract,
            pay: pay,
            scheduledStartMinutes: start,
            scheduledEndMinutes: end,
          );

    if (result == null) {
      // The only failures that reach here are the two uniqueness guards.
      setState(() {
        _cinTaken =
            MockQueries.employeeByCin(
              _cin.text.trim(),
              excludingId: widget.employeeId,
            ) !=
            null;
        _emailTaken =
            MockQueries.employeeByEmail(
              _email.text.trim(),
              excludingId: widget.employeeId,
            ) !=
            null;
      });
      return;
    }

    // Phase 6: persist the PIN. Required on create; on edit only when the
    // fields were filled (blank keeps the existing code).
    if (!_isEditing || _pinTouched) {
      CredentialMutations.setPin(result.id, _pin.text);
    }

    AppSnackBar.success(
      context,
      _isEditing ? l10n.employeeUpdated : l10n.employeeCreated,
    );
    if (_isEditing) {
      context.pushScreen(Routes.toEmployee(widget.storeId, widget.employeeId!));
    } else {
      context.goSection(Routes.toEmployees(widget.storeId));
    }
  }

  static String _formatPay(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString().replaceAll('.', ',');
}

/// The mocked photo picker's tile — an initials avatar, since no employee in
/// this demo carries a real `photoAsset` (assumption in the brief: same
/// treatment as `Store.imageAsset`, no file picker plumbing).
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.firstName, required this.lastName});

  final String firstName;
  final String lastName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letters = [
      if (firstName.trim().isNotEmpty) firstName.trim()[0],
      if (lastName.trim().isNotEmpty) lastName.trim()[0],
    ].join().toUpperCase();

    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        letters.isEmpty ? '?' : letters,
        style: theme.textTheme.titleLarge?.copyWith(
          color: AppColors.onPrimaryContainer,
        ),
      ),
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
