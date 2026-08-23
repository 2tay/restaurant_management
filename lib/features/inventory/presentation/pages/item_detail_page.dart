import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
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
    // Quantity, suppliers, prices and open orders can all change from a screen
    // pushed above this one.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);
    final item = MockQueries.itemById(itemId);

    if (item == null) {
      return ShellPage(
        title: l10n.inventoryTitle,
        child: ErrorState(
          message: l10n.errorStateBody,
          onRetry: () => context.goSection(Routes.toInventory(storeId)),
        ),
      );
    }

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
      subtitle: MockQueries.categoryNameOf(item.categoryId),
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
          onPressed: () => _confirmDelete(context, item),
        ),
      ],
      child: ItemDetailView(item: item, storeId: storeId, showTitle: false),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Item item) async {
    final l10n = AppLocalizations.of(context);

    // An article on a commande a supplier is still holding cannot go: the
    // document would be left referring to nothing. Explained before asking,
    // rather than confirmed and then quietly refused.
    final openOrders = MockQueries.openOrdersForItem(storeId, item.id);
    if (openOrders.isNotEmpty) {
      await ConfirmDialog.blocked(
        context,
        title: l10n.itemDeleteBlockedTitle(item.name),
        message: l10n.itemDeleteBlockedBody(openOrders.length),
      );
      return;
    }

    // Deleting cascades to movements and supplier links, so the dialog states
    // exactly what disappears. A confirmation that does not name its blast
    // radius is a formality, not a safeguard.
    final movements = MockQueries.movementsForItem(item.id).length;
    final suppliers = MockQueries.pricesForItem(item.id).length;

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: item.name,
      extraWarning: movements == 0 && suppliers == 0
          ? null
          : l10n.itemDeleteCascadeWarning(movements, suppliers),
    );
    if (!confirmed || !context.mounted) return;

    ItemMutations.delete(item.id);
    AppSnackBar.success(context, l10n.itemDeleted);
    context.goSection(Routes.toInventory(storeId));
  }
}

/// Shared page padding for detail screens that manage their own scrolling.
const EdgeInsets detailPadding = EdgeInsets.only(bottom: AppSpacing.xxl);
