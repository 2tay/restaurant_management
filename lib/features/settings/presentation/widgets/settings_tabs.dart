import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// The four settings tabs, the same on all four screens.
///
/// A widget rather than a list builder so the sync tab can carry its dot:
/// offline, or with changes waiting, is worth seeing from any settings screen
/// rather than only from the one that explains it.
class SettingsTabs extends ConsumerWidget {
  const SettingsTabs({
    required this.storeId,
    required this.currentPath,
    super.key,
  });

  final String storeId;

  /// The route of the settings screen showing these tabs.
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final syncNeedsAttention =
        ref.watch(offlineModeProvider) || ref.watch(pendingChangesProvider) > 0;

    return SectionTabs(
      currentPath: currentPath,
      tabs: [
        SectionTab(
          label: l10n.settingsTabStore,
          description: l10n.settingsTabStoreHint,
          icon: LucideIcons.store,
          path: Routes.toStoreSettings(storeId),
        ),
        SectionTab(
          label: l10n.settingsTabAccount,
          description: l10n.settingsTabAccountHint,
          icon: LucideIcons.userRound,
          path: Routes.toAccountSettings(storeId),
        ),
        SectionTab(
          label: l10n.settingsTabNotifications,
          description: l10n.settingsTabNotificationsHint,
          icon: LucideIcons.bell,
          path: Routes.toNotificationSettings(storeId),
        ),
        SectionTab(
          label: l10n.settingsTabSync,
          description: l10n.settingsTabSyncHint,
          icon: LucideIcons.refreshCw,
          attention: syncNeedsAttention ? l10n.settingsTabSyncAttention : null,
          path: Routes.toSyncStatus(storeId),
        ),
      ],
    );
  }
}
