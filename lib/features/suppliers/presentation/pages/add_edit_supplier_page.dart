import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
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

    _initialValues.length;
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

  /// Controller paired with the value it held when the form opened. Comparing
  /// against a snapshot rather than setting a flag means editing a field back
  /// to its original value correctly stops counting as unsaved.
  late final Map<TextEditingController, String> _initialValues = {
    _name: _name.text,
    _contactName: _contactName.text,
    _email: _email.text,
    _phone: _phone.text,
    _address: _address.text,
    _postalCode: _postalCode.text,
    _city: _city.text,
    _note: _note.text,
  };

  bool get _isDirty => _initialValues.entries.any(
    (entry) => entry.key.text.trim() != entry.value.trim(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FormScaffold(
      title: _isEditing ? l10n.editSupplierTitle : l10n.addSupplierTitle,
      back: BackDestination(
        label: l10n.suppliersTitle,
        path: Routes.toSuppliers(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.suppliersTitle, Routes.toSuppliers(widget.storeId)),
        Crumb(_isEditing ? l10n.editSupplierTitle : l10n.addSupplierTitle),
      ],
      submitLabel: l10n.actionSave,
      submitIcon: LucideIcons.check,
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _isDirty,
      maxWidth: 720,
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
        ],
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);

    if (_isEditing) {
      SupplierMutations.update(
        widget.supplierId!,
        name: _name.text,
        contactName: _contactName.text,
        email: _email.text,
        phone: _phone.text,
        addressLine: _address.text,
        postalCode: _postalCode.text,
        city: _city.text,
        note: _note.text,
        clearNote: _note.text.trim().isEmpty,
      );
    } else {
      SupplierMutations.create(
        storeId: widget.storeId,
        name: _name.text,
        contactName: _contactName.text,
        email: _email.text,
        phone: _phone.text,
        addressLine: _address.text,
        postalCode: _postalCode.text,
        city: _city.text,
        note: _note.text,
      );
    }

    AppSnackBar.success(
      context,
      _isEditing ? l10n.supplierUpdated : l10n.supplierCreated,
    );
    _leave();
  }

  void _leave() {
    if (_isEditing) {
      context.pushScreen(Routes.toSupplier(widget.storeId, widget.supplierId!));
    } else {
      context.goSection(Routes.toSuppliers(widget.storeId));
    }
  }
}
