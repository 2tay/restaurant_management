import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'employees_list_page.dart';

/// Create or edit a member of staff.
///
/// One form for both modes, same shape as `add_edit_supplier_page.dart` and
/// `add_edit_member_page.dart`. The pay rate label switches between "Salaire
/// mensuel (€)" and "Tarif horaire (€/h)" as the pay type changes — done
/// reactively in form state rather than as two separate fields, since exactly
/// one of the two ever applies.
class AddEditEmployeePage extends StatefulWidget {
  const AddEditEmployeePage({
    required this.storeId,
    this.employeeId,
    super.key,
  });

  final String storeId;

  /// Null when creating.
  final String? employeeId;

  @override
  State<AddEditEmployeePage> createState() => _AddEditEmployeePageState();
}

class _AddEditEmployeePageState extends State<AddEditEmployeePage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _cin = TextEditingController();
  final _payRate = TextEditingController();

  EmployeeType _type = EmployeeType.fixedSalary;
  PayType _payType = PayType.monthlySalary;

  /// Set when the entered email is already on file for this store. Cleared on
  /// the next keystroke so a corrected field stops complaining immediately.
  bool _emailTaken = false;

  bool get _isEditing => widget.employeeId != null;

  Employee? get _employee => widget.employeeId == null
      ? null
      : MockQueries.employeeById(widget.employeeId!);

  @override
  void initState() {
    super.initState();

    final existing = _employee;
    if (existing != null) {
      _name.text = existing.fullName;
      _email.text = existing.email;
      _phone.text = existing.phone;
      _address.text = existing.address;
      _cin.text = existing.cin;
      _type = existing.type;
      _payType = existing.payType;
      _payRate.text = _formatRate(existing.payRate);
    }

    _initialValues.length;
    _initialType = _type;
    _initialPayType = _payType;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _address,
      _cin,
      _payRate,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  late final Map<TextEditingController, String> _initialValues = {
    _name: _name.text,
    _email: _email.text,
    _phone: _phone.text,
    _address: _address.text,
    _cin: _cin.text,
    _payRate: _payRate.text,
  };
  late EmployeeType _initialType;
  late PayType _initialPayType;

  bool get _canSubmit =>
      _name.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty &&
      _address.text.trim().isNotEmpty &&
      _cin.text.trim().isNotEmpty &&
      _parsedRate != null;

  bool get _isDirty =>
      _initialValues.entries.any(
        (entry) => entry.key.text.trim() != entry.value.trim(),
      ) ||
      _type != _initialType ||
      _payType != _initialPayType;

  double? get _parsedRate =>
      double.tryParse(_payRate.text.replaceAll(',', '.').trim());

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
                _PhotoTile(name: _name.text),
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
                AppTextField(
                  label: l10n.employeeFormFullName,
                  controller: _name,
                  prefixIcon: LucideIcons.user,
                  autofocus: !_isEditing,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l10n.employeeFormEmail,
                  controller: _email,
                  errorText: _emailTaken ? l10n.employeeEmailTaken : null,
                  prefixIcon: LucideIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() => _emailTaken = false),
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
                        label: l10n.employeeFormCin,
                        controller: _cin,
                        prefixIcon: LucideIcons.idCard,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l10n.employeeFormAddress,
                  controller: _address,
                  prefixIcon: LucideIcons.mapPin,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              children: [
                AppDropdown<EmployeeType>(
                  label: l10n.employeeFormType,
                  value: _type,
                  options: [
                    for (final type in EmployeeType.values)
                      DropdownOption(
                        value: type,
                        label: employeeTypeLabel(l10n, type),
                      ),
                  ],
                  onChanged: (value) => setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppDropdown<PayType>(
                        label: l10n.employeeFormPayType,
                        value: _payType,
                        options: [
                          for (final payType in PayType.values)
                            DropdownOption(
                              value: payType,
                              label: payTypeLabel(l10n, payType),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _payType = value ?? _payType),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: _payType == PayType.monthlySalary
                            ? l10n.employeeFormPayRateMonthly
                            : l10n.employeeFormPayRateHourly,
                        controller: _payRate,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
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
    final rate = _parsedRate;
    if (rate == null) return;

    final result = _isEditing
        ? EmployeeMutations.update(
            widget.employeeId!,
            fullName: _name.text,
            email: _email.text,
            phone: _phone.text,
            address: _address.text,
            cin: _cin.text,
            type: _type,
            payType: _payType,
            payRate: rate,
          )
        : EmployeeMutations.create(
            storeId: widget.storeId,
            fullName: _name.text,
            email: _email.text,
            phone: _phone.text,
            address: _address.text,
            cin: _cin.text,
            type: _type,
            payType: _payType,
            payRate: rate,
          );

    // Null means the email is already used in this store — the only
    // validation here that can fail. Flagged under the field rather than in
    // a snackbar, so there is something to correct.
    if (result == null) {
      setState(() => _emailTaken = true);
      return;
    }

    AppSnackBar.success(
      context,
      _isEditing ? l10n.employeeUpdated : l10n.employeeCreated,
    );
    _leave();
  }

  void _leave() {
    if (_isEditing) {
      context.pushScreen(Routes.toEmployee(widget.storeId, widget.employeeId!));
    } else {
      context.goSection(Routes.toEmployees(widget.storeId));
    }
  }

  static String _formatRate(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString().replaceAll('.', ',');
}

/// The mocked photo picker's tile — an initials avatar, since no employee in
/// this demo carries a real `photoAsset`. See assumption 6 in the employees
/// brief: same treatment as `Store.imageAsset`, no file picker plumbing.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = name.trim();

    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        trimmed.isEmpty ? '?' : employeeInitials(trimmed),
        style: theme.textTheme.titleLarge?.copyWith(
          color: AppColors.onPrimaryContainer,
        ),
      ),
    );
  }
}
