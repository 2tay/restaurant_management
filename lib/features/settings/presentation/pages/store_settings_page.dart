import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// The four settings tabs, built the same way on all four screens.
List<SectionTab> settingsTabs(AppLocalizations l10n, String storeId) => [
  SectionTab(
    label: l10n.settingsTabStore,
    path: Routes.toStoreSettings(storeId),
  ),
  SectionTab(
    label: l10n.settingsTabAccount,
    path: Routes.toAccountSettings(storeId),
  ),
  SectionTab(
    label: l10n.settingsTabNotifications,
    path: Routes.toNotificationSettings(storeId),
  ),
  SectionTab(label: l10n.settingsTabSync, path: Routes.toSyncStatus(storeId)),
];

/// Store name, address and preferences.
///
/// Split in two: this resolves the establishment and its units, and
/// [_StoreSettingsForm] owns the controllers. A form whose fields are filled
/// from a query cannot be one widget, because `initState` runs before the
/// answer arrives — and filling controllers during `build` would write to them
/// while their fields are being laid out.
class StoreSettingsPage extends ConsumerWidget {
  const StoreSettingsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = asyncAll3(
      ref.watch(storeProvider(storeId)),
      ref.watch(unitsProvider(storeId)),
      ref.watch(stalePartialOrderDaysProvider(storeId)),
      (store, units, staleDays) => (
        store: store,
        units: units,
        staleDays: staleDays,
      ),
    );

    return AsyncContent<({Store? store, List<UnitOfMeasure> units, int staleDays})>(
      value: data,
      onRetry: () {
        ref.invalidate(storeProvider(storeId));
        ref.invalidate(unitsProvider(storeId));
        ref.invalidate(stalePartialOrderDaysProvider(storeId));
      },
      // The chrome is drawn either way, so the tabs and the title do not
      // arrive a frame after the page they belong to.
      skeleton: ShellPage(
        tabs: SectionTabs(
          currentPath: Routes.toStoreSettings(storeId),
          tabs: settingsTabs(l10n, storeId),
        ),
        title: l10n.storeSettingsTitle,
        child: const SkeletonList(rows: 3, rowHeight: 180),
      ),
      builder: (context, data) {
        final store = data.store;
        if (store == null) {
          return ShellPage(
            tabs: SectionTabs(
              currentPath: Routes.toStoreSettings(storeId),
              tabs: settingsTabs(l10n, storeId),
            ),
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
          staleDays: data.staleDays,
        );
      },
    );
  }
}

class _StoreSettingsForm extends ConsumerStatefulWidget {
  const _StoreSettingsForm({
    required this.store,
    required this.units,
    required this.staleDays,
    super.key,
  });

  final Store store;
  final List<UnitOfMeasure> units;
  final int staleDays;

  @override
  ConsumerState<_StoreSettingsForm> createState() => _StoreSettingsFormState();
}

class _StoreSettingsFormState extends ConsumerState<_StoreSettingsForm> {
  late final _name = TextEditingController(text: widget.store.name);
  late final _address = TextEditingController(text: widget.store.addressLine);
  late final _postalCode = TextEditingController(text: widget.store.postalCode);
  late final _city = TextEditingController(text: widget.store.city);
  late final _phone = TextEditingController(text: widget.store.phone);
  late final _staleDays = TextEditingController(text: '${widget.staleDays}');

  /// Which unit a new article starts with. Local to this screen: there is no
  /// column behind it, because "the unit the form pre-selects" is a convenience
  /// rather than a fact about the establishment.
  late String? _defaultUnitId = widget.units.isEmpty
      ? null
      : widget.units.first.id;

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
    final storeId = widget.store.id;

    return ShellPage(
      tabs: SectionTabs(
        currentPath: Routes.toStoreSettings(storeId),
        tabs: settingsTabs(l10n, storeId),
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
                  for (final unit in widget.units)
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
          ],
        ),
      ),
    );
  }

  /// Saves the establishment and the stale-order threshold.
  ///
  /// The threshold was a mutable global in Phase 1 and is a column now, so a
  /// number typed here survives closing the app — which is the only way the
  /// dashboard warning it drives can be demonstrated properly.
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final stores = ref.read(storeRepositoryProvider);

    await stores.updateStore(
      widget.store.id,
      name: _name.text,
      addressLine: _address.text,
      postalCode: _postalCode.text,
      city: _city.text,
      phone: _phone.text,
    );

    final days = int.tryParse(_staleDays.text.trim());
    if (days != null && days > 0) {
      await stores.setStalePartialOrderDays(widget.store.id, days);
    } else {
      // Falling back rather than refusing: an empty or nonsense value should
      // restore the default, not leave the dashboard with no threshold at all.
      // The repository refuses a non-positive number, so the decision about
      // what nonsense means belongs here, in the form that accepted it.
      await stores.setStalePartialOrderDays(
        widget.store.id,
        OrderRules.defaultStalePartialDays,
      );
      _staleDays.text = '${OrderRules.defaultStalePartialDays}';
    }

    if (!mounted) return;
    AppSnackBar.success(context, l10n.storeSettingsSaved);
  }
}
