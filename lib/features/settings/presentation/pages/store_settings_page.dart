import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../core/utils/permissions.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/settings_tabs.dart';

/// Store name, address and preferences, plus the pointage hours and payroll
/// coefficients.
///
/// Split in two: this resolves the establishment, its units and its settings
/// row, and [_StoreSettingsForm] owns the controllers. A form whose fields are
/// filled from a query cannot be one widget, because `initState` runs before
/// the answer arrives — and filling controllers during `build` would write to
/// them while their fields are being laid out.
class StoreSettingsPage extends ConsumerWidget {
  const StoreSettingsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = asyncAll3(
      ref.watch(storeProvider(storeId)),
      ref.watch(unitsProvider(storeId)),
      ref.watch(storeSettingsProvider(storeId)),
      (store, units, settings) =>
          (store: store, units: units, settings: settings),
    );

    return AsyncContent<
      ({Store? store, List<UnitOfMeasure> units, StoreSettings settings})
    >(
      value: data,
      onRetry: () {
        ref.invalidate(storeProvider(storeId));
        ref.invalidate(unitsProvider(storeId));
        ref.invalidate(storeSettingsProvider(storeId));
      },
      // The chrome is drawn either way, so the tabs and the title do not
      // arrive a frame after the page they belong to.
      skeleton: ShellPage(
        tabs: SettingsTabs(
          storeId: storeId,
          currentPath: Routes.toStoreSettings(storeId),
        ),
        tabsAboveTitle: true,
        showTitle: false,
        title: l10n.storeSettingsTitle,
        child: const SkeletonList(rows: 3, rowHeight: 180),
      ),
      builder: (context, data) {
        final store = data.store;
        if (store == null) {
          return ShellPage(
            tabs: SettingsTabs(
              storeId: storeId,
              currentPath: Routes.toStoreSettings(storeId),
            ),
            tabsAboveTitle: true,
            showTitle: false,
            title: l10n.storeSettingsTitle,
            child: ErrorState(
              title: l10n.shellNoStoreTitle,
              message: l10n.shellNoStoreBody,
            ),
          );
        }

        return _StoreSettingsForm(
          // Keyed on the establishment so switching store rebuilds the state
          // rather than leaving the previous shop's address in the fields.
          key: ValueKey(store.id),
          store: store,
          units: data.units,
          settings: data.settings,
        );
      },
    );
  }
}

class _StoreSettingsForm extends ConsumerStatefulWidget {
  const _StoreSettingsForm({
    required this.store,
    required this.units,
    required this.settings,
    super.key,
  });

  final Store store;
  final List<UnitOfMeasure> units;
  final StoreSettings settings;

  @override
  ConsumerState<_StoreSettingsForm> createState() => _StoreSettingsFormState();
}

class _StoreSettingsFormState extends ConsumerState<_StoreSettingsForm> {
  late final _name = TextEditingController(text: widget.store.name);
  late final _address = TextEditingController(text: widget.store.addressLine);
  late final _postalCode = TextEditingController(text: widget.store.postalCode);
  late final _city = TextEditingController(text: widget.store.city);
  late final _phone = TextEditingController(text: widget.store.phone);
  late final _staleDays = TextEditingController(
    text: '${widget.settings.stalePartialOrderDays}',
  );
  late final _maxBreak = TextEditingController(
    text: '${widget.settings.maxBreakMinutes}',
  );

  /// The journée's auto-open time, minutes after midnight. Picked with the
  /// time picker, so it is always valid.
  late int _autoOpenMinutes = widget.settings.businessDayAutoOpenMinutes;
  late final _autoOpen = TextEditingController(
    text: _formatMinutes(_autoOpenMinutes),
  );

  /// Which unit a new article starts with. Local to this screen: there is no
  /// column behind it, because "the unit the form pre-selects" is a convenience
  /// rather than a fact about the establishment.
  late String? _defaultUnitId = widget.units.isEmpty
      ? null
      : widget.units.first.id;

  /// What « Annuler » puts the unit back to — it has no row to re-read.
  late String? _savedUnitId = _defaultUnitId;

  /// The unit's name, for the read-only field shown outside editing.
  late final _unitName = TextEditingController(text: _unitLabel());

