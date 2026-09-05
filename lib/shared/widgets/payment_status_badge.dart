import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'status_pill.dart';

/// Whether a worked day has been settled by a payroll run — built the same way
/// [AttendanceStatusBadge] is, so the two rules every status badge in the app
/// follows hold here too:
///
/// 1. **Colour is never alone.** Each status carries an icon and a label.
/// 2. **The icons differ by shape**, not just by colour.
///
/// Colours are reused from the existing palette: paid → the "in stock" green,
/// unpaid → the "low stock" amber (an item still needing attention).
class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({required this.status, super.key});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(status);

    return StatusPill(
      colors: colors,
      icon: iconFor(status),
      label: paymentStatusLabel(AppLocalizations.of(context), status),
    );
  }

  static StockStatusColors colorsFor(PaymentStatus status) => switch (status) {
    PaymentStatus.paid => AppColors.inStock,
    PaymentStatus.unpaid => AppColors.lowStock,
  };

  static IconData iconFor(PaymentStatus status) => switch (status) {
    PaymentStatus.paid => LucideIcons.circleCheck,
    PaymentStatus.unpaid => LucideIcons.hourglass,
  };
}

/// Shared status naming, so every screen that shows a [PaymentStatus] agrees
/// on the wording. Lives beside the badge, mirroring [AttendanceStatusBadge].
String paymentStatusLabel(AppLocalizations l10n, PaymentStatus status) =>
    switch (status) {
      PaymentStatus.paid => l10n.paymentStatusPaid,
      PaymentStatus.unpaid => l10n.paymentStatusUnpaid,
    };
