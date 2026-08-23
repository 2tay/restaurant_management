import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';

/// Create or edit a supplier.
class AddEditSupplierPage extends StatefulWidget {
  const AddEditSupplierPage({
    required this.storeId,
    this.supplierId,
    super.key,
  });

  final String storeId;

  /// Null when creating.
  final String? supplierId;

  @override
  State<AddEditSupplierPage> createState() => _AddEditSupplierPageState();
}

class _AddEditSupplierPageState extends State<AddEditSupplierPage> {
  final _name = TextEditingController();
  final _contactName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _note = TextEditingController();

  bool get _isEditing => widget.supplierId != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.supplierId == null
        ? null
        : MockQueries.supplierById(widget.supplierId!);

    if (existing != null) {
      _name.text = existing.name;
      _contactName.text = existing.contactName;
      _email.text = existing.email;
      _phone.text = existing.phone;
      _address.text = existing.addressLine;
      _postalCode.text = existing.postalCode;
      _city.text = existing.city;
      _note.text = existing.note ?? '';
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _contactName,
      _email,
      _phone,
      _address,
      _postalCode,
      _city,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit => _name.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: _isEditing ? l10n.editSupplierTitle : l10n.addSupplierTitle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    label: l10n.supplierFormName,
                    controller: _name,
                    hint: l10n.supplierFormNameHint,
                    autofocus: !_isEditing,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: l10n.supplierFormContactName,
                    controller: _contactName,
                    prefixIcon: LucideIcons.user,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: l10n.supplierFormEmail,
                          controller: _email,
                          prefixIcon: LucideIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: AppTextField(
                          label: l10n.supplierFormPhone,
                          controller: _phone,
                          prefixIcon: LucideIcons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    label: l10n.addStoreAddress,
                    controller: _address,
                    prefixIcon: LucideIcons.mapPin,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 160,
                        child: AppTextField(
                          label: l10n.addStorePostalCode,
                          controller: _postalCode,
                          hint: '1000',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: AppTextField(
                          label: l10n.addStoreCity,
                          controller: _city,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              child: AppTextField(
                label: l10n.supplierFormNote,
                controller: _note,
                hint: l10n.supplierFormNoteHint,
                maxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SecondaryButton(label: l10n.actionCancel, onPressed: _leave),
                const SizedBox(width: AppSpacing.md),
                PrimaryButton(
                  label: l10n.actionSave,
                  icon: LucideIcons.check,
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
      _isEditing ? l10n.supplierUpdated : l10n.supplierCreated,
    );
    _leave();
  }

  void _leave() {
    if (_isEditing) {
      context.go(Routes.toSupplier(widget.storeId, widget.supplierId!));
    } else {
      context.go(Routes.toSuppliers(widget.storeId));
    }
  }
}
