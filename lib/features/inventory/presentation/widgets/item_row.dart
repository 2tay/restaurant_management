import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// One item in the inventory list.
///
/// Laid out so the three things a cook actually wants are readable in one
/// glance from a step back: what it is, how much is left, and whether that is a
/// problem. Everything else is secondary and sized accordingly.
class ItemRow extends StatelessWidget {
  const ItemRow({
    required this.item,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final Item item;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = stockStatusOf(item);
    final colors = StockStatusBadge.colorsFor(status);
    final unit = MockQueries.unitAbbreviationOf(item.unitId);

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
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  MockQueries.categoryNameOf(item.categoryId),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                Formatters.quantityWithUnit(item.quantity, unit),
                style: AppTypography.numeric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          StockStatusBadge(status: status),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            LucideIcons.chevronRight,
            size: AppSizing.iconMd,
            color: AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}
