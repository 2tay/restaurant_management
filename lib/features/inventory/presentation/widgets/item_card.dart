import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// The height of a card below its picture.
///
/// Fixed, and the grid adds it to the image height to size each tile — see
/// [ItemCard]. Three lines of text plus the padding around them: name,
/// category, quantity.
const double itemCardTextHeight = 96;

/// One product in the catalogue grid.
///
/// The photo takes the top of the card and the facts sit under it: what it is,
/// how much is left, and whether that is a problem — legible from a step back,
/// which is the distance a cook reads this from.
///
/// **Nothing here flexes.** Two earlier versions both failed on the same
/// point, in opposite directions. Letting the column size itself overflowed a
/// fixed tile by 53 pixels; giving the image `Expanded` instead handed it
/// whatever was left, which on a short tile is *nothing* — a zero-height
/// `Stack` that Flutter cannot hit test, and a stream of "Cannot hit test a
/// render box with no size" every time the pointer crossed it.
///
/// So the text block is a known height ([itemCardTextHeight]), the picture is
/// square, and the grid makes each tile exactly the sum of the two. There is
/// no leftover space to divide up and no way for either part to be squeezed to
/// nothing.
class ItemCard extends StatelessWidget {
  const ItemCard({
    required this.view,
    required this.onTap,
    required this.imageHeight,
    this.selected = false,
    super.key,
  });

  final ItemRowView view;
  final VoidCallback onTap;

  /// The picture's height, which the grid has already sized the tile for.
  final double imageHeight;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = view.item;
    final status = stockStatusOf(item);
    final colors = StockStatusBadge.colorsFor(status);
    final attention = status != StockStatus.inStock;

    return AppCard(
      onTap: onTap,
      selected: selected,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flush to the card's top corners — `AppCard` clips to its own
          // radius — with the status as a band across the foot of the picture
          // rather than a stripe down the card's edge. In a grid the eye lands
          // on the image first, so that is where the one product needing
          // attention has to announce itself.
          SizedBox(
            height: imageHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProductImage(
                  imagePath: item.imagePath,
                  size: double.infinity,
                  radius: 0,
                ),
                if (attention)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: colors.solid,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          StockStatusBadge.labelFor(
                            AppLocalizations.of(context),
                            status,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(
            height: itemCardTextHeight,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        view.categoryName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Text(
                    Formatters.quantityWithUnit(
                      item.quantity,
                      view.unitAbbreviation,
                    ),
                    style: AppTypography.numeric,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
