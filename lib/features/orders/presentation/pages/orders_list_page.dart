import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../documents/order_document_button.dart';
import '../widgets/order_actions.dart';
import '../widgets/order_row.dart';
import '../widgets/order_status_badge.dart';

/// How many days back a date filter reaches. Null means no date filter.
enum OrderDateRange { last7, last30, last90 }

/// The status tabs across the top of the orders list.
enum OrdersTab {
  all,
  drafts,
  sent,
  partial,

  /// Fully received or cancelled — nothing left to do.
  done;

  bool matches(PurchaseOrder order) => switch (this) {
    OrdersTab.all => true,
    OrdersTab.drafts => order.status == PurchaseOrderStatus.draft,
    OrdersTab.sent => order.status == PurchaseOrderStatus.sent,
    OrdersTab.partial => order.status == PurchaseOrderStatus.partial,
    OrdersTab.done =>
      order.status == PurchaseOrderStatus.received ||
          order.status == PurchaseOrderStatus.cancelled,
  };

  String label(AppLocalizations l10n) => switch (this) {
    OrdersTab.all => l10n.ordersTabAll,
    OrdersTab.drafts => l10n.ordersTabDrafts,
    OrdersTab.sent => l10n.ordersTabSent,
    OrdersTab.partial => l10n.ordersTabPartial,
    OrdersTab.done => l10n.ordersTabDone,
  };
}

/// Local filter state for the orders list. UI state only — no business rules.
class OrdersFilter {
  const OrdersFilter({this.tab = OrdersTab.all, this.supplierId, this.range});

  /// Which status tab is open. Always on screen, so not counted as a filter.
  final OrdersTab tab;
  final String? supplierId;
  final OrderDateRange? range;

  bool get hasActiveFilters => activeFilterCount > 0;

  /// How many filters are narrowing the list, for the button that stands in
  /// for them on a phone.
  int get activeFilterCount =>
      (supplierId != null ? 1 : 0) + (range != null ? 1 : 0);

  OrdersFilter copyWith({
    OrdersTab? tab,
    String? supplierId,
    OrderDateRange? range,
    bool clearSupplier = false,
    bool clearRange = false,
  }) {
    return OrdersFilter(
      tab: tab ?? this.tab,
      supplierId: clearSupplier ? null : supplierId ?? this.supplierId,
      range: clearRange ? null : range ?? this.range,
    );
  }
}

class OrdersFilterNotifier extends Notifier<OrdersFilter> {
  @override
  OrdersFilter build() => const OrdersFilter();

  void setTab(OrdersTab tab) => state = state.copyWith(tab: tab);

  void setSupplier(String? id) => id == null
      ? state = state.copyWith(clearSupplier: true)
      : state = state.copyWith(supplierId: id);

  void setRange(OrderDateRange? value) => value == null
      ? state = state.copyWith(clearRange: true)
      : state = state.copyWith(range: value);

  /// Clears the supplier and period, keeping the tab the user is on.
  void clear() => state = OrdersFilter(tab: state.tab);
}

/// Cards or a table — kept for the session.
enum OrdersViewMode { list, table }

class OrdersViewModeNotifier extends Notifier<OrdersViewMode> {
  @override
  OrdersViewMode build() => OrdersViewMode.list;

  void select(OrdersViewMode mode) => state = mode;
}

