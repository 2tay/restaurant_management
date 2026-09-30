import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/device_access.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/sync_service.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_notice.dart';

/// An account device whose restaurant data has not arrived yet
/// (SYNC_PLAN.md, Phases 4 and 6): a manager who just joined, or an owner on
/// a second tablet. The first sync downloads the data, this screen counts
/// what arrives, and it gives way to the employee login as soon as an
/// establishment exists locally.
class AccountWaitingPage extends ConsumerStatefulWidget {
  const AccountWaitingPage({super.key});

  @override
  ConsumerState<AccountWaitingPage> createState() => _AccountWaitingPageState();
}

class _AccountWaitingPageState extends ConsumerState<AccountWaitingPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final access = ref.watch(deviceAccessProvider);
    final sync = ref.watch(syncControllerProvider);

    // The data arrived: on to the PIN login.
    ref.listen<DeviceAccess>(deviceAccessProvider, (_, next) {
      if (next.hasLocalData && mounted) context.goSection(Routes.login);
    });

    return AuthLayout(
      title: l10n.waitingTitle,
      children: [
        AuthNotice.info(l10n.waitingBodyNow(access.organizationName ?? '')),
        if (access.accountEmail != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.setupSignedInAs(access.accountEmail!),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (sync.status == SyncStatus.syncing) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.waitingDownloading(sync.received),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ] else if (sync.status == SyncStatus.offline) ...[
          AuthNotice.error(l10n.syncProblemOffline),
        ] else if (sync.status == SyncStatus.error) ...[
          AuthNotice.error(
            sync.problem == SyncOutcome.sessionExpired
                ? l10n.syncProblemSessionExpired
                : sync.problem == SyncOutcome.deviceRemoved
                ? l10n.syncProblemDeviceRemoved
                : l10n.syncProblemFailed,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: l10n.waitingRetry,
          icon: LucideIcons.refreshCw,
          fullWidth: true,
          isBusy: sync.status == SyncStatus.syncing,
          onPressed: sync.status == SyncStatus.syncing || _busy
              ? null
              : () => ref.read(syncControllerProvider.notifier).syncNow(),
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: l10n.accountSignOut,
          icon: LucideIcons.logOut,
          fullWidth: true,
          onPressed: _busy ? null : _signOut,
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await ref.read(deviceAccessProvider.notifier).signOutAccount();
    if (!mounted) return;
    context.goSection(Routes.welcome);
  }
}
