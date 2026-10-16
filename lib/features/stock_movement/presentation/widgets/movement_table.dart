import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'movement_labels.dart';
import 'movement_type_badge.dart' show movementQuantityColor;
import '../../../inventory/presentation/widgets/product_drawer.dart';
import '../../../orders/presentation/widgets/order_detail_view.dart';

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

/// The movement history as a table, in the product table's frame
/// ([DataTableWrapper]): when, which product (with its photo) and the
/// detail, what kind, how much and what it was worth, and who.
///
/// [title] sits at the top left — « Tous les mouvements (128) », « Entrées
/// (12) » — and follows the filters. Entrées, sorties and ajustements stand
/// apart by their coloured badge and quantity, as the product table's status
/// does. Nothing scrolls sideways: the value, the person and the receipt
/// link drop out as the width shrinks.
class MovementTable extends StatelessWidget {
  const MovementTable({
    required this.movements,
    required this.storeId,
    this.title,
    super.key,
  });

  final List<MovementRowView> movements;
  final String storeId;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showValue = width >= 760;
        final showBy = width >= 640;
        final showReceipt = width >= 960;

        return DataTableWrapper(
          title: title,
          minWidth: width,
          scrollable: false,
          columnSpacing: AppSpacing.xl,
          columns: [
            DataColumn(label: Text(l10n.tableColDate)),
            DataColumn(label: Text(l10n.tableColProduct)),
            DataColumn(label: Text(l10n.tableColType)),
            DataColumn(label: Text(l10n.tableColQuantity), numeric: true),
            if (showValue)
              DataColumn(label: Text(l10n.tableColValue), numeric: true),
            if (showBy) DataColumn(label: Text(l10n.tableColBy)),
            if (showReceipt) const DataColumn(label: SizedBox.shrink()),
          ],
          rows: [
            for (final view in movements)
              _row(
                context,
                l10n,
                theme,
                view,
                width: width,
                showValue: showValue,
                showBy: showBy,
                showReceipt: showReceipt,
              ),
          ],
        );
      },
    );
  }

  DataRow _row(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    MovementRowView view, {
    required double width,
    required bool showValue,
    required bool showBy,
    required bool showReceipt,
  }) {
    final movement = view.movement;
    final unit = view.unitAbbreviation;

    return DataRow(
      onSelectChanged: (_) =>
          openProductDrawer(context, storeId: storeId, itemId: movement.itemId),
      cells: [
        // The date leads; the hour sits under it, quieter — a column of
        // movements is read by day first.
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Formatters.date(movement.occurredAt),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
              ),
              Text(
                Formatters.time(movement.occurredAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
        DataCell(
          ConstrainedBox(
            // A long name ellipsizes rather than widening the table.
            constraints: BoxConstraints(
              maxWidth: (width * 0.35).clamp(120.0, 280.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProductImage(
                  imagePath: view.itemImagePath,
                  size: 40,
                  radius: 8,
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Formatters.capitalized(view.itemName),
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
          ),
        ),
        // The cards' type badge, shaped like the employees' role badge.
        DataCell(
          LabelChip(
            label: movementTypeLabel(l10n, movement.type),
            icon: movementTypeIcon(movement.type),
            background: movementColors(movement.type).container,
            foreground: movementColors(movement.type).foreground,
            borderRadius: AppRadius.smAll,
            dense: true,
          ),
        ),
        DataCell(
          Text(
            Formatters.quantityDelta(movement.quantity, unit),
            style: AppTypography.numeric.copyWith(
              fontSize: context.tableFigureSize,
              fontWeight: FontWeight.w700,
              color: movementQuantityColor(movement.type),
            ),
            maxLines: 1,
          ),
        ),
        if (showValue)
          DataCell(
            Text(
              _value(movement),
              style: AppTypography.numeric.copyWith(
                fontSize: context.tableFigureSize,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
            ),
          ),
        if (showBy)
          DataCell(
            Text(
              movement.userName,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (showReceipt)
          DataCell(
            movement.receiptId == null
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () => openReceiptPanel(
                      context,
                      storeId: storeId,
                      receiptId: movement.receiptId!,
                    ),
                    tooltip: l10n.movementViewReceipt,
                    icon: const Icon(
                      LucideIcons.receiptText,
                      size: AppSizing.iconSm,
                    ),
                    color: AppColors.textSecondary,
                  ),
          ),
      ],
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
