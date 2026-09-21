import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import 'movement_labels.dart';

/// The movement's type as a small soft badge: its icon and its name, in its
/// colour on a pale tint of it — Entrée green, Sortie red, Ajustement blue.
///
/// The one place a row carries the type's colour, besides the quantity
/// written in the same hue. Enough to pick the entries out of a column at a
/// glance, quiet enough that a table of them still reads as a table: no
/// stripe down the row, no coloured icon disc, no filled block.
class MovementTypeBadge extends StatelessWidget {
  const MovementTypeBadge({required this.type, super.key});

  final StockMovementType type;

  @override
  Widget build(BuildContext context) {
    final colors = movementColors(type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(movementTypeIcon(type), size: 14, color: colors.foreground),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              movementTypeLabel(AppLocalizations.of(context), type),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The colour a movement's quantity is written in: its type's, so the figure
/// and the badge on a row agree.
Color movementQuantityColor(StockMovementType type) =>
    movementColors(type).foreground;
