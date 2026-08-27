import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
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
  final _openTime = TextEditingController();
  final _closeTime = TextEditingController();
  final _maxBreak = TextEditingController();
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

    final settings = MockQueries.storeSettings(widget.storeId);
    _staleDays.text = '${settings.stalePartialOrderDays}';
    _openTime.text = Formatters.minutesToClock(settings.openMinutes);
    _closeTime.text = Formatters.minutesToClock(settings.closeMinutes);
    _maxBreak.text = '${settings.maxBreakMinutes}';
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
      _openTime,
      _closeTime,
      _maxBreak,
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: LucideIcons.clock,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionHeader(title: l10n.storeSettingsHours),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: l10n.storeSettingsOpenTime,
                          controller: _openTime,
                          hint: '08:00',
                          prefixIcon: LucideIcons.sunrise,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: AppTextField(
                          label: l10n.storeSettingsCloseTime,
                          controller: _closeTime,
                          hint: '17:00',
                          prefixIcon: LucideIcons.sunset,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: 260,
                    child: AppTextField(
                      label: l10n.storeSettingsMaxBreak,
                      controller: _maxBreak,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      prefixIcon: LucideIcons.coffee,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.storeSettingsHoursHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The store-settings values persist within the session — the dashboard
  /// warning, the pointage lateness and the "pause dépassée" mark are all only
  /// demonstrable if changing a number changes what the app shows.
  void _save() {
    final l10n = AppLocalizations.of(context);

    final updated = AccountMutations.updateStoreSettings(
      widget.storeId,
      openMinutes: Formatters.clockToMinutes(_openTime.text),
      closeMinutes: Formatters.clockToMinutes(_closeTime.text),
      maxBreakMinutes: int.tryParse(_maxBreak.text.trim()),
      stalePartialOrderDays: int.tryParse(_staleDays.text.trim()),
    );

    // Reflect what actually stuck (a nonsense value is ignored, not refused).
    _openTime.text = Formatters.minutesToClock(updated.openMinutes);
    _closeTime.text = Formatters.minutesToClock(updated.closeMinutes);
    _maxBreak.text = '${updated.maxBreakMinutes}';
    _staleDays.text = '${updated.stalePartialOrderDays}';

    AppSnackBar.success(context, l10n.storeSettingsSaved);
  }
}
