import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'product_wizard_dialog.dart';

/// The height of a product card, before the user's type size.
///
/// Stated rather than derived, and the grid uses it as each tile's height —
/// see [ItemCard]. It covers the top row (the photo beside the name, the
/// category and « Stock actuel »), the supplier / category row, and the
/// Qté min / Qté max footer.
const double itemCardHeight = 236;

/// [itemCardHeight] grown for the user's current type size.
///
/// A fixed height clips the last line at 150%, so it scales — capped at 2x so
/// an extreme accessibility setting makes the tiles tall rather than making
/// them a page each.
double itemCardHeightFor(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return itemCardHeight * scale.clamp(1.0, 2.0);
}

/// The photo's largest side: the top row is usually shorter, and then the
/// photo is as tall as the row.
const double _photoMaxSide = 112;

/// One product in the catalogue grid, laid out like the mock-up:
///
/// - **Top:** the photo on the left; on the right the category's round icon,
///   the name and the category, the ⋮ menu, then « Stock actuel » over the
///   quantity — in the colour of its status, legible from a step back — with
///   the status pill beside it.
/// - **Middle:** the default supplier and the category, each beside a round
///   icon, split by a hairline.
/// - **Footer:** the minimum and the maximum quantity, and a chevron that says
///   the card opens.
///
/// **Nothing here sizes itself.** The grid hands every tile
/// [itemCardHeightFor]; the top row takes what the fixed middle and footer
/// leave, and the photo is as tall as that row (at most [_photoMaxSide]).
class ItemCard extends ConsumerWidget {
  const ItemCard({
    required this.view,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final ItemRowView view;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final item = view.item;
    final status = stockStatusOf(item);
    final categoryIcon = categoryIconFor(view.categoryName);

    String? supplierName;
    final suppliers = ref.watch(suppliersProvider(item.storeId)).value;
    for (final s in suppliers ?? const <Supplier>[]) {
      if (s.id == item.defaultSupplierId) supplierName = s.name;
    }

    return AppCard(
      onTap: onTap,
      selected: selected,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md + 2,
        AppSpacing.md + 2,
        AppSpacing.md + 2,
        AppSpacing.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TopRow(
              view: view,
              status: status,
              categoryIcon: categoryIcon,
              onOpen: onTap,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FactsRow(
            facts: [
              (
                LucideIcons.truck,
                supplierName ?? l10n.itemDefaultSupplierNone,
                l10n.inventoryFilterSupplier,
              ),
              (categoryIcon, view.categoryName, l10n.inventoryFilterCategory),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm + 2),
          _LimitsFooter(view: view),
        ],
      ),
    );
  }
}

/// The photo, then who the product is and how much of it is left.
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.view,
    required this.status,
    required this.categoryIcon,
    required this.onOpen,
  });

  final ItemRowView view;
  final StockStatus status;
  final IconData categoryIcon;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxHeight.clamp(0.0, _photoMaxSide);
        // On a very narrow card the photo would leave the name nothing.
        final showPhoto = constraints.maxWidth - side >= 150;

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoundIcon(icon: categoryIcon, size: 36, tinted: true),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
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
                ),
                _CardMenu(view: view, onOpen: onOpen),
              ],
            ),
            const Spacer(),
            Text(
              l10n.inventoryStockCurrent,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Expanded(
                  child: ItemStockQuantity(
                    view: view,
                    status: status,
                    style: AppTypography.numeric.copyWith(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: StockStatusBadge(status: status)),
              ],
            ),
          ],
        );

        if (!showPhoto) return details;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(
              imagePath: view.item.imagePath,
              size: side,
              radius: 14,
              placeholder: ProductImagePlaceholder.disc,
            ),
            const SizedBox(width: AppSpacing.md + 2),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

/// Two facts side by side — a round icon, the value in bold, its caption
/// under it — split by a hairline.
class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.facts});

  /// Icon, value, caption.
  final List<(IconData, String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget fact((IconData, String, String) f) => Row(
      children: [
        _RoundIcon(icon: f.$1, size: 34),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                f.$2,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                f.$3,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, f) in facts.indexed) ...[
            if (i > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: fact(f)),
          ],
        ],
      ),
    );
  }
}

/// The footer: Qté min and Qté max, then the chevron.
class _LimitsFooter extends StatelessWidget {
  const _LimitsFooter({required this.view});

  final ItemRowView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final unit = view.unitAbbreviation;

    Widget limit(IconData icon, String label, double value) => Row(
      children: [
        Icon(icon, size: AppSizing.iconSm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs + 2),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: '$label  ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              children: [
                TextSpan(
                  text: Formatters.quantityWithUnit(value, unit),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Row(
      children: [
        Expanded(
          child: limit(
            LucideIcons.arrowDownToLine,
            l10n.itemCardQtyMin,
            view.item.lowStockThreshold,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: limit(
            LucideIcons.arrowUpToLine,
            l10n.itemCardQtyMax,
            view.item.maxStock,
          ),
        ),
        const Icon(
          LucideIcons.chevronRight,
          size: AppSizing.iconSm,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

/// An icon in a round seat — green-tinted for the category beside the name,
/// as in the mock-up, grey elsewhere.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.size,
    this.tinted = false,
  });

  final IconData icon;
  final double size;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tinted ? AppColors.primaryContainer : AppColors.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: AppSizing.iconSm,
        color: tinted ? AppColors.primary600 : AppColors.textSecondary,
      ),
    );
  }
}

enum _CardAction { open, edit, movements }

/// The ⋮ beside the name: the product, its form, its movements.
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
        _CardAction.edit => showProductWizard(
          context,
          storeId: item.storeId,
          itemId: item.id,
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
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          LucideIcons.ellipsisVertical,
          size: AppSizing.iconSm,
          color: AppColors.textSecondary,
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
