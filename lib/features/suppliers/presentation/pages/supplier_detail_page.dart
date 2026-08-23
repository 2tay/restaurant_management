import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../orders/presentation/widgets/order_row.dart';

/// A supplier's contact details and everything they supply, with prices.
///
/// The product table marks the rows where this supplier is the cheapest option,
/// which turns "who is this supplier" into "is this supplier worth keeping".
class SupplierDetailPage extends ConsumerStatefulWidget {
  const SupplierDetailPage({
    required this.storeId,
    required this.supplierId,
    this.embedded = false,
    super.key,
  });

  final String storeId;
  final String supplierId;

  /// True when shown in the right-hand pane of the suppliers split view. The
  /// surrounding page already provides the header and chrome, so this renders
  /// its body alone.
  final bool embedded;

  @override
  ConsumerState<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends ConsumerState<SupplierDetailPage> {
  static const String _tabDetails = 'details';
  static const String _tabOrders = 'orders';

  String _tab = _tabDetails;

  String get storeId => widget.storeId;
  String get supplierId => widget.supplierId;
  bool get embedded => widget.embedded;

  @override
  Widget build(BuildContext context) {
    // Prices, linked items and the order history all move under this screen.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final supplier = MockQueries.supplierById(supplierId);

    if (supplier == null) {
      return ShellPage(
        title: l10n.suppliersTitle,
        child: ErrorState(
          onRetry: () => context.goSection(Routes.toSuppliers(storeId)),
        ),
      );
    }

    final prices = MockQueries.pricesForSupplier(supplierId);
    final orders = MockQueries.ordersForSupplier(supplierId);

    final body = _tab == _tabOrders
        ? _OrderHistory(storeId: storeId, orders: orders)
        : _body(context, l10n, theme, supplier, prices);

    final tabs = SectionTabs(
      currentPath: _tab,
      // Two views of one supplier rather than two screens, so they switch in
      // place instead of navigating — but they look and behave like every other
      // tab bar in the app.
      onSelected: (value) => setState(() => _tab = value),
      tabs: [
        SectionTab(label: l10n.supplierTabDetails, path: _tabDetails),
        SectionTab(label: l10n.supplierTabOrders, path: _tabOrders),
      ],
    );

    if (embedded) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: tabs),
            const SizedBox(height: AppSpacing.xl),
            body,
          ],
        ),
      );
    }

    return ShellPage(
      back: BackDestination(
        label: l10n.suppliersTitle,
        path: Routes.toSuppliers(storeId),
      ),
      crumbs: [
        Crumb(l10n.suppliersTitle, Routes.toSuppliers(storeId)),
        Crumb(supplier.name),
      ],
      title: supplier.name,
      subtitle: '${supplier.postalCode} ${supplier.city}',
      tabs: tabs,
      actions: [
        SecondaryButton(
          label: l10n.actionEdit,
          icon: LucideIcons.pencil,
          onPressed: () =>
              context.pushScreen(Routes.toEditSupplier(storeId, supplierId)),
        ),
        PrimaryButton(
          label: l10n.supplierEditPrices,
          icon: LucideIcons.scale,
          onPressed: () =>
              context.pushScreen(Routes.toSupplierPricing(storeId, supplierId)),
        ),
      ],
      child: body,
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Supplier supplier,
    List<SupplierPrice> prices,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.supplierContact),
        AppCard(
          child: Column(
            children: [
              _ContactRow(
                icon: LucideIcons.user,
                label: l10n.supplierFormContactName,
                value: supplier.contactName,
              ),
              const Divider(height: AppSpacing.xl),
              _ContactRow(
                icon: LucideIcons.mail,
                label: l10n.supplierFormEmail,
                value: supplier.email,
              ),
              const Divider(height: AppSpacing.xl),
              _ContactRow(
                icon: LucideIcons.phone,
                label: l10n.supplierFormPhone,
                value: supplier.phone,
              ),
              const Divider(height: AppSpacing.xl),
              _ContactRow(
                icon: LucideIcons.mapPin,
                label: l10n.addStoreAddress,
                value:
                    '${supplier.addressLine}, ${supplier.postalCode} ${supplier.city}',
              ),
              if (supplier.note != null) ...[
                const Divider(height: AppSpacing.xl),
                _ContactRow(
                  icon: LucideIcons.info,
                  label: l10n.supplierFormNote,
                  value: supplier.note!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(
          title: l10n.supplierProducts,
          count: prices.isEmpty ? null : prices.length,
        ),
        if (prices.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.supplierProductsEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          DataTableWrapper(
            minWidth: 680,
            columns: [
              DataColumn(label: Text(l10n.supplierPricingColumnProduct)),
              DataColumn(
                label: Text(l10n.supplierPricingColumnPrice),
                numeric: true,
              ),
              DataColumn(label: Text(l10n.supplierPricingColumnUpdated)),
              DataColumn(label: Text(l10n.supplierPricingColumnCompare)),
            ],
            rows: [
              for (final price in prices)
                _productRow(context, l10n, price.itemId, price),
            ],
          ),
        const SizedBox(height: AppSpacing.xl),

        Align(
          alignment: Alignment.centerLeft,
          child: DestructiveButton(
            label: l10n.actionDelete,
            icon: LucideIcons.trash2,
            filled: false,
            onPressed: () =>
                _confirmDelete(context, supplier.name, prices.length),
          ),
        ),
      ],
    );
  }

  DataRow _productRow(
    BuildContext context,
    AppLocalizations l10n,
    String itemId,
    SupplierPrice price,
  ) {
    final item = MockQueries.itemById(itemId);
    final unit = item == null
        ? ''
        : MockQueries.unitAbbreviationOf(item.unitId);
    final cheapest = MockQueries.cheapestPriceForItem(itemId);
    final isCheapest = cheapest?.supplierId == supplierId;
    final gap = cheapest == null
        ? 0.0
        : price.pricePerUnit - cheapest.pricePerUnit;

    return DataRow(
      onSelectChanged: (_) =>
          context.pushScreen(Routes.toItem(storeId, itemId)),
      cells: [
        DataCell(Text(item?.name ?? '—')),
        DataCell(
          NumericCell('${Formatters.price(price.pricePerUnit)} / $unit'),
        ),
        DataCell(Text(Formatters.date(price.effectiveDate))),
        DataCell(
          isCheapest
              ? _Badge(
                  label: l10n.supplierPricingBest,
                  colors: AppColors.inStock,
                  icon: LucideIcons.trendingDown,
                )
              : Text(
                  '+${Formatters.price(gap)}',
                  style: AppTypography.numericSmall.copyWith(
                    color: AppColors.lowStock.foreground,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String name,
    int productCount,
  ) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: name,
      extraWarning: productCount > 0
          ? l10n.supplierDeleteWarning(productCount)
          : null,
    );

    if (confirmed && context.mounted) {
      AppSnackBar.success(context, l10n.supplierDeleted);
      context.goSection(Routes.toSuppliers(storeId));
    }
  }
}

/// Every commande ever placed with this supplier, newest first.
///
/// The question this answers is not "what do they sell" — the prices tab covers
/// that — but "how do they actually behave": how often we order, how much we
/// spend, and how many orders had to be closed short.
class _OrderHistory extends StatelessWidget {
  const _OrderHistory({required this.storeId, required this.orders});

  final String storeId;
  final List<PurchaseOrder> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (orders.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: LucideIcons.clipboardList,
          title: l10n.supplierOrdersEmpty,
          message: l10n.ordersEmptyBody,
          actionLabel: l10n.ordersNewAction,
          actionIcon: LucideIcons.plus,
          onAction: () => context.pushScreen(Routes.toNewOrder(storeId)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.supplierTabOrders,
          count: orders.length,
          trailing: SecondaryButton(
            label: l10n.ordersNewAction,
            icon: LucideIcons.plus,
            onPressed: () => context.pushScreen(Routes.toNewOrder(storeId)),
          ),
        ),
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OrderRow(
              order: order,
              onTap: () =>
                  context.pushScreen(Routes.toOrder(storeId, order.id)),
            ),
          ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizing.iconMd, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.colors, required this.icon});

  final String label;
  final StockStatusColors colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.foreground),
          ),
        ],
      ),
    );
  }
}
