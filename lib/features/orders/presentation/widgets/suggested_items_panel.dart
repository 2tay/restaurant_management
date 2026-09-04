import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'already_on_order_badge.dart';

/// This supplier's items that are currently below their threshold.
///
/// The bridge between "the app told me stock is low" and "I did something about
/// it". Without this the low stock alerts screen is a list you read and then
/// leave, and the ordering screen is a blank form you have to fill from memory.
///
/// Items already on the order being built stay in the list, greyed and ticked,
/// rather than disappearing — rows vanishing as you add them makes the list
/// feel unstable to work in, and hides the fact that you already dealt with
/// them.
class SuggestedItemsPanel extends StatelessWidget {
  const SuggestedItemsPanel({
    required this.storeId,
    required this.supplierId,
    required this.suggestions,
    required this.supplierName,
    required this.chosenItemIds,
    required this.onAdd,
    required this.onAddAll,
    super.key,
  });

  final String storeId;
  final String supplierId;

  /// This supplier's articles that are running low, already resolved.
  ///
  /// Passed in rather than queried here: the screen around this panel is
  /// already watching the same supplier and the same establishment, and a panel
  /// that fetched its own copy would be a second subscription to the same rows.
  final List<ItemRowView> suggestions;

  /// The supplier's name, from the same list the screen picked them from.
  final String supplierName;

  /// Items already on the order, so the panel can mark them.
  final Set<String> chosenItemIds;

  final ValueChanged<Item> onAdd;
  final ValueChanged<List<Item>> onAddAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final remaining = suggestions
        .where((row) => !chosenItemIds.contains(row.item.id))
        .toList();

    if (suggestions.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(
              LucideIcons.circleCheck,
              size: AppSizing.iconMd,
              color: AppColors.inStock.solid,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l10n.orderSuggestedEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.orderSuggestedTitle(supplierName),
          subtitle: l10n.orderSuggestedSubtitle,
          count: suggestions.length,
          trailing: SecondaryButton(
            label: l10n.orderSuggestedAddAll,
            icon: LucideIcons.listChecks,
            // Disabled rather than hidden once everything is on the order —
            // a control that vanishes leaves the user hunting for it.
            onPressed: remaining.isEmpty
                ? null
                : () => onAddAll([for (final row in remaining) row.item]),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final row in suggestions)
                _SuggestionRow(
                  view: row,
                  storeId: storeId,
                  alreadyChosen: chosenItemIds.contains(row.item.id),
                  onAdd: () => onAdd(row.item),
                  isLast: row.item.id == suggestions.last.item.id,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.view,
    required this.storeId,
    required this.alreadyChosen,
    required this.onAdd,
    required this.isLast,
  });

  final ItemRowView view;
  final String storeId;
  final bool alreadyChosen;
  final VoidCallback onAdd;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final item = view.item;
    final unit = view.unitAbbreviation;
    final shortfall = item.lowStockThreshold - item.quantity;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairline)),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: alreadyChosen
                        ? AppColors.textDisabled
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  Formatters.quantityWithUnit(item.quantity, unit),
                  style: AppTypography.numericSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            flex: 3,
            child: Text(
              l10n.orderSuggestedShortfall(
                Formatters.quantityWithUnit(
                  shortfall > 0 ? shortfall : 0,
                  unit,
                ),
              ),
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // The badge decides for itself whether it has anything to say —
          // it renders nothing when nothing is on its way.
          Flexible(
            flex: 3,
            child: AlreadyOnOrderBadge(
              storeId: storeId,
              itemId: item.id,
              unitAbbreviation: unit,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          if (alreadyChosen)
            Icon(
              LucideIcons.circleCheck,
              size: AppSizing.iconMd,
              color: AppColors.inStock.solid,
            )
          else
            SecondaryButton(label: l10n.orderSuggestedAdd, onPressed: onAdd),
        ],
      ),
    );
  }
}
