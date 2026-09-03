import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
/// [ItemCard]. It covers the name, the category, the rule under them, and the
/// stock line sharing a row with the arrow.
const double itemCardTextHeight = 140;

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

                  // The rule separates what the product *is* from how much of
                  // it there is. They are read at different moments — one to
                  // find the product, the other to decide something about it.
                  const Divider(
                    height: AppSpacing.md,
                    thickness: 1,
                    color: AppColors.hairline,
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.inventoryStockCurrent,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            ItemStockQuantity(view: view, status: status),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ItemActionArrow(onTap: onTap),
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

/// The arrow at the corner of a product card or row.
///
/// It does exactly what tapping the card does — it is an affordance, not a
/// second action. The card is the tap target that matters, so this is allowed
/// to be smaller than [AppSizing.minTapTarget]: missing it hits the card and
/// opens the same product.
class ItemActionArrow extends StatefulWidget {
  const ItemActionArrow({required this.onTap, super.key});

  final VoidCallback onTap;

  static const double _side = 40;

  @override
  State<ItemActionArrow> createState() => _ItemActionArrowState();
}

class _ItemActionArrowState extends State<ItemActionArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).inventoryOpenItem;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.standard,
              width: ItemActionArrow._side,
              height: ItemActionArrow._side,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppColors.primaryContainer
                    : AppColors.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: _hovered ? AppColors.primary600 : AppColors.border,
                ),
              ),
              child: const Icon(
                LucideIcons.arrowRight,
                size: AppSizing.iconSm,
                color: AppColors.primary600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
