import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';

/// The status of a commande.
///
/// Follows the same rule as the stock badge, for the same reason: **colour is
/// never alone.** Every status carries an icon whose shape differs from the
/// others and a written label, so the list stays readable for someone with a
/// colour vision deficiency and at a glance from across the pass.
///
/// The mapping from status to colour lives here and nowhere else.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({
    required this.status,
    this.compact = false,
    super.key,
  });

  final PurchaseOrderStatus status;

  /// Icon only, label in a tooltip. For dense table rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(status);
    final icon = iconFor(status);
    final label = labelFor(AppLocalizations.of(context), status);

    if (compact) {
      return Tooltip(
        message: label,
        child: Container(
          width: AppSizing.iconLg,
          height: AppSizing.iconLg,
          decoration: BoxDecoration(
            color: colors.container,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: AppSizing.iconSm, color: colors.foreground),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizing.iconSm, color: colors.foreground),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }

  /// Reuses the stock triad rather than inventing a second palette.
  ///
  /// The meanings line up: green for settled, amber for "somebody still has to
  /// do something", red for the dead end. A separate set of order colours would
  /// mean a screen showing both — the item detail does — carrying two colour
  /// languages at once.
  static StockStatusColors colorsFor(PurchaseOrderStatus status) =>
      switch (status) {
        // Neutral rather than tinted: a draft is not a state anything is wrong
        // with, and tinting it would put a fourth colour on the list for no
        // signal.
        PurchaseOrderStatus.draft => _draftColors,
        PurchaseOrderStatus.sent => _sentColors,
        PurchaseOrderStatus.partial => AppColors.lowStock,
        PurchaseOrderStatus.received => AppColors.inStock,
        PurchaseOrderStatus.cancelled => AppColors.outOfStock,
      };

  static const StockStatusColors _draftColors = StockStatusColors(
    solid: AppColors.neutral500,
    foreground: AppColors.textSecondary,
    container: AppColors.surfaceVariant,
  );

  /// Sent is informational, not a warning — the same reasoning as the offline
  /// banner. Nothing is wrong; goods are simply on their way.
  static const StockStatusColors _sentColors = StockStatusColors(
    solid: AppColors.offline,
    foreground: AppColors.steel800,
    container: AppColors.offlineContainer,
  );

  static IconData iconFor(PurchaseOrderStatus status) => switch (status) {
    PurchaseOrderStatus.draft => LucideIcons.filePen,
    PurchaseOrderStatus.sent => LucideIcons.send,
    PurchaseOrderStatus.partial => LucideIcons.packageOpen,
    PurchaseOrderStatus.received => LucideIcons.packageCheck,
    PurchaseOrderStatus.cancelled => LucideIcons.ban,
  };

  static String labelFor(AppLocalizations l10n, PurchaseOrderStatus status) =>
      switch (status) {
        PurchaseOrderStatus.draft => l10n.orderStatusDraft,
        PurchaseOrderStatus.sent => l10n.orderStatusSent,
        PurchaseOrderStatus.partial => l10n.orderStatusPartial,
        PurchaseOrderStatus.received => l10n.orderStatusReceived,
        PurchaseOrderStatus.cancelled => l10n.orderStatusCancelled,
      };
}
