import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';

/// Plain-language names and icons for movement types and reasons.
///
/// Centralised so "Perte" means the same thing and looks the same on the
/// history list, the stock-out form and the usage report. The brief is explicit
/// about the wording: "Ajouter une livraison", not "Create Stock Ingress
/// Record".

String movementTypeLabel(AppLocalizations l10n, StockMovementType type) =>
    switch (type) {
      StockMovementType.stockIn => l10n.movementTypeIn,
      StockMovementType.stockOut => l10n.movementTypeOut,
      StockMovementType.adjustment => l10n.movementTypeAdjustment,
    };

IconData movementTypeIcon(StockMovementType type) => switch (type) {
  StockMovementType.stockIn => LucideIcons.arrowDownToLine,
  StockMovementType.stockOut => LucideIcons.arrowUpFromLine,
  StockMovementType.adjustment => LucideIcons.clipboardCheck,
};

String reasonLabel(AppLocalizations l10n, StockOutReason reason) =>
    switch (reason) {
      StockOutReason.sale => l10n.reasonSale,
      StockOutReason.waste => l10n.reasonWaste,
      StockOutReason.spoilage => l10n.reasonSpoilage,
      StockOutReason.transfer => l10n.reasonTransfer,
    };

IconData reasonIcon(StockOutReason reason) => switch (reason) {
  StockOutReason.sale => LucideIcons.receipt,
  StockOutReason.waste => LucideIcons.trash2,
  StockOutReason.spoilage => LucideIcons.ban,
  StockOutReason.transfer => LucideIcons.truck,
};

/// One-line description of a movement, for history rows.
///
/// A delivery received against a commande says so, and names it. Two entry
/// paths land in this one log — somebody checking in an ordered delivery, and
/// somebody who ran to the market and bought 5 kg of tomatoes — and the row has
/// to make clear which is which without the user opening it.
String movementDescription(
  AppLocalizations l10n,
  StockMovement movement,
  String supplierName, {
  String? orderReference,
}) {
  return switch (movement.type) {
    StockMovementType.stockIn =>
      orderReference == null
          ? '${l10n.movementTypeIn} — $supplierName'
          : '${l10n.movementFromOrder(orderReference)} — $supplierName',
    StockMovementType.stockOut =>
      movement.reason == null
          ? l10n.movementTypeOut
          : reasonLabel(l10n, movement.reason!),
    StockMovementType.adjustment => l10n.movementTypeAdjustment,
  };
}
