import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'movement_labels.dart';
import 'movement_type_badge.dart';
import '../../../inventory/presentation/widgets/product_drawer.dart';

/// How the movement history is shown.
enum MovementsViewMode { list, table }

class MovementsViewModeNotifier extends Notifier<MovementsViewMode> {
  @override
  MovementsViewMode build() => MovementsViewMode.list;

  void select(MovementsViewMode mode) => state = mode;
}

/// Kept for the session, like the product page's grid/table choice: coming
/// back to the history finds it the way it was left.
final movementsViewModeProvider =
    NotifierProvider<MovementsViewModeNotifier, MovementsViewMode>(
      MovementsViewModeNotifier.new,
    );

/// The movement history as a table: when, which product (with its photo) and
/// the detail, what kind, how much and what it was worth, and who.
///
/// Entrées, sorties and ajustements stand apart at a glance: each row's
/// type is a small soft badge in its colour, and its quantity is written in
/// the same colour. Nothing else is tinted — no stripe, no coloured icon — so
/// the table still reads as a table. On a narrow screen the value, the person and the receipt link drop
/// out before anything scrolls sideways.
class MovementTable extends StatelessWidget {
  const MovementTable({
    required this.movements,
    required this.storeId,
    super.key,
  });

  final List<MovementRowView> movements;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppTable<MovementRowView>(
      rows: movements,
      shrinkWrap: true,
      onRowTap: (view) => openProductDrawer(
        context,
        storeId: storeId,
        itemId: view.movement.itemId,
      ),
      columns: [
        AppTableColumn(label: l10n.tableColDate, width: 150),
        AppTableColumn(label: l10n.tableColProduct, flex: 3),
        AppTableColumn(label: l10n.tableColType, width: 140),
        AppTableColumn(label: l10n.tableColQuantity, width: 120, numeric: true),
        AppTableColumn(
          label: l10n.tableColValue,
          width: 112,
          numeric: true,
          minTableWidth: 780,
        ),
        AppTableColumn(label: l10n.tableColBy, flex: 2, minTableWidth: 660),
        const AppTableColumn(label: '', width: 56, minTableWidth: 960),
      ],
      cell: (context, view, column) {
        final movement = view.movement;
        final unit = view.unitAbbreviation;

        return switch (column) {
          0 => Text(
            Formatters.dateTime(movement.occurredAt),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          1 => Row(
            children: [
              ProductImage(imagePath: view.itemImagePath, size: 36, radius: 8),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.itemName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      movementDescription(
                        l10n,
                        movement,
                        view.supplierName ?? '—',
                        orderReference: view.orderReference,
                        unit: unit,
                        withType: false,
                      ),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          2 => MovementTypeBadge(type: movement.type),
          3 => Text(
            Formatters.quantityDelta(movement.quantity, unit),
            style: AppTypography.numeric.copyWith(
              fontWeight: FontWeight.w700,
              color: movementQuantityColor(movement.type),
            ),
            maxLines: 1,
          ),
          4 => Text(
            _value(movement),
            style: AppTypography.numeric.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
          ),
          5 => Text(
            movement.userName,
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _ =>
            movement.receiptId == null
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () => context.pushScreen(
                      Routes.toReceipt(storeId, movement.receiptId!),
                    ),
                    tooltip: l10n.movementViewReceipt,
                    icon: const Icon(
                      LucideIcons.receiptText,
                      size: AppSizing.iconSm,
                    ),
                    color: AppColors.textSecondary,
                  ),
        };
      },
    );
  }

  /// What the stock that moved was worth, or a dash when no cost is known —
  /// the same rule as the card: blank rather than a zero that reads as free.
  static String _value(StockMovement movement) {
    final unitValue = movement.unitCost ?? movement.unitPrice;
    if (unitValue == null) return '—';
    return Formatters.price(unitValue * movement.quantity.abs());
  }
}
