import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// Which notifications the user wants.
///
/// Price-change alerts are on by default and listed second. They are the least
/// obvious of the four and the one this app exists to provide — a supplier
/// raising a price by forty cents is invisible without them.
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({required this.storeId, super.key});

  final String storeId;

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool _lowStock = true;
  bool _priceChange = true;
  bool _largeAdjustment = true;
  bool _deliveries = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.notificationPrefsTitle,
      subtitle: l10n.notificationPrefsSubtitle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _PreferenceRow(
                icon: LucideIcons.triangleAlert,
                title: l10n.notificationPrefLowStock,
                body: l10n.notificationPrefLowStockBody,
                value: _lowStock,
                onChanged: (value) => setState(() => _lowStock = value),
              ),
              const Divider(height: 1),
              _PreferenceRow(
                icon: LucideIcons.trendingUp,
                title: l10n.notificationPrefPriceChange,
                body: l10n.notificationPrefPriceChangeBody,
                value: _priceChange,
                onChanged: (value) => setState(() => _priceChange = value),
              ),
              const Divider(height: 1),
              _PreferenceRow(
                icon: LucideIcons.clipboardCheck,
                title: l10n.notificationPrefLargeAdjustment,
                body: l10n.notificationPrefLargeAdjustmentBody,
                value: _largeAdjustment,
                onChanged: (value) => setState(() => _largeAdjustment = value),
              ),
              const Divider(height: 1),
              _PreferenceRow(
                icon: LucideIcons.truck,
                title: l10n.notificationPrefDeliveries,
                body: l10n.notificationPrefDeliveriesBody,
                value: _deliveries,
                onChanged: (value) => setState(() => _deliveries = value),
              ),
            ],
          ),
        ),
      ),
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
