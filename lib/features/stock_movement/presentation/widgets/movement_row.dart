import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'movement_labels.dart';
import 'movement_type_badge.dart';

/// One entry in the movement history.
///
/// The product's photo leads, then what moved and why. The type — Entrée
/// green, Sortie red, Ajustement blue — is a small soft badge with its icon
/// and name, and the quantity is written in the same colour: two cues that
/// agree, so entries and exits stand apart at a glance, with nothing else on
/// the card tinted.
class MovementRow extends StatelessWidget {
  const MovementRow({required this.view, this.storeId, this.onTap, super.key});

  final MovementRowView view;

  /// Needed to link back to the receipt. Omitted where the row is decorative.
  final String? storeId;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final movement = view.movement;
    final parts = _Parts(
      icon: ProductImage(imagePath: view.itemImagePath, size: 40, radius: 8),
      pill: MovementTypeBadge(type: movement.type),
      description: Text(
        movementDescription(
          l10n,
          movement,
          view.supplierName ?? '—',
          orderReference: view.orderReference,
          unit: view.unitAbbreviation,
          withType: false,
        ),
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      quantity: Text(
        Formatters.quantityDelta(movement.quantity, view.unitAbbreviation),
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.numeric.copyWith(
          fontWeight: FontWeight.w700,
          color: movementQuantityColor(movement.type),
        ),
      ),
      value: _valueLabel(movement),
      // Closes the trail in the other direction: from a quantity on the
      // shelf back to the delivery, the order, and the supplier.
      receipt: movement.receiptId != null && storeId != null
          ? IconButton(
              onPressed: () => context.pushScreen(
                Routes.toReceipt(storeId!, movement.receiptId!),
              ),
              tooltip: l10n.movementViewReceipt,
              icon: const Icon(LucideIcons.receiptText),
              color: AppColors.textSecondary,
              constraints: const BoxConstraints(
                minWidth: AppSizing.minTapTarget,
                minHeight: AppSizing.minTapTarget,
              ),
            )
          : null,
    );

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: context.isPhone ? _phone(context, parts) : _wide(context, parts),
    );
  }

  /// A phone has no room for four columns: the name and the quantity share
  /// the top line, and what, when and who stack under it.
  Widget _phone(BuildContext context, _Parts parts) {
    final theme = Theme.of(context);
    final movement = view.movement;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        parts.icon,
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      view.itemName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  parts.quantity,
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Flexible(child: parts.pill),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: parts.description),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${movement.userName} · '
                      '${Formatters.dateTime(movement.occurredAt)}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (parts.value.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(parts.value, style: AppTypography.numericSmall),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (parts.receipt != null) parts.receipt!,
      ],
    );
  }

  Widget _wide(BuildContext context, _Parts parts) {
    final theme = Theme.of(context);
    final movement = view.movement;

    return Row(
      children: [
        parts.icon,
        const SizedBox(width: AppSpacing.md),

        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                view.itemName,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Flexible(child: parts.pill),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: parts.description),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),

        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Formatters.dateTime(movement.occurredAt),
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      movement.userName,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),

        // What the stock that moved was worth.
        //
        // A delivery falls back to the price paid, which is the same figure;
        // everything else uses the cost recorded on the movement, so a line
        // of waste finally reads in euros as well as in kilos. Movements
        // seeded before costs existed carry neither and stay blank rather
        // than showing a zero that would read as free.
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              parts.value,
              style: AppTypography.numericSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ),
        if (parts.receipt != null) ...[
          parts.receipt!,
          const SizedBox(width: AppSpacing.sm),
        ],

        const SizedBox(width: AppSpacing.md),

        SizedBox(width: 110, child: parts.quantity),
      ],
    );
  }

  /// What the stock this movement moved was worth, or blank if unknown.
  ///
  /// [StockMovement.unitCost] is preferred over [StockMovement.unitPrice]
  /// because it is the figure that entered the stock and it is present on every
  /// kind of movement, not only on deliveries.
  static String _valueLabel(StockMovement movement) {
    final unitValue = movement.unitCost ?? movement.unitPrice;
    if (unitValue == null) return '';
    return Formatters.price(unitValue * movement.quantity.abs());
  }
}

/// The pieces of a row, built once and arranged by whichever layout fits.
class _Parts {
  const _Parts({
    required this.icon,
    required this.pill,
    required this.description,
    required this.quantity,
    required this.value,
    required this.receipt,
  });

  final Widget icon;
  final Widget pill;
  final Widget description;
  final Widget quantity;
  final String value;
  final Widget? receipt;
}
