import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'item_card.dart';

/// One product in the catalogue's list view.
///
/// The same facts as [ItemCard] laid on a single line: the picture shrunk to a
/// thumbnail, the name and category on the left, the status and the quantity
/// on the right. It is for the user who knows what they are looking for and
/// wants twenty products on screen rather than six.
///
/// Laid out so the three things a cook actually wants are readable in one
/// glance from a step back: what it is, how much is left, and whether that is a
/// problem. Everything else is secondary and sized accordingly.
class ItemListRow extends StatelessWidget {
  const ItemListRow({
    required this.view,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final ItemRowView view;
  final VoidCallback onTap;
  final bool selected;

  /// The thumbnail's side. Big enough that a photograph is recognisable
  /// without turning the row into a card.
  static const double _thumbnailSide = 56;

  /// Below this the badge goes, then the stock caption. The name and the
  /// figure are the two things that cannot go, so they are what is left on the
  /// narrowest pane.
  static const double _badgeBreakpoint = 620;
  static const double _captionBreakpoint = 460;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final item = view.item;
    final status = stockStatusOf(item);
    final colors = StockStatusBadge.colorsFor(status);

    return AppCard(
      onTap: onTap,
      selected: selected,
      // The status stripe repeats the badge's information down the left edge,
      // which is what makes a long list scannable without reading it.
      accentColor: status == StockStatus.inStock ? null : colors.solid,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showBadge = constraints.maxWidth >= _badgeBreakpoint;
          final showCaption = constraints.maxWidth >= _captionBreakpoint;

          return Row(
            children: [
              ProductImage(
                imagePath: item.imagePath,
                size: _thumbnailSide,
                radius: AppRadius.md,
                placeholder: ProductImagePlaceholder.disc,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 4,
                child: Column(
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
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showBadge) ...[
                const SizedBox(width: AppSpacing.md),
                StockStatusBadge(status: status),
              ],
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showCaption)
                      Text(
                        l10n.inventoryStockCurrent,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ItemStockQuantity(
                      view: view,
                      status: status,
                      style: AppTypography.numeric,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ItemActionArrow(onTap: onTap),
            ],
          );
        },
      ),
    );
  }
}
