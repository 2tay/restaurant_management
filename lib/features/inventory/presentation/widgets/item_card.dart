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
/// Stated rather than derived, and the grid adds it to the image height to size
/// each tile — see [ItemCard]. It covers the name, the category line and the
/// quantity line.
///
/// 108dp. It was 120 while a 40dp arrow button sat on the quantity's line and
/// set that row's height; the card opens on a tap anywhere, so the arrow was
/// an affordance pretending to be an action, and its twelve points went with
/// it. Before that it was 126 with a "Stock actuel" caption above the figure —
/// a label repeating on every card in a grid of products, where a quantity
/// with its unit needs no introduction.
///
/// It scales with the user's type size: a fixed height clips the last line at
/// 150%, which is where this grid overflowed for anyone who had turned the text
/// up. Capped at 2x so an extreme accessibility setting makes the tiles tall
/// rather than making them a page each.
const double itemCardTextHeight = 108;

/// [itemCardTextHeight] grown for the user's current type size.
double itemCardTextHeightFor(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return itemCardTextHeight * scale.clamp(1.0, 2.0);
}

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
/// So the text block is a known height ([itemCardTextHeight]), the picture's
/// height is handed down by the grid, and the tile is exactly the sum of the
/// two. There is no leftover space to divide up and no way for either part to
/// be squeezed to nothing.
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
    final l10n = AppLocalizations.of(context);
    final item = view.item;
    final status = stockStatusOf(item);

    return AppCard(
      onTap: onTap,
      selected: selected,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flush to the card's top corners — `AppCard` clips to its own
          // radius — with the status as a badge dropped onto the corner of the
          // picture rather than a band across it. In a grid the eye lands on
          // the image first, so that is where the one product needing
          // attention has to announce itself, and a corner badge does that
          // without covering the photograph that makes the card scannable.
          SizedBox(
            height: imageHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProductImage(
                  imagePath: item.imagePath,
                  size: double.infinity,
                  radius: 0,
                  placeholder: ProductImagePlaceholder.disc,
                ),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  // A photo can be any colour, including one close to the
                  // badge's own tint. The hairline keeps the pill's edge
                  // findable whatever is behind it.
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.pillAll,
                      border: Border.all(color: AppColors.white, width: 1.5),
                    ),
                    child: StockStatusBadge(status: status),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: itemCardTextHeightFor(context),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.capitalized(item.name),
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Each figure says what it is: « Catégorie : » and
                  // « Qté : » in muted text before the value.
                  _LabelledLine(
                    label: l10n.itemCardCategoryLabel,
                    child: Text(
                      view.categoryName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _LabelledLine(
                    label: l10n.itemCardQuantityLabel,
                    child: ItemStockQuantity(view: view, status: status),
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

/// The quantity on hand, coloured by what that quantity means.
///
/// The colour is derived from the same [stockStatusOf] the badge above it
/// uses, so the figure and the badge can never disagree — and it is never the
/// only signal, because the badge spells the status out in words.
class ItemStockQuantity extends StatelessWidget {
  const ItemStockQuantity({
    required this.view,
    required this.status,
    this.style,
    super.key,
  });

  final ItemRowView view;
  final StockStatus status;

  /// Defaults to [AppTypography.numericMedium]; the list row asks for the
  /// smaller [AppTypography.numeric] so its line height matches the name.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = StockStatusBadge.colorsFor(status);

    return Text(
      Formatters.quantityWithUnit(view.item.quantity, view.unitAbbreviation),
      style: (style ?? AppTypography.numericMedium).copyWith(
        color: colors.foreground,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// « Catégorie : Légumes » — a muted label, then the value, on one line.
class _LabelledLine extends StatelessWidget {
  const _LabelledLine({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Both give way on the narrowest card, the label too, rather than
        // the line running off the edge.
        Flexible(
          child: Text(
            '$label ',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Flexible(flex: 2, child: child),
      ],
    );
  }
}