final ordersViewModeProvider =
    NotifierProvider<OrdersViewModeNotifier, OrdersViewMode>(
      OrdersViewModeNotifier.new,
    );

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

    // Sending, receiving and cancelling all happen on screens pushed above this
    // one. The query watches the tables they write to, so the list is correct
    // when the user comes back rather than showing what it read on the way in.
    final filter = ref.watch(ordersFilterProvider);
    final notifier = ref.read(ordersFilterProvider.notifier);

    final rows = ref.watch(orderRowsProvider(storeId));
    final suppliers = ref.watch(suppliersProvider(storeId)).value ?? const [];
    final staleDays =
        ref.watch(stalePartialOrderDaysProvider(storeId)).value ??
        OrderRules.defaultStalePartialDays;

    return ShellPage(
      title: l10n.ordersTitle,
      subtitle: l10n.ordersSubtitle,
      actions: [
        PrimaryButton(
          label: l10n.ordersNewAction,
          shortLabel: l10n.shortNewOrder,
          icon: LucideIcons.plus,
          onPressed: () => context.pushScreen(Routes.toNewOrder(storeId)),
        ),
      ],
      child: AsyncContent<List<OrderRowView>>(
        value: rows,
        onRetry: () => ref.invalidate(orderRowsProvider(storeId)),
        builder: (context, all) {
          final orders = _visible(all, filter);

          final filters = <Widget>[
            _SupplierMenu(
              suppliers: suppliers,
              selectedId: filter.supplierId,
              onSelected: notifier.setSupplier,
            ),
            _RangeMenu(selected: filter.range, onSelected: notifier.setRange),
          ];

          // Counted over the supplier and period filters, so each tab says
          // how many rows tapping it would show.
          final beforeTab = _visible(all, filter.copyWith(tab: OrdersTab.all));
          final counts = {
            for (final tab in OrdersTab.values)
              tab: beforeTab.where((view) => tab.matches(view.order)).length,
          };
          final viewMode = ref.watch(ordersViewModeProvider);
          final showTable =
              viewMode == OrdersViewMode.table && !context.isPhone;

          final count = Text(
            l10n.ordersCount(orders.length),
            style: Theme.of(context).textTheme.bodySmall,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusTabs(
                tab: filter.tab,
                counts: counts,
                onSelected: notifier.setTab,
              ),
              const SizedBox(height: AppSpacing.md),
              // Four filters and a count stack into five rows on a phone. They
              // move behind one button there and stay on screen on a tablet,
              // the same bargain the inventory and movement lists make.
              if (context.isPhone)
                Row(
                  children: [
                    FilterSheetButton(
                      activeCount: filter.activeFilterCount,
                      onPressed: () => FilterSheet.show(
                        context,
                        onClear: filter.hasActiveFilters
                            ? notifier.clear
                            : null,
                        builder: (context) => Consumer(
                          builder: (context, ref, _) {
                            // Watched, not captured: the pills inside the sheet
                            // have to follow the taps made on them.
                            ref.watch(ordersFilterProvider);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final (i, control) in filters.indexed) ...[
                                  if (i > 0)
                                    const SizedBox(height: AppSpacing.md),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: control,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: count),
                  ],
                )
              else ...[
                // Filters on the left, how to show them on the right.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...filters,
                          if (filter.hasActiveFilters)
                            TextButton.icon(
                              onPressed: notifier.clear,
                              icon: const Icon(
                                LucideIcons.x,
                                size: AppSizing.iconSm,
                              ),
                              label: Text(l10n.inventoryClearFilters),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ViewModeToggle<OrdersViewMode>(
                      value: viewMode,
                      onSelected: ref
                          .read(ordersViewModeProvider.notifier)
                          .select,
                      options: [
                        ViewModeOption(
                          value: OrdersViewMode.list,
                          icon: LucideIcons.list,
                          label: l10n.movementsViewList,
                        ),
                        ViewModeOption(
                          value: OrdersViewMode.table,
                          icon: LucideIcons.table,
                          label: l10n.movementsViewTable,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                count,
              ],
              const SizedBox(height: AppSpacing.md),

              // Part of the page: the whole page scrolls, title and filters
              // included.
              Builder(
                builder: (context) => orders.isEmpty
                    ? _Empty(
                        storeId: storeId,
                        storeHasOrders: all.isNotEmpty,
                        onClearFilters: notifier.clear,
                      )
                    : showTable
                    ? _OrdersTable(storeId: storeId, orders: orders)
                    : ListView.separated(
                        shrinkWrap: true,
                        primary: false,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: orders.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final view = orders[index];
                          return OrderRow(
                            view: view,
                            stalePartialDays: staleDays,
                            onTap: () => context.pushScreen(
                              Routes.toOrder(storeId, view.order.id),
                            ),
                            action: _QuickAction(storeId: storeId, view: view),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The four filters, applied over rows already in hand.
  ///
  /// Kept in Dart: this is a screen for trying one filter after another, and
  /// four optional predicates in SQL would be four shapes of query behind it.
  List<OrderRowView> _visible(List<OrderRowView> rows, OrdersFilter filter) {
    final now = DateTime.now();

    return rows.where((view) {
      final order = view.order;
      if (!filter.tab.matches(order)) return false;
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

class _SupplierMenu extends StatelessWidget {
  const _SupplierMenu({
    required this.suppliers,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Supplier> suppliers;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  /// From the list the menu is already showing, so the label on the chip and
  /// the entries below it cannot disagree.
  String _nameOf(String id) {
    for (final supplier in suppliers) {
      if (supplier.id == id) return supplier.name;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = selectedId == null ? null : _nameOf(selectedId!);

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
          PopupMenuItem<String>(value: supplier.id, child: Text(supplier.name)),
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

/// The status tabs: one chip per status, each with how many orders it holds.
/// One tap to the drafts waiting to be sent, or the orders waiting to arrive.
class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.tab,
    required this.counts,
    required this.onSelected,
  });

  final OrdersTab tab;
  final Map<OrdersTab, int> counts;
  final ValueChanged<OrdersTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, value) in OrdersTab.values.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              selected: value == tab,
              child: InkWell(
                onTap: () => onSelected(value),
                borderRadius: AppRadius.pillAll,
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  constraints: const BoxConstraints(
                    minHeight: AppSizing.minTapTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: value == tab
                        ? AppColors.primaryContainer
                        : AppColors.surface,
                    borderRadius: AppRadius.pillAll,
                    border: Border.all(
                      color: value == tab
                          ? AppColors.primary600
                          : AppColors.border,
                      width: value == tab ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value.label(l10n),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: value == tab
                              ? AppColors.onPrimaryContainer
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: value == tab
                              ? AppColors.surface
                              : AppColors.surfaceVariant,
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(
                          '${counts[value] ?? 0}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The one thing to do next with an order, on its row: send a draft, receive
/// a sent or partial one, reorder a finished one.
class _QuickAction extends ConsumerWidget {
  const _QuickAction({required this.storeId, required this.view});

  final String storeId;
  final OrderRowView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = view.order;

    return switch (order.status) {
      PurchaseOrderStatus.draft => SecondaryButton(
        label: l10n.orderActionSend,
        icon: LucideIcons.send,
        onPressed: () =>
            confirmSendOrder(context, ref, order, view.supplierName),
      ),
      PurchaseOrderStatus.sent || PurchaseOrderStatus.partial => PrimaryButton(
        label: l10n.receptionsReceive,
        icon: LucideIcons.packageCheck,
        onPressed: () =>
            context.pushScreen(Routes.toReceiveOrder(storeId, order.id)),
      ),
      PurchaseOrderStatus.received ||
      PurchaseOrderStatus.cancelled => SecondaryButton(
        label: l10n.orderActionDuplicate,
        icon: LucideIcons.copy,
        onPressed: () => duplicateOrder(context, ref, storeId, order),
      ),
    };
  }
}

/// How much of what was ordered has arrived, as a share — the Reçu column.
double _receivedShare(PurchaseOrder order) {
  var ordered = 0.0;
  var received = 0.0;
  for (final line in order.lines) {
    ordered += line.quantityOrdered;
    received += line.quantityReceived.clamp(0, line.quantityOrdered);
  }
  return ordered <= 0 ? 0 : (received / ordered).clamp(0.0, 1.0);
}

/// The orders as a table: reference and date, supplier, status, lines,
/// amount, how much has arrived, and the next action.
class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.storeId, required this.orders});

  final String storeId;
  final List<OrderRowView> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppTable<OrderRowView>(
      rows: orders,
      shrinkWrap: true,
      onRowTap: (view) =>
          context.pushScreen(Routes.toOrder(storeId, view.order.id)),
      columns: [
        AppTableColumn(label: l10n.tableColReference, width: 170),
        AppTableColumn(label: l10n.tableColSupplier, flex: 3),
        AppTableColumn(label: l10n.tableColStatus, width: 150),
        AppTableColumn(
          label: l10n.tableColLines,
          width: 80,
          numeric: true,
          minTableWidth: 980,
        ),
        AppTableColumn(label: l10n.tableColAmount, width: 112, numeric: true),
        AppTableColumn(
          label: l10n.tableColReceived,
          width: 120,
          minTableWidth: 860,
        ),
        const AppTableColumn(label: '', width: 220),
      ],
      cell: (context, view, column) {
        final order = view.order;
        return switch (column) {
          0 => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.reference,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                Formatters.date(order.sentAt ?? order.createdAt),
                style: theme.textTheme.bodySmall,
                maxLines: 1,
              ),
            ],
          ),
          1 => Text(
            view.supplierName,
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          2 => OrderStatusBadge(status: order.status),
          3 => Text('${order.lines.length}', style: AppTypography.numeric),
          4 => Text(
            Formatters.price(orderTotal(order)),
            style: AppTypography.numeric,
            maxLines: 1,
          ),
          5 =>
            order.status == PurchaseOrderStatus.draft
                ? Text('—', style: theme.textTheme.bodySmall)
                : Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: AppRadius.pillAll,
                          child: LinearProgressIndicator(
                            value: _receivedShare(order),
                            minHeight: 6,
                            color: AppColors.primary600,
                            backgroundColor: AppColors.neutral100,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        Formatters.percent(_receivedShare(order)),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
          _ => Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OrderDocumentButton(order: order, compact: true),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: _QuickAction(storeId: storeId, view: view),
              ),
            ],
          ),
        };
      },
    );
  }
}
