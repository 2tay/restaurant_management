import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
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
/// each tile — see [ItemCard]. It covers the identity block (the category's
/// icon, the name, the category and the status pill) and the « Stock actuel »
/// panel under it.
///
/// 172dp since the card took the panel layout: the quantity sits in its own
/// tinted panel across the card's width, labelled « Stock actuel », rather
/// than as a bare figure. It was 116 with the figure inline. The panel carries
/// no action — the « Alerter » button of the mock-up is left out, and the
/// figure takes the room it would have had.
///
/// It scales with the user's type size: a fixed height clips the last line at
/// 150%, which is where this grid overflowed for anyone who had turned the text
/// up. Capped at 2x so an extreme accessibility setting makes the tiles tall
/// rather than making them a page each.
const double itemCardTextHeight = 172;

/// [itemCardTextHeight] grown for the user's current type size.
double itemCardTextHeightFor(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return itemCardTextHeight * scale.clamp(1.0, 2.0);
}

/// Below this card width the category's round icon beside the name goes: on a
/// two-column phone grid it would leave the name a hundred dp.
const double _identityIconMinWidth = 200;

/// One product in the catalogue grid.
///
/// The photo takes the top of the card, with the stock status pinned to its
/// top-left corner, the product's menu at the top-right and its category at
/// the bottom-left. Under it: what the product is, then how much is left, in
/// a panel of its own and in the colour of its status — legible from a step
/// back, which is the distance a cook reads this from.
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
    final item = view.item;
    final status = stockStatusOf(item);
    final categoryIcon = categoryIconFor(view.categoryName);

    return AppCard(
      onTap: onTap,
      selected: selected,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flush to the card's top corners — `AppCard` clips to its own
          // radius. In a grid the eye lands on the image first, so that is
          // where the one product needing attention announces itself: the
          // status as a badge on the corner rather than a band across it.
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
                  right: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
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
                ),
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: _CardMenu(view: view, onOpen: onTap),
                ),
                Positioned(
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _CategoryTag(
                      name: view.categoryName,
                      icon: categoryIcon,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: itemCardTextHeightFor(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md + 2,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Identity(view: view, status: status, icon: categoryIcon),
                  _StockPanel(view: view, status: status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The category's round icon, the name, the category, and the status pill.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.view,
    required this.status,
    required this.icon,
  });

  final ItemRowView view;
  final StockStatus status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Formatters.capitalized(view.item.name),
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          view.categoryName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        // The status in words, as a quiet pill: the badge on the photo is the
        // alarm, this is the line a person reads.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.pillAll,
          ),
          child: Text(
            _statusWord(l10n, status).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _identityIconMinWidth) return text;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppSizing.iconSm,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: text),
          ],
        );
      },
    );
  }

  static String _statusWord(AppLocalizations l10n, StockStatus status) =>
      switch (status) {
        StockStatus.outOfStock => l10n.alertsPriorityOut,
        StockStatus.lowStock => l10n.alertsPriorityLow,
        StockStatus.inStock => l10n.itemCardQuantityLabel,
      };
}

/// « Stock actuel » over the quantity, in a tinted panel across the card —
/// the figure in the colour of its status, so an empty shelf reads red.
class _StockPanel extends StatelessWidget {
  const _StockPanel({required this.view, required this.status});

  final ItemRowView view;
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.package,
            size: AppSizing.iconMd,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.inventoryStockCurrent,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                ItemStockQuantity(
                  view: view,
                  status: status,
                  style: AppTypography.numeric.copyWith(
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The category on the photo: a dark translucent pill with its icon in a
/// round seat, readable over any picture.
class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.name, required this.icon});

  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 2, AppSpacing.md, 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: AppColors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.white,
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

enum _CardAction { open, edit, movements }

/// The ⋮ on the photo: the product, its form, its movements.
class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.view, required this.onOpen});

  final ItemRowView view;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = view.item;

    PopupMenuItem<_CardAction> entry(
      _CardAction value,
      IconData icon,
      String label,
    ) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: AppSizing.iconSm, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Text(label),
        ],
      ),
    );

    return PopupMenuButton<_CardAction>(
      tooltip: l10n.itemMoreActions,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (action) => switch (action) {
        _CardAction.open => onOpen(),
        _CardAction.edit => context.pushScreen(
          Routes.toEditItem(item.storeId, item.id),
        ),
        _CardAction.movements => context.pushScreen(
          Routes.toMovements(item.storeId, itemId: item.id),
        ),
      },
      itemBuilder: (context) => [
        entry(
          _CardAction.open,
          LucideIcons.packageSearch,
          l10n.alertsOpenProduct,
        ),
        entry(_CardAction.edit, LucideIcons.pencil, l10n.editItemTitle),
        entry(
          _CardAction.movements,
          LucideIcons.history,
          l10n.alertsViewMovements,
        ),
      ],
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          LucideIcons.ellipsis,
          size: AppSizing.iconSm,
          color: AppColors.white,
        ),
      ),
    );
  }
}

/// An icon for a category, read from its name — categories are free text,
/// so the common restaurant ones are recognised and the rest get a box.
IconData categoryIconFor(String categoryName) {
  final name = categoryName.toLowerCase();
  bool has(List<String> words) => words.any(name.contains);

  if (has(['légume', 'legume', 'fruit'])) return LucideIcons.carrot;
  if (has(['viande', 'boucher', 'volaille'])) return LucideIcons.beef;
  if (has(['poisson', 'mer', 'fruits de mer'])) return LucideIcons.fish;
  if (has(['laitier', 'fromage', 'lait', 'crèmerie'])) return LucideIcons.milk;
  if (has(['boulang', 'pain', 'pâtisser', 'viennois'])) {
    return LucideIcons.croissant;
  }
  if (has(['vin', 'alcool', 'spiritueux'])) return LucideIcons.wine;
  if (has(['bière', 'biere'])) return LucideIcons.beer;
  if (has(['boisson', 'soda', 'jus', 'eau'])) return LucideIcons.cupSoda;
  if (has(['surgel', 'congel'])) return LucideIcons.snowflake;
  if (has(['épice', 'epice', 'condiment', 'herbe'])) return LucideIcons.leaf;
  if (has(['œuf', 'oeuf'])) return LucideIcons.egg;
  if (has(['céréale', 'farine', 'riz', 'pâte', 'épicerie'])) {
    return LucideIcons.wheat;
  }
  if (has(['entretien', 'nettoy', 'hygiène', 'produit d'])) {
    return LucideIcons.sprayCan;
  }
  if (has(['voiture', 'véhicule'])) return LucideIcons.car;
  return LucideIcons.package;
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
