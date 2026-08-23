import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/order_row.dart';
import '../widgets/order_status_badge.dart';

/// How many days back a date filter reaches. Null means no date filter.
enum OrderDateRange { last7, last30, last90 }

/// Local filter state for the orders list. UI state only — no business rules.
class OrdersFilter {
  const OrdersFilter({
    this.status,
    this.supplierId,
    this.range,
    this.openOnly = false,
  });

  final PurchaseOrderStatus? status;
  final String? supplierId;
  final OrderDateRange? range;

  /// Sent and partial only — the orders somebody still has to do something
  /// about. The one filter staff actually reach for, so it gets its own chip
  /// rather than living inside the status menu.
  final bool openOnly;

  bool get hasActiveFilters =>
      status != null || supplierId != null || range != null || openOnly;

  OrdersFilter copyWith({
    PurchaseOrderStatus? status,
    String? supplierId,
    OrderDateRange? range,
    bool? openOnly,
    bool clearStatus = false,
    bool clearSupplier = false,
    bool clearRange = false,
  }) {
    return OrdersFilter(
      status: clearStatus ? null : status ?? this.status,
      supplierId: clearSupplier ? null : supplierId ?? this.supplierId,
      range: clearRange ? null : range ?? this.range,
      openOnly: openOnly ?? this.openOnly,
    );
  }
}

class OrdersFilterNotifier extends Notifier<OrdersFilter> {
  @override
  OrdersFilter build() => const OrdersFilter();

  void setStatus(PurchaseOrderStatus? value) => value == null
      ? state = state.copyWith(clearStatus: true)
      : state = state.copyWith(status: value);

  void setSupplier(String? id) => id == null
      ? state = state.copyWith(clearSupplier: true)
      : state = state.copyWith(supplierId: id);

  void setRange(OrderDateRange? value) => value == null
      ? state = state.copyWith(clearRange: true)
      : state = state.copyWith(range: value);

  void toggleOpenOnly() => state = state.copyWith(openOnly: !state.openOnly);

  /// Used by the dashboard's stale-orders prompt, which wants to land the user
  /// on the open orders rather than on everything.
  void showOpenOnly() => state = const OrdersFilter(openOnly: true);

  void clear() => state = const OrdersFilter();
}

final ordersFilterProvider =
    NotifierProvider<OrdersFilterNotifier, OrdersFilter>(
      OrdersFilterNotifier.new,
    );

/// Every commande for the current store.
class OrdersListPage extends ConsumerWidget {
  const OrdersListPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Sending, receiving and cancelling all happen on screens pushed above
    // this one. Watching the revision is what makes the list correct when the
    // user comes back rather than showing what it read on the way in.
    ref.watch(mockDataRevisionProvider);

    final filter = ref.watch(ordersFilterProvider);
    final notifier = ref.read(ordersFilterProvider.notifier);

    final all = MockQueries.ordersForStore(storeId);
    final orders = _visible(all, filter);
    final suppliers = MockQueries.suppliersForStore(storeId);

