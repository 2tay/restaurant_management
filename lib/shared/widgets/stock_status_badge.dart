import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'status_pill.dart';

/// The in stock / low stock / out of stock indicator.
///
/// The most important component in the app: it is what the user is scanning for
/// when they walk past the tablet. Three rules it enforces so no call site can
/// get them wrong:
///
/// 1. **Colour is never alone.** Every status carries an icon and a label as
///    well. The app's core signal is red/amber/green and roughly 1 in 12 men
///    has a colour vision deficiency, so a colour-only badge would be unusable
///    for a chunk of any kitchen brigade.
/// 2. **The icons are distinguishable by shape**, not just by colour — a tick,
///    a triangle, a cross read differently in peripheral vision.
/// 3. **The mapping lives here.** Nothing else in the app decides what colour
///    "stock faible" is.
///
/// The pill itself is [StatusPill], shared with the other three status badges
/// so the shape can only be got right or wrong in one place.
class StockStatusBadge extends StatelessWidget {
  const StockStatusBadge({
    required this.status,
    this.compact = false,
    super.key,
  });

  final StockStatus status;

  /// Icon only, with the label moved to a tooltip. For dense table rows where
  /// the surrounding column already says what the number means.
  ///
  /// Use sparingly — the label is what makes this readable at a glance.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(status);
    final icon = iconFor(status);
    final label = labelFor(AppLocalizations.of(context), status);

    return StatusPill(
      colors: colors,
      icon: icon,
      label: label,
      compact: compact,
    );
  }

  static StockStatusColors colorsFor(StockStatus status) => switch (status) {
    StockStatus.inStock => AppColors.inStock,
    StockStatus.lowStock => AppColors.lowStock,
    StockStatus.outOfStock => AppColors.outOfStock,
  };

  static IconData iconFor(StockStatus status) => switch (status) {
    StockStatus.inStock => LucideIcons.circleCheck,
    StockStatus.lowStock => LucideIcons.triangleAlert,
    StockStatus.outOfStock => LucideIcons.circleX,
  };

  static String labelFor(AppLocalizations l10n, StockStatus status) =>
      switch (status) {
        StockStatus.inStock => l10n.stockStatusInStock,
        StockStatus.lowStock => l10n.stockStatusLowStock,
        StockStatus.outOfStock => l10n.stockStatusOutOfStock,
      };
}
