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
import '../widgets/order_status_badge.dart';
import '../widgets/order_visuals.dart';

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

/// A table column the orders can be sorted by.
enum OrdersSortKey { date, reference, supplier, status, amount, received }

/// The table's sort — null [key] keeps the newest-first order the list comes
/// in with.
class OrdersSort {
  const OrdersSort({this.key, this.ascending = true});

  final OrdersSortKey? key;
  final bool ascending;
}

class OrdersSortNotifier extends Notifier<OrdersSort> {
  @override
  OrdersSort build() => const OrdersSort();

  /// A new column sorts ascending; the same column again flips direction.
  void toggle(OrdersSortKey key) => state = state.key == key
      ? OrdersSort(key: key, ascending: !state.ascending)
      : OrdersSort(key: key);
}

final ordersSortProvider = NotifierProvider<OrdersSortNotifier, OrdersSort>(
  OrdersSortNotifier.new,
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
          final count = _Summary(orders: orders);

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
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...filters,
                    if (filter.hasActiveFilters)
                      TextButton.icon(
                        onPressed: notifier.clear,
                        icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
                        label: Text(l10n.inventoryClearFilters),
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
                    : _OrdersTable(
                        storeId: storeId,
                        orders: orders,
                        stalePartialDays: staleDays,
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
///
/// [compact] draws it as an icon button with the label in a tooltip, for a
/// table too narrow to give a worded button its column.
class _QuickAction extends ConsumerWidget {
  const _QuickAction({
    required this.storeId,
    required this.view,
    this.compact = false,
  });

  final String storeId;
  final OrderRowView view;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = view.order;

    final (label, icon, primary, onPressed) = switch (order.status) {
      PurchaseOrderStatus.draft => (
        l10n.orderActionSend,
        LucideIcons.send,
        false,
        () => confirmSendOrder(context, ref, order, view.supplierName),
      ),
      PurchaseOrderStatus.sent || PurchaseOrderStatus.partial => (
        l10n.receptionsReceive,
        LucideIcons.packageCheck,
        true,
        () => context.pushScreen(Routes.toReceiveOrder(storeId, order.id)),
      ),
      PurchaseOrderStatus.received || PurchaseOrderStatus.cancelled => (
        l10n.orderActionDuplicate,
        LucideIcons.copy,
        false,
        () => duplicateOrder(context, ref, storeId, order),
      ),
    };

    if (compact) {
      final glyph = Icon(icon, size: AppSizing.iconSm);
      return primary
          ? IconButton.filled(onPressed: onPressed, tooltip: label, icon: glyph)
          : IconButton.outlined(
              onPressed: onPressed,
              tooltip: label,
              icon: glyph,
            );
    }

    return primary
        ? PrimaryButton(label: label, icon: icon, onPressed: onPressed)
        : SecondaryButton(label: label, icon: icon, onPressed: onPressed);
  }
}

/// "12 commandes · 4 520,00 €" — how many rows the filters left, and what
/// they commit the store to.
class _Summary extends StatelessWidget {
  const _Summary({required this.orders});

  final List<OrderRowView> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    var total = 0.0;
    for (final view in orders) {
      total += orderTotal(view.order);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: l10n.ordersCount(orders.length),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (orders.isNotEmpty) ...[
            const TextSpan(text: '  ·  '),
            TextSpan(
              text: Formatters.price(total),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The orders, as the page's one view: date and time, reference, supplier,
/// status, lines, amount, how much has arrived, and the next action.
///
/// Sortable by every column worth comparing. Shapes itself to the room it is
/// given rather than to the screen, dropping columns in order of how rarely
/// they are read — lines, then progress, then the reference — while action
/// buttons fold to icons and the status pill to its glyph. What a dropped
/// column said moves under the supplier's name.
///
/// Below [_stacksBelow] — a phone — there is no room left for columns at all,
/// and each order becomes a stacked row inside the same frame instead: every
/// figure still there, none of it panned off the side.
class _OrdersTable extends ConsumerWidget {
  const _OrdersTable({
    required this.storeId,
    required this.orders,
    required this.stalePartialDays,
  });

  final String storeId;
  final List<OrderRowView> orders;
  final int stalePartialDays;

  // The widths each column needs to be shown at.
  static const double _showsLines = 1180;
  static const double _showsReceived = 1000;
  static const double _showsReference = 700;
  static const double _stacksBelow = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sort = ref.watch(ordersSortProvider);
    final rows = _sorted(orders, sort);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < _stacksBelow) {
          return _StackedOrders(
            storeId: storeId,
            orders: rows,
            stalePartialDays: stalePartialDays,
          );
        }
        final compactStatus = width < _showsReference;
        final compactActions = width < 900;
        final showsReference = width >= _showsReference;

        return AppTable<OrderRowView>(
          rows: rows,
          shrinkWrap: true,
          rowHeight: 64,
          sortKey: sort.key,
          sortAscending: sort.ascending,
          onSort: (key) => ref
              .read(ordersSortProvider.notifier)
              .toggle(key as OrdersSortKey),
          // Only the orders that need chasing get an edge, so a long table
          // still shows at a glance which deliveries are overdue.
          rowAccent: (view) => orderIsStale(view.order, stalePartialDays)
              ? AppColors.lowStock.solid
              : null,
          onRowTap: (view) =>
              context.pushScreen(Routes.toOrder(storeId, view.order.id)),
          columns: [
            AppTableColumn(
              label: l10n.tableColDate,
              width: 124,
              sortKey: OrdersSortKey.date,
            ),
            AppTableColumn(
              label: l10n.tableColReference,
              width: 150,
              minTableWidth: _showsReference,
              sortKey: OrdersSortKey.reference,
            ),
            AppTableColumn(
              label: l10n.tableColSupplier,
              flex: 3,
              sortKey: OrdersSortKey.supplier,
            ),
            AppTableColumn(
              label: l10n.tableColStatus,
              width: compactStatus ? 60 : 144,
              sortKey: compactStatus ? null : OrdersSortKey.status,
            ),
            AppTableColumn(
              label: l10n.tableColLines,
              width: 84,
              numeric: true,
              minTableWidth: _showsLines,
            ),
            AppTableColumn(
              label: l10n.tableColAmount,
              width: 128,
              numeric: true,
              sortKey: OrdersSortKey.amount,
            ),
            AppTableColumn(
              label: l10n.tableColReceived,
              width: 150,
              minTableWidth: _showsReceived,
              sortKey: OrdersSortKey.received,
            ),
            AppTableColumn(label: '', width: compactActions ? 128 : 228),
          ],
          cell: (context, view, column) {
            final order = view.order;
            final at = order.sentAt ?? order.createdAt;
            return switch (column) {
              0 => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.date(at),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(Formatters.time(at), style: muted, maxLines: 1),
                ],
              ),
              1 => Text(
                order.reference,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              2 => _SupplierCell(
                view: view,
                // What the hidden reference column would have said.
                subtitle: showsReference ? '' : order.reference,
              ),
              3 => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: OrderStatusBadge(
                      status: order.status,
                      compact: compactStatus,
                    ),
                  ),
                  if (!compactStatus &&
                      orderIsStale(order, stalePartialDays)) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Tooltip(
                      message: l10n.dashboardStaleOrdersBody,
                      child: Icon(
                        LucideIcons.clock,
                        size: AppSizing.iconSm,
                        color: AppColors.lowStock.foreground,
                      ),
                    ),
                  ],
                ],
              ),
              4 => Text(
                '${order.lines.length}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              5 => Text(
                Formatters.price(orderTotal(order)),
                style: AppTypography.numeric.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
              ),
              6 =>
                order.status == PurchaseOrderStatus.draft ||
                        order.status == PurchaseOrderStatus.cancelled
                    ? Text(
                        '—',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      )
                    : ReceivedProgress(share: orderReceivedShare(order)),
              _ => Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OrderDocumentButton(order: order, compact: true),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: _QuickAction(
                      storeId: storeId,
                      view: view,
                      compact: compactActions,
                    ),
                  ),
                ],
              ),
            };
          },
        );
      },
    );
  }

  static List<OrderRowView> _sorted(
    List<OrderRowView> orders,
    OrdersSort sort,
  ) {
    final key = sort.key;
    if (key == null) return orders;

    int compare(OrderRowView a, OrderRowView b) => switch (key) {
      OrdersSortKey.date => (a.order.sentAt ?? a.order.createdAt).compareTo(
        b.order.sentAt ?? b.order.createdAt,
      ),
      OrdersSortKey.reference => a.order.reference.compareTo(b.order.reference),
      OrdersSortKey.supplier => a.supplierName.toLowerCase().compareTo(
        b.supplierName.toLowerCase(),
      ),
      OrdersSortKey.status => a.order.status.index.compareTo(
        b.order.status.index,
      ),
      OrdersSortKey.amount => orderTotal(
        a.order,
      ).compareTo(orderTotal(b.order)),
      OrdersSortKey.received => orderReceivedShare(
        a.order,
      ).compareTo(orderReceivedShare(b.order)),
    };

    return [...orders]
      ..sort((a, b) => sort.ascending ? compare(a, b) : compare(b, a));
  }
}

