import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/settings_tabs.dart';

/// Which notifications the user wants.
///
/// Price-change alerts are on by default and listed second. They are the least
/// obvious of the four and the one this app exists to provide — a supplier
/// raising a price by forty cents is invisible without them.
///
/// Every switch writes straight to the establishment and the screen redraws
/// from the stream it just wrote to. Until the notifications became real these
/// four lived in a `setState` that nothing read and nothing saved: the screen
/// looked like a setting and was a decoration.
class NotificationPreferencesPage extends ConsumerWidget {
  const NotificationPreferencesPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncSettings = ref.watch(storeSettingsProvider(storeId));

    return ShellPage(
      tabs: SettingsTabs(
        storeId: storeId,
        currentPath: Routes.toNotificationSettings(storeId),
      ),
      sideTabsOnWide: true,
      title: l10n.notificationPrefsTitle,
      subtitle: l10n.notificationPrefsSubtitle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: AsyncContent<StoreSettings>(
          value: asyncSettings,
          onRetry: () => ref.invalidate(storeSettingsProvider(storeId)),
          builder: (context, settings) => AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _PreferenceRow(
                  icon: LucideIcons.triangleAlert,
                  title: l10n.notificationPrefLowStock,
                  body: l10n.notificationPrefLowStockBody,
                  value: settings.notifyLowStock,
                  onChanged: (value) => _save(ref, lowStock: value),
                ),
                const Divider(height: 1),
                _PreferenceRow(
                  icon: LucideIcons.trendingUp,
                  title: l10n.notificationPrefPriceChange,
                  body: l10n.notificationPrefPriceChangeBody,
                  value: settings.notifyPriceChange,
                  onChanged: (value) => _save(ref, priceChange: value),
                ),
                const Divider(height: 1),
                _PreferenceRow(
                  icon: LucideIcons.clipboardCheck,
                  title: l10n.notificationPrefLargeAdjustment,
                  body: l10n.notificationPrefLargeAdjustmentBody,
                  value: settings.notifyLargeAdjustment,
                  onChanged: (value) => _save(ref, largeAdjustment: value),
                ),
                const Divider(height: 1),
                _PreferenceRow(
                  icon: LucideIcons.truck,
                  title: l10n.notificationPrefDeliveries,
                  body: l10n.notificationPrefDeliveriesBody,
                  value: settings.notifyDeliveries,
                  onChanged: (value) => _save(ref, deliveries: value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One switch at a time, so a screen left open on another tablet cannot
  /// revert a change it never saw.
  void _save(
    WidgetRef ref, {
    bool? lowStock,
    bool? priceChange,
    bool? largeAdjustment,
    bool? deliveries,
  }) {
    ref
        .read(storeRepositoryProvider)
        .setNotificationPreference(
          storeId,
          lowStock: lowStock,
          priceChange: priceChange,
          largeAdjustment: largeAdjustment,
          deliveries: deliveries,
        );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      // The whole row toggles, not just the switch — a 40dp switch is a small
      // target for someone in a hurry.
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.primaryContainer
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppSizing.iconMd,
                color: value
                    ? AppColors.onPrimaryContainer
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
