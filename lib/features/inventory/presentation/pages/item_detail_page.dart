import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/delete_item.dart';
import '../widgets/item_detail_view.dart';

/// Full-page item detail.
///
/// Reached on narrow tablets, or by deep link. On a wide tablet the same
/// content appears in the inventory split view instead.
class ItemDetailPage extends ConsumerWidget {
  const ItemDetailPage({
    required this.storeId,
    required this.itemId,
    super.key,
  });

  final String storeId;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Only the header is watched here — the name, the category, the status
    // badge. The body below watches its own four queries; splitting them is
    // what lets the header stay put while a delivery lands underneath it.
    final row = ref.watch(itemRowProvider(itemId)).value;

    if (row == null) {
      // Either the query has not answered or the article is gone. Both draw the
      // page's chrome with a placeholder inside it rather than a blank screen,
      // and the retry goes back to the list — which is the only useful action
      // for an article that no longer exists.
      return ShellPage(
        title: l10n.inventoryTitle,
        back: BackDestination(
          label: l10n.inventoryTitle,
          path: Routes.toInventory(storeId),
        ),
        child: ref.watch(itemRowProvider(itemId)).isLoading
            ? const SkeletonList(rows: 4, rowHeight: 120)
            : ErrorState(
                message: l10n.errorStateBody,
                onRetry: () => context.goSection(Routes.toInventory(storeId)),
              ),
      );
    }

    final item = row.item;

    return ShellPage(
      back: BackDestination(
        label: l10n.inventoryTitle,
        path: Routes.toInventory(storeId),
      ),
      crumbs: [
        Crumb(l10n.inventoryTitle, Routes.toInventory(storeId)),
        Crumb(item.name),
      ],
      title: item.name,
      subtitle: row.categoryName,
      scrollable: false,
      actions: [
        StockStatusBadge(status: stockStatusOf(item)),
        SecondaryButton(
          label: l10n.actionEdit,
          icon: LucideIcons.pencil,
          onPressed: () =>
              context.pushScreen(Routes.toEditItem(storeId, item.id)),
        ),
        DestructiveButton(
          label: l10n.actionDelete,
          icon: LucideIcons.trash2,
          filled: false,
          onPressed: () async {
            if (await confirmDeleteItem(context, ref, storeId, item) &&
                context.mounted) {
              context.goSection(Routes.toInventory(storeId));
            }
          },
        ),
      ],
      child: ItemDetailView(
        itemId: itemId,
        storeId: storeId,
        showTitle: false,
      ),
    );
  }
}

/// Shared page padding for detail screens that manage their own scrolling.
const EdgeInsets detailPadding = EdgeInsets.only(bottom: AppSpacing.xxl);
