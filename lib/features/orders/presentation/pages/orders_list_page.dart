import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
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
import '../widgets/order_detail_view.dart';
import 'create_order_page.dart';

/// Below this width the table would have to scroll sideways to show its
/// columns — a card per order reads better on a touch screen, as on the
/// pointage history.
const double _tableMinWidth = 860;

/// A table column the orders can be sorted by.
enum OrdersSortKey { date, reference, supplier, status, amount, received }

/// Every commande for the current store — laid out like the pointage history:
/// KPI tiles, the search and filter strip, the active filters, then the table
/// (cards on a narrow screen) and its paginator.
class OrdersListPage extends ConsumerStatefulWidget {
  const OrdersListPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends ConsumerState<OrdersListPage> {
  String _query = '';
  String? _supplierId;
  PurchaseOrderStatus? _status;

  /// The first day shown, or null for "since the first order" — nothing is
  /// hidden until the manager narrows the period.
  DateTime? _from;

  /// The last day shown, or null for today.
  DateTime? _to;

  OrdersSortKey? _sortKey;
  bool _sortAscending = true;
  int _page = 0;
  int _pageSize = Paginator.defaultPageSizes.first;

  bool get _rangeIsDefault => _from == null && _to == null;

  int get _activeFilterCount =>
      (_rangeIsDefault ? 0 : 1) +
      (_supplierId == null ? 0 : 1) +
      (_status == null ? 0 : 1);

  void _update(VoidCallback change) => setState(() {
    change();
    _page = 0;
  });

  void _clearFilters() => _update(() {
    _from = null;
    _to = null;
    _supplierId = null;
    _status = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Sending, receiving and cancelling all happen on screens pushed above this
    // one. The query watches the tables they write to, so the list is correct
    // when the user comes back rather than showing what it read on the way in.
    final rows = ref.watch(orderRowsProvider(widget.storeId));
    final suppliers =
        ref.watch(suppliersProvider(widget.storeId)).value ?? const [];
    final staleDays =
        ref.watch(stalePartialOrderDaysProvider(widget.storeId)).value ??
        OrderRules.defaultStalePartialDays;

    return ShellPage(
      title: l10n.ordersTitle,
      subtitle: l10n.ordersSubtitle,
      actions: [
        PrimaryButton(
          label: l10n.ordersNewAction,
          shortLabel: l10n.shortNewOrder,
          icon: LucideIcons.plus,
          onPressed: () => createOrder(context, storeId: widget.storeId),
        ),
      ],
      child: AsyncContent<List<OrderRowView>>(
        value: rows,
        onRetry: () => ref.invalidate(orderRowsProvider(widget.storeId)),
        builder: (context, all) => _content(l10n, all, suppliers, staleDays),
      ),
    );
  }

  Widget _content(
    AppLocalizations l10n,
    List<OrderRowView> all,
    List<Supplier> suppliers,
    int staleDays,
  ) {
    final today = dayOf(clock.now());
    final to = _to ?? today;
    final earliest = all.isEmpty
        ? today
        : all
              .map((v) => dayOf(_dateOf(v.order)))
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final from = _from ?? (earliest.isAfter(to) ? to : earliest);

    final orders = _sorted(_visible(all));
    final pageCount = math.max(1, (orders.length / _pageSize).ceil());
    final page = math.min(_page, pageCount - 1);
    final shown = orders
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow(orders: orders, staleDays: staleDays),
        const SizedBox(height: AppSpacing.lg),
        FilterToolbar(
          activeCount: _activeFilterCount,
          onClear: _clearFilters,
          search: SearchField(
            hint: l10n.ordersSearchHint,
            initialValue: _query,
            onChanged: (q) => _update(() => _query = q.trim()),
          ),
          filters: [
            FilterMenu<String?>(
              label: l10n.inventoryFilterSupplier,
              selectedLabel: _supplierName(suppliers),
              entries: {
                null: l10n.inventoryFilterAllSuppliers,
                for (final s in suppliers) s.id: s.name,
              },
              onSelected: (id) => _update(() => _supplierId = id),
            ),
            DateFilter(
              key: const ValueKey('orders-date-from'),
              label: l10n.historyFilterFrom,
              value: from,
              firstDate: DateTime(2000),
              lastDate: to,
              isDefault: _from == null,
              onChanged: (d) => _update(() => _from = dayOf(d)),
            ),
            DateFilter(
              key: const ValueKey('orders-date-to'),
              label: l10n.historyFilterTo,
              value: to,
              firstDate: from,
              lastDate: today,
              isDefault: _to == null,
              onChanged: (d) => _update(() {
                _to = dayOf(d);
                if (_from != null && _from!.isAfter(_to!)) _from = _to;
              }),
            ),
            FilterMenu<PurchaseOrderStatus?>(
              label: l10n.ordersFilterStatus,
              selectedLabel: _status == null
                  ? null
                  : OrderStatusBadge.labelFor(l10n, _status!),
              entries: {
                null: l10n.ordersFilterAllStatuses,
                for (final s in PurchaseOrderStatus.values)
                  s: OrderStatusBadge.labelFor(l10n, s),
              },
              onSelected: (s) => _update(() => _status = s),
            ),
          ],
        ),
        if (_activeFilterCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_supplierId != null)
                RemovableFilterChip(
                  label: _supplierName(suppliers) ?? '—',
                  onRemove: () => _update(() => _supplierId = null),
                ),
              if (!_rangeIsDefault)
                RemovableFilterChip(
                  label: l10n.ordersFilterDateRange(
                    Formatters.date(from),
                    Formatters.date(to),
                  ),
                  onRemove: () => _update(() {
                    _from = null;
                    _to = null;
                  }),
                ),
              if (_status != null)
                RemovableFilterChip(
                  label: OrderStatusBadge.labelFor(l10n, _status!),
                  onRemove: () => _update(() => _status = null),
                ),
              TextButton(
                onPressed: _clearFilters,
                child: Text(l10n.inventoryClearFilters),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.ordersCount(orders.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (orders.isEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 360),
            child: _Empty(
              storeId: widget.storeId,
              storeHasOrders: all.isNotEmpty,
              onClearFilters: _clearFilters,
            ),
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= _tableMinWidth
                ? _OrdersTable(
                    storeId: widget.storeId,
                    orders: shown,
                    staleDays: staleDays,
                    sortKey: _sortKey,
                    sortAscending: _sortAscending,
                    onSort: (key) => setState(() {
                      // A new column sorts ascending; the same column again
                      // flips direction.
                      _sortAscending = _sortKey == key ? !_sortAscending : true;
                      _sortKey = key;
                    }),
                  )
                : _OrderCards(
                    storeId: widget.storeId,
                    orders: shown,
                    staleDays: staleDays,
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Paginator(
            page: page,
            pageCount: pageCount,
            totalCount: orders.length,
            pageSize: _pageSize,
            onChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (size) => _update(() => _pageSize = size),
          ),
        ],
      ],
    );
  }

  String? _supplierName(List<Supplier> suppliers) {
    final id = _supplierId;
    if (id == null) return null;
    for (final s in suppliers) {
      if (s.id == id) return s.name;
    }
    return '—';
  }

  static DateTime _dateOf(PurchaseOrder order) =>
      order.sentAt ?? order.createdAt;

  /// The search and the filters, applied over rows already in hand.
  List<OrderRowView> _visible(List<OrderRowView> rows) {
    final query = _query.toLowerCase();

    return rows.where((view) {
      final order = view.order;
      if (_status != null && order.status != _status) return false;
      if (_supplierId != null && order.supplierId != _supplierId) {
        return false;
      }
      final day = dayOf(_dateOf(order));
      if (_from != null && day.isBefore(_from!)) return false;
      if (_to != null && day.isAfter(_to!)) return false;
      if (query.isNotEmpty &&
          !order.reference.toLowerCase().contains(query) &&
          !view.supplierName.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Null [_sortKey] keeps the newest-first order the list comes in with.
  List<OrderRowView> _sorted(List<OrderRowView> orders) {
    final key = _sortKey;
    if (key == null) return orders;

    int compare(OrderRowView a, OrderRowView b) => switch (key) {
      OrdersSortKey.date => _dateOf(a.order).compareTo(_dateOf(b.order)),
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
      ..sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
  }
}

// -----------------------------------------------------------------------------

/// The KPI tiles over the orders the search and filters leave: how many, what
/// they commit the store to, how many still expect goods, how many are late.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.orders, required this.staleDays});

  final List<OrderRowView> orders;
  final int staleDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    var total = 0.0;
    var toReceive = 0;
    var late = 0;
    for (final view in orders) {
      final order = view.order;
      total += orderTotal(order);
      if (order.status == PurchaseOrderStatus.sent ||
          order.status == PurchaseOrderStatus.partial) {
        toReceive++;
      }
      if (orderIsStale(order, staleDays)) late++;
    }

    return StatTileRow(
      tiles: [
        StatTile(
          label: l10n.ordersStatCount,
          value: '${orders.length}',
          icon: LucideIcons.clipboardList,
        ),
        StatTile(
          label: l10n.ordersStatAmount,
          value: Formatters.price(total),
          icon: LucideIcons.wallet,
        ),
        StatTile(
          label: l10n.ordersStatToReceive,
          value: '$toReceive',
          icon: LucideIcons.truck,
        ),
        StatTile(
          label: l10n.ordersStatLate,
          value: '$late',
          icon: LucideIcons.clockAlert,
          accent: late == 0 ? null : AppColors.lowStock,
        ),
      ],
    );
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
      onAction: () => createOrder(context, storeId: storeId),
    );
  }
}

/// The one thing to do next with an order: send a draft, receive a sent or
/// partial one. A received or cancelled order has nothing left to do.
///
/// [compact] draws it as an icon button with the label in a tooltip, for the
/// table's action column.
class _QuickAction extends ConsumerWidget {
  const _QuickAction({
    required this.storeId,
    required this.view,
    this.compact = false,
  });

  final String storeId;
  final OrderRowView view;
  final bool compact;

  static bool hasAction(PurchaseOrder order) =>
      order.status == PurchaseOrderStatus.draft ||
      order.status == PurchaseOrderStatus.sent ||
      order.status == PurchaseOrderStatus.partial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = view.order;
    if (!hasAction(order)) return const SizedBox.shrink();

    final draft = order.status == PurchaseOrderStatus.draft;
    final label = draft ? l10n.orderActionSend : l10n.receptionsReceive;
    final icon = draft ? LucideIcons.send : LucideIcons.packageCheck;
    void onPressed() => draft
        ? confirmSendOrder(context, ref, order, view.supplierName)
        : context.pushScreen(Routes.toReceiveOrder(storeId, order.id));

    if (compact) {
      final glyph = Icon(icon, size: AppSizing.iconSm);
      return draft
          ? IconButton.outlined(
              onPressed: onPressed,
              tooltip: label,
              icon: glyph,
            )
          : IconButton.filled(
              onPressed: onPressed,
              tooltip: label,
              icon: glyph,
            );
    }

    return draft
        ? SecondaryButton(label: label, icon: icon, onPressed: onPressed)
        : PrimaryButton(label: label, icon: icon, onPressed: onPressed);
  }
}

/// One line per order: Date / Référence / Fournisseur / Statut / Montant /
/// Reçu, then the document and the next action. Clicking the row opens the
/// order panel — the same table as the pointage history.
class _OrdersTable extends StatelessWidget {
  const _OrdersTable({
    required this.storeId,
    required this.orders,
    required this.staleDays,
    required this.sortKey,
    required this.sortAscending,
    required this.onSort,
  });

  final String storeId;
  final List<OrderRowView> orders;
  final int staleDays;
  final OrdersSortKey? sortKey;
  final bool sortAscending;
  final ValueChanged<OrdersSortKey> onSort;

  /// The sort key of each column, in column order; null is not sortable.
  static const _columnKeys = [
    OrdersSortKey.date,
    OrdersSortKey.reference,
    OrdersSortKey.supplier,
    OrdersSortKey.status,
    OrdersSortKey.amount,
    OrdersSortKey.received,
    null,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.tableColDate,
      l10n.tableColReference,
      l10n.tableColSupplier,
      l10n.tableColStatus,
      l10n.tableColAmount,
      l10n.tableColReceived,
      '',
    ];
    final sortIndex = sortKey == null ? null : _columnKeys.indexOf(sortKey);

    return DataTableWrapper(
      minWidth: _tableMinWidth,
      sortColumnIndex: sortIndex,
      sortAscending: sortAscending,
      columns: [
        for (final (i, key) in _columnKeys.indexed)
          DataColumn(
            label: Text(labels[i]),
            numeric: key == OrdersSortKey.amount,
            onSort: key == null ? null : (_, _) => onSort(key),
          ),
      ],
      rows: [for (final view in orders) _row(context, l10n, view)],
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, OrderRowView view) {
    final theme = Theme.of(context);
    final order = view.order;
    final at = order.sentAt ?? order.createdAt;
    final stale = orderIsStale(order, staleDays);
    final pending =
        order.status == PurchaseOrderStatus.draft ||
        order.status == PurchaseOrderStatus.cancelled;

    return DataRow(
      onSelectChanged: (_) =>
          openOrderPanel(context, storeId: storeId, orderId: order.id),
      cells: [
        DataCell(WeekdayDate(at)),
        DataCell(
          Text(
            order.reference,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SupplierMonogram(name: view.supplierName, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  view.supplierName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrderStatusBadge(status: order.status),
              if (stale) ...[
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
        ),
        DataCell(
          NumericCell(Formatters.price(orderTotal(order)), emphasis: true),
        ),
        DataCell(
          pending
              ? Text(
                  '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textDisabled,
                  ),
                )
              : SizedBox(
                  width: 120,
                  child: ReceivedProgress(share: orderReceivedShare(order)),
                ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrderDocumentButton(order: order, compact: true),
              if (_QuickAction.hasAction(order)) ...[
                const SizedBox(width: AppSpacing.xs),
                _QuickAction(storeId: storeId, view: view, compact: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The orders as a grid of cards — the table's small-screen alternative, the
/// same [ResponsiveCardGrid] as the pointage history's day cards.
class _OrderCards extends StatelessWidget {
  const _OrderCards({
    required this.storeId,
    required this.orders,
    required this.staleDays,
  });

  final String storeId;
  final List<OrderRowView> orders;
  final int staleDays;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCardGrid(
      children: [
        for (final view in orders)
          _OrderCard(
            storeId: storeId,
            view: view,
            stale: orderIsStale(view.order, staleDays),
          ),
      ],
    );
  }
}

/// One order, as a card: the date and the status on top ([CardDateHeader]),
/// the supplier and reference, the amount and how much has arrived side by
/// side, then the document and the next action. The whole card opens the
/// order panel.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
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
    final pending =
        order.status == PurchaseOrderStatus.draft ||
        order.status == PurchaseOrderStatus.cancelled;

    return AppCard(
      onTap: () => openOrderPanel(context, storeId: storeId, orderId: order.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardDateHeader(
            date: order.sentAt ?? order.createdAt,
            status: OrderStatusBadge(status: order.status),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
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
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // IntrinsicHeight so the two tiles match when one label wraps.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CardFigure(
                    label: l10n.tableColAmount,
                    child: Text(
                      Formatters.price(orderTotal(order)),
                      style: AppTypography.numeric.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _CardFigure(
                    label: l10n.tableColReceived,
                    child: pending
                        ? Text(
                            '—',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textDisabled,
                            ),
                          )
                        : ReceivedProgress(share: orderReceivedShare(order)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OrderDocumentButton(order: order, compact: true),
              if (_QuickAction.hasAction(order)) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _QuickAction(storeId: storeId, view: view),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One figure on an [_OrderCard] — a small grey label over the value, on a
/// grey tile, like the pointage history's cards.
class _CardFigure extends StatelessWidget {
  const _CardFigure({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}