  /// Which block is open for editing. Each has its own pencil and its own
  /// « Enregistrer », so one is saved without touching the other.
  bool _editingGeneral = false;
  bool _editingOperations = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _postalCode,
      _city,
      _phone,
      _staleDays,
      _maxBreak,
      _autoOpen,
      _unitName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Phase 6: only an owner may change store settings. A manager still sees the
  /// page (the route is not guarded, so the settings section has no dead end),
  /// but the fields stay read-only and no pencil is offered.
  bool get _canEdit {
    final employee = ref.watch(currentEmployeeProvider);
    return employee != null && can(employee.role, Capability.editStoreSettings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final storeId = widget.store.id;
    final canEdit = _canEdit;
    final general = _editingGeneral;
    final operations = _editingOperations;

    return ShellPage(
      tabs: SettingsTabs(
        storeId: storeId,
        currentPath: Routes.toStoreSettings(storeId),
      ),
      tabsAboveTitle: true,
      showTitle: false,
      title: l10n.storeSettingsTitle,
      // Laid straight on the page, in the search bar's white borderless look.
      child: AppTextFieldVariantScope(
        variant: AppTextFieldVariant.plain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!canEdit) ...[
              _ReadOnlyNotice(message: l10n.storeSettingsReadOnlyNotice),
              const SizedBox(height: AppSpacing.xl),
            ],
            EditableSection(
              title: l10n.storeSettingsGeneral,
              description: l10n.storeSettingsGeneralDescription,
              editKey: const ValueKey('store-settings-edit-general'),
              editing: general,
              saving: _saving,
              onEdit: canEdit
                  ? () => setState(() => _editingGeneral = true)
                  : null,
              onCancel: _cancelGeneral,
              onSave: _saveGeneral,
              child: FieldGrid(
                children: [
                  AppTextField(
                    label: l10n.addStoreName,
                    controller: _name,
                    readOnly: !general,
                  ),
                  AppTextField(
                    label: l10n.addStoreAddress,
                    controller: _address,
                    prefixIcon: LucideIcons.mapPin,
                    readOnly: !general,
                  ),
                  // Kept side by side at every width: one line of an address.
                  FieldPair(
                    first: AppTextField(
                      label: l10n.addStorePostalCode,
                      controller: _postalCode,
                      keyboardType: TextInputType.number,
                      readOnly: !general,
                    ),
                    second: AppTextField(
                      label: l10n.addStoreCity,
                      controller: _city,
                      readOnly: !general,
                    ),
                  ),
                  AppTextField(
                    label: l10n.addStorePhone,
                    controller: _phone,
                    prefixIcon: LucideIcons.phone,
                    keyboardType: TextInputType.phone,
                    readOnly: !general,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            EditableSection(
              title: l10n.storeSettingsOperations,
              description: l10n.storeSettingsOperationsDescription,
              editKey: const ValueKey('store-settings-edit-operations'),
              editing: operations,
              saving: _saving,
              onEdit: canEdit
                  ? () => setState(() => _editingOperations = true)
                  : null,
              onCancel: _cancelOperations,
              onSave: _saveOperations,
              child: FieldGrid(
                children: [
                  // A dropdown only while editing: disabled, it would grey
                  // the unit out instead of reading like the fields beside it.
                  if (operations)
                    AppDropdown<String>(
                      label: l10n.storeSettingsPreferences,
                      labelHelp: l10n.storeSettingsDefaultUnit,
                      value: _defaultUnitId,
                      options: [
                        for (final unit in widget.units)
                          DropdownOption(
                            value: unit.id,
                            label: unit.name,
                            secondaryLabel: unit.abbreviation,
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _defaultUnitId = value;
                        _unitName.text = _unitLabel();
                      }),
                    )
                  else
                    AppTextField(
                      label: l10n.storeSettingsPreferences,
                      controller: _unitName,
                      labelHelp: l10n.storeSettingsDefaultUnit,
                      prefixIcon: LucideIcons.ruler,
                      readOnly: true,
                    ),
                  AppTextField(
                    label: l10n.storeSettingsOrders,
                    controller: _staleDays,
                    labelHelp: l10n.storeSettingsStaleDaysHelp,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixIcon: LucideIcons.clock,
                    suffixText: l10n.storeSettingsDaysSuffix,
                    readOnly: !operations,
                  ),
                  AppTextField(
                    label: l10n.storeSettingsHours,
                    controller: _maxBreak,
                    labelHelp: l10n.storeSettingsHoursHelp,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixIcon: LucideIcons.coffee,
                    suffixText: l10n.storeSettingsMinutesSuffix,
                    readOnly: !operations,
                  ),
                  AppTextField(
                    key: const ValueKey('store-settings-auto-open'),
                    label: l10n.storeSettingsBusinessDay,
                    controller: _autoOpen,
                    labelHelp: l10n.storeSettingsAutoOpenHelp,
                    prefixIcon: LucideIcons.sunrise,
                    // Always picked, never typed: the picker keeps it valid.
                    readOnly: true,
                    onTap: operations ? _pickAutoOpen : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _unitLabel() {
    for (final unit in widget.units) {
      if (unit.id == _defaultUnitId) return unit.name;
    }
    return '—';
  }

  static String _formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  Future<void> _pickAutoOpen() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _autoOpenMinutes ~/ 60,
        minute: _autoOpenMinutes % 60,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _autoOpenMinutes = picked.hour * 60 + picked.minute;
      _autoOpen.text = _formatMinutes(_autoOpenMinutes);
    });
  }

  /// Puts the fields back to the saved establishment.
  void _cancelGeneral() {
    final store = widget.store;
    _name.text = store.name;
    _address.text = store.addressLine;
    _postalCode.text = store.postalCode;
    _city.text = store.city;
    _phone.text = store.phone;
    setState(() => _editingGeneral = false);
  }

  void _cancelOperations() {
    final settings = widget.settings;
    _staleDays.text = '${settings.stalePartialOrderDays}';
    _maxBreak.text = '${settings.maxBreakMinutes}';
    _autoOpenMinutes = settings.businessDayAutoOpenMinutes;
    _autoOpen.text = _formatMinutes(_autoOpenMinutes);
    setState(() {
      _defaultUnitId = _savedUnitId;
      _unitName.text = _unitLabel();
      _editingOperations = false;
    });
  }

  /// Saves the name, address and phone.
  Future<void> _saveGeneral() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(storeRepositoryProvider)
          .updateStore(
            widget.store.id,
            name: _name.text,
            addressLine: _address.text,
            postalCode: _postalCode.text,
            city: _city.text,
            phone: _phone.text,
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    setState(() => _editingGeneral = false);
    AppSnackBar.success(context, l10n.storeSettingsSaved);
  }

  /// Saves the stale-order threshold, the break allowance and the journée's
  /// auto-open time. Each survives closing the app now — which is the only way
  /// the dashboard warning and the "pause dépassée" mark it drives can be
  /// demonstrated properly.
  Future<void> _saveOperations() async {
    final l10n = AppLocalizations.of(context);
    final stores = ref.read(storeRepositoryProvider);
    setState(() => _saving = true);
    try {
      final days = int.tryParse(_staleDays.text.trim());
      if (days != null && days > 0) {
        await stores.setStalePartialOrderDays(widget.store.id, days);
      } else {
        // Falling back rather than refusing: an empty or nonsense value should
        // restore the default, not leave the dashboard with no threshold at
        // all.
        await stores.setStalePartialOrderDays(
          widget.store.id,
          OrderRules.defaultStalePartialDays,
        );
        _staleDays.text = '${OrderRules.defaultStalePartialDays}';
      }

      // The break allowance. A nonsense value is ignored here rather than
      // refused, so a half-typed field does not block the rest.
      final maxBreak = int.tryParse(_maxBreak.text.trim());
      final updated = await stores.updateStoreSettings(
        widget.store.id,
        maxBreakMinutes: maxBreak,
        businessDayAutoOpenMinutes: _autoOpenMinutes,
      );

      // Reflect what actually stuck.
      _maxBreak.text = '${updated.maxBreakMinutes}';
      _savedUnitId = _defaultUnitId;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    setState(() => _editingOperations = false);
    AppSnackBar.success(context, l10n.storeSettingsSaved);
  }
}

// Shown to a manager: the store settings are visible but not theirs to change.
class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.lock,
            size: AppSizing.iconMd,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
