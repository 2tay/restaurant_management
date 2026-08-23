import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/item_detail_view.dart';

/// Full-page item detail.
///
/// Reached on narrow tablets, or by deep link. On a wide tablet the same
/// content appears in the inventory split view instead.
class ItemDetailPage extends StatelessWidget {
  const ItemDetailPage({
    required this.storeId,
    required this.itemId,
    super.key,
  });

  final String storeId;
  final String itemId;

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => _confirmDelete(context, item.name),
        ),
      ],
      child: ItemDetailView(item: item, storeId: storeId, showTitle: false),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: name,
      extraWarning: l10n.itemRemoveSupplierWarning,
    );

    if (confirmed && context.mounted) {
      AppSnackBar.success(context, l10n.itemDeleted);
      context.goSection(Routes.toInventory(storeId));
    }
  }
}

/// Shared page padding for detail screens that manage their own scrolling.
const EdgeInsets detailPadding = EdgeInsets.only(bottom: AppSpacing.xxl);
