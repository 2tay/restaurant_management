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
/// quantity with the small label above it.
///
/// 116dp since the category became a chip and the quantity got back a small
/// « EN STOCK » label above it: a figure set large reads as the card's answer,
/// and the label says which question it answers. It was 108 with « Catégorie : »
/// and « Qté : » inline, and 120 while a 40dp arrow button sat on the quantity's line and
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
const double itemCardTextHeight = 116;

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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // What it is: the name, and its category as a chip — a
                  // tag, not a sentence to read.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Formatters.capitalized(item.name),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs + 2),
                      _CategoryChip(name: view.categoryName),
                    ],
                  ),
                  // How much is left: a small label, then the figure large
                  // and in the colour of its status.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.itemCardQuantityLabel.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ItemStockQuantity(view: view, status: status),
                    ],
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

/// The category as a small neutral pill. Neutral on purpose: the colours on
/// this card belong to the stock status, and a tinted category would compete
/// with them for what the eye reads first.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
