import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';

/// Store name, address and preferences.
class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({required this.storeId, super.key});

  final String storeId;

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _staleDays = TextEditingController();
  String? _defaultUnitId;

  @override
  void initState() {
    super.initState();
    final store = MockQueries.storeById(widget.storeId);
    if (store != null) {
      _name.text = store.name;
      _address.text = store.addressLine;
      _postalCode.text = store.postalCode;
      _city.text = store.city;
      _phone.text = store.phone;
    }
    final units = MockQueries.unitsForStore(widget.storeId);
    _defaultUnitId = units.isEmpty ? null : units.first.id;
    _staleDays.text = '${MockSettings.stalePartialOrderDays}';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _postalCode,
      _city,
      _phone,
      _staleDays,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final units = MockQueries.unitsForStore(widget.storeId);

    return ShellPage(
      tabs: SectionTabs(
        currentPath: Routes.toStoreSettings(widget.storeId),
        tabs: [
          SectionTab(
            label: l10n.settingsTabStore,
            path: Routes.toStoreSettings(widget.storeId),
          ),
          SectionTab(
            label: l10n.settingsTabAccount,
            path: Routes.toAccountSettings(widget.storeId),
          ),
          SectionTab(
            label: l10n.settingsTabNotifications,
            path: Routes.toNotificationSettings(widget.storeId),
          ),
          SectionTab(
            label: l10n.settingsTabSync,
            path: Routes.toSyncStatus(widget.storeId),
          ),
        ],
      ),
      title: l10n.storeSettingsTitle,
      actions: [
        PrimaryButton(
          label: l10n.actionSave,
          icon: LucideIcons.check,
          onPressed: _save,
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l10n.storeSettingsGeneral),
            AppCard(
              child: Column(
                children: [
                  AppTextField(label: l10n.addStoreName, controller: _name),
                  const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: l10n.addStorePhone,
                    controller: _phone,
                    prefixIcon: LucideIcons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: l10n.storeSettingsPreferences),
            AppCard(
              child: AppDropdown<String>(
                label: l10n.storeSettingsDefaultUnit,
                value: _defaultUnitId,
                options: [
                  for (final unit in units)
                    DropdownOption(
                      value: unit.id,
                      label: unit.name,
                      secondaryLabel: unit.abbreviation,
                    ),
                ],
                onChanged: (value) => setState(() => _defaultUnitId = value),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: l10n.storeSettingsOrders),
            AppCard(
              child: SizedBox(
                width: 260,
                child: AppTextField(
                  label: l10n.storeSettingsStaleDays,
                  controller: _staleDays,
                  helperText: l10n.storeSettingsStaleDaysHelp,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  prefixIcon: LucideIcons.clock,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nothing else on this screen persists in this phase, but the stale-order
  /// threshold does — within the session — because the dashboard warning it
  /// drives is only demonstrable if changing the number changes the warning.
  void _save() {
    final l10n = AppLocalizations.of(context);
    final days = int.tryParse(_staleDays.text.trim());
    if (days != null && days > 0) {
      MockSettings.stalePartialOrderDays = days;
    } else {
      // Falling back rather than refusing: an empty or nonsense value should
      // restore the default, not leave the dashboard with no threshold at all.
      MockSettings.reset();
      _staleDays.text = '${MockSettings.stalePartialOrderDays}';
    }
    AppSnackBar.success(context, l10n.storeSettingsSaved);
  }
}