/// The supplier with its initials, and underneath it whatever the narrower
/// table had to leave out.
class _SupplierCell extends StatelessWidget {
  const _SupplierCell({required this.view, required this.subtitle});

  final OrderRowView view;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          view.supplierName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return Row(
      children: [
        SupplierMonogram(name: view.supplierName, size: 32),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: text),
      ],
    );
  }
}

/// The orders on a phone: the table's frame and its rows, each row stacked
/// rather than split into columns.
///
/// Supplier and amount on top, reference and date underneath, status beside
/// them, and — for an order still expecting goods — how much has arrived with
/// the button to receive the rest. Every row keeps a full-size, worded action:
/// a thumb needs a target, and an unlabelled icon asks it to guess.
class _StackedOrders extends StatelessWidget {
  const _StackedOrders({
    required this.storeId,
    required this.orders,
    required this.stalePartialDays,
  });

  final String storeId;
  final List<OrderRowView> orders;
  final int stalePartialDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, view) in orders.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.hairline),
            _StackedOrderRow(
              storeId: storeId,
              view: view,
              stale: orderIsStale(view.order, stalePartialDays),
            ),
          ],
        ],
      ),
    );
  }
}

class _StackedOrderRow extends StatelessWidget {
  const _StackedOrderRow({
    required this.storeId,
    required this.view,
    required this.stale,
  });

