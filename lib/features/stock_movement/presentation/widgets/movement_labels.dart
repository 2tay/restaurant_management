import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
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

/// The one colour per movement type, used by the history rows, the type
/// chips and the entry forms alike.
///
/// Green in, red out, blue for a count: a column of rows reads by colour from
/// across the kitchen, and the icon and label beside it keep it readable for
/// anyone who cannot tell the two apart.
StockStatusColors movementColors(StockMovementType type) => switch (type) {
  StockMovementType.stockIn => AppColors.inStock,
  StockMovementType.stockOut => AppColors.outOfStock,
  StockMovementType.adjustment => AppColors.info,
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
///
/// An adjustment reads as the count it records — "Compté 31 kg — prévu 40 kg"
/// — when both figures are on the movement, because that is the useful record
/// and the bare word "Ajustement" is not.
///
/// [withType] false drops the leading type word, for a row that already shows
/// the type as a pill beside it.
String movementDescription(
  AppLocalizations l10n,
  StockMovement movement,
  String supplierName, {
  String? orderReference,
  String unit = '',
  bool withType = true,
}) {
  return switch (movement.type) {
    StockMovementType.stockIn =>
      orderReference != null
          ? '${l10n.movementFromOrder(orderReference)} — $supplierName'
          : withType
          ? '${l10n.movementTypeIn} — $supplierName'
          : supplierName,
    StockMovementType.stockOut =>
      movement.reason == null
          ? l10n.movementTypeOut
          : reasonLabel(l10n, movement.reason!),
    StockMovementType.adjustment =>
      movement.systemQuantity == null || movement.countedQuantity == null
          ? l10n.movementTypeAdjustment
          : l10n.movementCountedOf(
              Formatters.quantityWithUnit(movement.countedQuantity!, unit),
              Formatters.quantityWithUnit(movement.systemQuantity!, unit),
            ),
  };
}

/// The colour a signed quantity is written in: green when stock went up, red
/// when it went down, whatever kind of movement moved it. An adjustment of −9
/// is a loss and should read as one.
Color quantityDeltaColor(double quantity) => quantity > 0
    ? AppColors.inStock.foreground
    : quantity < 0
    ? AppColors.outOfStock.foreground
    : AppColors.textSecondary;
