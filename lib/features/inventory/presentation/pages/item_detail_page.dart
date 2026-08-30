import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
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
          onPressed: () => _confirmDelete(context, ref, item),
        ),
      ],
      child: ItemDetailView(
        itemId: itemId,
        storeId: storeId,
        showTitle: false,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Item item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final items = ref.read(itemRepositoryProvider);

    // An article on a commande a supplier is still holding cannot go: the
    // document would be left referring to nothing. Explained before asking,
    // rather than confirmed and then quietly refused. The repository refuses it
    // too — this is the sentence, not the safeguard.
    final orders = ref.read(orderRepositoryProvider);
    final openOrders = await orders.openOrdersForItem(storeId, item.id);
    if (!context.mounted) return;

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
    final movements = await ref
        .read(movementRepositoryProvider)
        .movementsForItem(item.id);
    final suppliers = await ref
        .read(supplierRepositoryProvider)
        .pricesForItem(item.id);
    if (!context.mounted) return;

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: item.name,
      extraWarning: movements.isEmpty && suppliers.isEmpty
          ? null
          : l10n.itemDeleteCascadeWarning(movements.length, suppliers.length),
    );
    if (!confirmed || !context.mounted) return;

    await items.delete(item.id);

    if (!context.mounted) return;
    AppSnackBar.success(context, l10n.itemDeleted);
    context.goSection(Routes.toInventory(storeId));
  }
}

/// Shared page padding for detail screens that manage their own scrolling.
const EdgeInsets detailPadding = EdgeInsets.only(bottom: AppSpacing.xxl);