  final String storeId;
  final OrderRowView view;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final order = view.order;
    final at = order.sentAt ?? order.createdAt;
    final open =
        order.status == PurchaseOrderStatus.sent ||
        order.status == PurchaseOrderStatus.partial;

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => context.pushScreen(Routes.toOrder(storeId, order.id)),
        hoverColor: AppColors.neutral50,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 3,
                color: stale ? AppColors.lowStock.solid : Colors.transparent,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SupplierMonogram(name: view.supplierName, size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          view.supplierName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.xxs,
                          children: [
                            MetaItem(
                              icon: LucideIcons.hash,
                              label: order.reference,
                            ),
                            MetaItem(
                              icon: LucideIcons.calendar,
                              label:
                                  '${Formatters.date(at)} · '
                                  '${Formatters.time(at)}',
                            ),
                            if (stale)
                              MetaItem(
                                icon: LucideIcons.clock,
                                label: l10n.receptionsLate,
                                color: AppColors.lowStock.foreground,
                                emphasis: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    Formatters.price(orderTotal(order)),
                    style: AppTypography.numeric.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Flexible(child: OrderStatusBadge(status: order.status)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: open
                        ? ReceivedProgress(share: orderReceivedShare(order))
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: _QuickAction(storeId: storeId, view: view),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