    return ShellPage(
      title: l10n.ordersTitle,
      subtitle: l10n.ordersSubtitle,
      scrollable: false,
      actions: [
        PrimaryButton(
          label: l10n.ordersNewAction,
          icon: LucideIcons.plus,
          onPressed: () => context.pushScreen(Routes.toNewOrder(storeId)),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusMenu(
                selected: filter.status,
                onSelected: notifier.setStatus,
              ),
              _SupplierMenu(
                suppliers: suppliers,
                selectedId: filter.supplierId,
                onSelected: notifier.setSupplier,
              ),
              _RangeMenu(selected: filter.range, onSelected: notifier.setRange),
              FilterChip(
                label: Text(l10n.ordersOpenOnly),
                avatar: Icon(
                  LucideIcons.truck,
                  size: AppSizing.iconSm,
                  color: filter.openOnly
                      ? AppColors.steel800
                      : AppColors.textSecondary,
                ),
                selected: filter.openOnly,
                onSelected: (_) => notifier.toggleOpenOnly(),
                selectedColor: AppColors.offlineContainer,
                checkmarkColor: AppColors.steel800,
              ),
              if (filter.hasActiveFilters)
                TextButton.icon(
                  onPressed: notifier.clear,
                  icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
                  label: Text(l10n.inventoryClearFilters),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.ordersCount(orders.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),

          Expanded(
            child: orders.isEmpty
                ? _Empty(
                    storeId: storeId,
                    storeHasOrders: all.isNotEmpty,
                    onClearFilters: notifier.clear,
                  )
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return OrderRow(
                        order: order,
                        onTap: () => context.pushScreen(
                          Routes.toOrder(storeId, order.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<PurchaseOrder> _visible(List<PurchaseOrder> orders, OrdersFilter filter) {
    final now = DateTime.now();

    return orders.where((order) {
      if (filter.openOnly && !orderIsOpen(order)) return false;
      if (filter.status != null && order.status != filter.status) return false;
      if (filter.supplierId != null && order.supplierId != filter.supplierId) {
        return false;
      }
      if (filter.range != null) {
        final days = switch (filter.range!) {
          OrderDateRange.last7 => 7,
          OrderDateRange.last30 => 30,
          OrderDateRange.last90 => 90,
        };
        final date = order.sentAt ?? order.createdAt;
        if (now.difference(date).inDays > days) return false;
      }
      return true;
    }).toList();
  }
}

/// Separates "this store has never ordered anything" from "your filters matched
/// nothing". Different words, different button.
class _Empty extends StatelessWidget {
  const _Empty({
    required this.storeId,
    required this.storeHasOrders,
    required this.onClearFilters,
  });

  final String storeId;
  final bool storeHasOrders;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (storeHasOrders) {
      return EmptyState.noResults(
        l10n,
        onClearFilters: onClearFilters,
        clearLabel: l10n.inventoryClearFilters,
      );
    }

    return EmptyState(
      icon: LucideIcons.clipboardList,
      title: l10n.ordersEmptyTitle,
      message: l10n.ordersEmptyBody,
      actionLabel: l10n.ordersEmptyAction,
      actionIcon: LucideIcons.plus,
      onAction: () => context.pushScreen(Routes.toNewOrder(storeId)),
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.selected, required this.onSelected});

  final PurchaseOrderStatus? selected;
  final ValueChanged<PurchaseOrderStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      tooltip: l10n.ordersFilterStatus,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (value) => onSelected(
        value == _all
            ? null
            : PurchaseOrderStatus.values.firstWhere((s) => s.name == value),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: _all,
          child: Text(l10n.ordersFilterAllStatuses),
        ),
        const PopupMenuDivider(),
        for (final status in PurchaseOrderStatus.values)
          PopupMenuItem<String>(
            value: status.name,
            child: Row(
              children: [
                OrderStatusBadge(status: status, compact: true),
                const SizedBox(width: AppSpacing.md),
                Text(OrderStatusBadge.labelFor(l10n, status)),
              ],
            ),
          ),
      ],
      child: FilterPill(
        label: l10n.ordersFilterStatus,
        selectedLabel: selected == null
            ? null
            : OrderStatusBadge.labelFor(l10n, selected!),
      ),
    );
  }

  static const String _all = '__all__';
}

class _SupplierMenu extends StatelessWidget {
  const _SupplierMenu({
    required this.suppliers,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Supplier> suppliers;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = selectedId == null
        ? null
        : MockQueries.supplierNameOf(selectedId);

    return PopupMenuButton<String>(
      tooltip: l10n.inventoryFilterSupplier,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (value) => onSelected(value == _all ? null : value),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: _all,
          child: Text(l10n.inventoryFilterAllSuppliers),
        ),
        const PopupMenuDivider(),
        for (final supplier in suppliers)
          PopupMenuItem<String>(
            value: supplier.id,
            child: Text(supplier.name),
          ),
      ],
      child: FilterPill(
        label: l10n.inventoryFilterSupplier,
        selectedLabel: selected,
      ),
    );
  }

  static const String _all = '__all__';
}

class _RangeMenu extends StatelessWidget {
  const _RangeMenu({required this.selected, required this.onSelected});

  final OrderDateRange? selected;
  final ValueChanged<OrderDateRange?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    String label(OrderDateRange range) => switch (range) {
      OrderDateRange.last7 => l10n.ordersFilterLast7,
      OrderDateRange.last30 => l10n.ordersFilterLast30,
      OrderDateRange.last90 => l10n.ordersFilterLast90,
    };

    return PopupMenuButton<String>(
      tooltip: l10n.ordersFilterPeriod,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (value) => onSelected(
        value == _all
            ? null
            : OrderDateRange.values.firstWhere((r) => r.name == value),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: _all,
          child: Text(l10n.ordersFilterAllPeriods),
        ),
        const PopupMenuDivider(),
        for (final range in OrderDateRange.values)
          PopupMenuItem<String>(value: range.name, child: Text(label(range))),
      ],
      child: FilterPill(
        label: l10n.ordersFilterPeriod,
        selectedLabel: selected == null ? null : label(selected!),
      ),
    );
  }

  static const String _all = '__all__';
}
