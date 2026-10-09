import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/device_access.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/auth_service.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/widgets/auth_notice.dart';

/// The restaurant's account, on the account settings screen
/// (SYNC_PLAN.md, Phase 4).
///
/// In the demo: an invitation to connect a real account. With an account:
/// who is signed in, the join code for a manager and the device list (owner),
/// and signing the account out, which wipes the device.
class RestaurantAccountSection extends ConsumerStatefulWidget {
  const RestaurantAccountSection({super.key});

  @override
  ConsumerState<RestaurantAccountSection> createState() =>
      _RestaurantAccountSectionState();
}

class _RestaurantAccountSectionState
    extends ConsumerState<RestaurantAccountSection> {
  Future<List<DeviceInfo>>? _devices;
  String? _thisDevice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(deviceAccessProvider).isOwnerAccount) _loadDevices();
  }

  void _loadDevices() {
    setState(() {
      _devices = ref.read(accountBackendProvider).devices();
    });
    ref.read(deviceRepositoryProvider).deviceId().then((id) {
      if (mounted) setState(() => _thisDevice = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final access = ref.watch(deviceAccessProvider);

    // Laid straight on the page like the profile above it: a title, then
    // the facts in the field style, then the actions.
    if (!access.isAccount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionTitle(
            title: l10n.accountSectionTitle,
            description: l10n.accountSectionDescription,
          ),
          AdaptiveRow(
            cells: [
              AdaptiveCell(
                flex: 1,
                child: Text(
                  l10n.accountSectionDemo,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              AdaptiveCell(
                child: SecondaryButton(
                  label: l10n.accountConnect,
                  icon: LucideIcons.cloud,
                  tone: SecondaryButtonTone.surface,
                  onPressed: () => context.goSection(Routes.welcome),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionTitle(
          title: l10n.accountSectionTitle,
          description: l10n.accountSectionDescription,
        ),
        FieldGrid(
          children: [
            ReadOnlyValueField(
              label: l10n.syncRestaurantLabel,
              value: access.organizationName ?? '',
              icon: LucideIcons.store,
            ),
            ReadOnlyValueField(
              label: l10n.syncAccountLabel,
              value:
                  '${access.accountEmail ?? ''} · '
                  '${access.isOwnerAccount ? l10n.accountRoleOwner : l10n.accountRoleManager}',
              icon: LucideIcons.mail,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (access.isOwnerAccount)
              SecondaryButton(
                label: l10n.accountInvite,
                icon: LucideIcons.userPlus,
                tone: SecondaryButtonTone.surface,
                onPressed: _busy ? null : _invite,
              ),
            SecondaryButton(
              label: l10n.accountSignOut,
              icon: LucideIcons.logOut,
              tone: SecondaryButtonTone.surface,
              onPressed: _busy ? null : _signOut,
            ),
          ],
        ),
        if (access.isOwnerAccount) ...[
          const SizedBox(height: AppSpacing.xxl),
          SettingsSectionTitle(
            title: l10n.accountDevices,
            description: l10n.accountDevicesDescription,
          ),
          FutureBuilder<List<DeviceInfo>>(
            future: _devices,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  l10n.accountDevicesUnavailable,
                  style: theme.textTheme.bodyMedium,
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              // One card per device, as on the notification settings.
              return ResponsiveCardGrid(
                maxColumns: 2,
                equalRowHeights: true,
                children: [
                  for (final device in snapshot.data!)
                    IconInfoCard(
                      icon: LucideIcons.tablet,
                      title: device.name.isEmpty ? device.id : device.name,
                      value: device.id == _thisDevice
                          ? l10n.accountDeviceThis
                          : l10n.accountDeviceLastSeen(
                              Formatters.date(
                                device.lastSeenAt ?? device.createdAt,
                              ),
                            ),
                      highlighted: device.id == _thisDevice,
                      trailing: device.id == _thisDevice
                          ? null
                          : TextButton(
                              onPressed: () => _remove(device),
                              child: Text(l10n.accountDeviceRemove),
                            ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _invite() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final code = await ref.read(accountBackendProvider).createJoinCode();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.accountInviteTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                '${code.substring(0, 4)}-${code.substring(4)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.accountInviteBody),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Icon(LucideIcons.copy),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.actionClose),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _snack(accountErrorMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(DeviceInfo device) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.accountDeviceRemoveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.accountDeviceRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(accountBackendProvider).removeDevice(device.id);
      if (mounted) _loadDevices();
    } catch (error) {
      if (mounted) _snack(accountErrorMessage(l10n, error));
    }
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final pending = ref.read(pendingChangesProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountSignOutTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.accountSignOutBody),
            if (pending > 0) ...[
              const SizedBox(height: AppSpacing.md),
              AuthNotice.error(l10n.accountSignOutPending(pending)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.accountSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await ref.read(deviceAccessProvider.notifier).signOutAccount();
    if (!mounted) return;
    context.goSection(Routes.welcome);
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
