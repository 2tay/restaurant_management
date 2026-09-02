import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/movement_labels.dart';
import '../widgets/movement_row.dart';

/// A date range for the history filter.
enum HistoryPeriod {
  last7(7),
  last30(30),
  last90(90),
  all(null);

  const HistoryPeriod(this.days);

  final int? days;
}

/// The chronological movement log.
///
/// Filterable by type, period, item and user — the four questions actually
/// asked of a stock log: "what came in this week", "who logged that", "what
/// happened to the chicken", "how much did we throw away".
class StockHistoryPage extends ConsumerStatefulWidget {
  const StockHistoryPage({
    required this.storeId,
    this.initialItemId,
    super.key,
  });

  final String storeId;

  /// The product to open the log on, from `?item=` — see [Routes.toMovements].
  ///
  /// A starting point rather than a lock: the filter menu is exactly where it
  /// always is, and clearing it shows the whole store again.
  final String? initialItemId;

  @override
  ConsumerState<StockHistoryPage> createState() => _StockHistoryPageState();
}

class _StockHistoryPageState extends ConsumerState<StockHistoryPage> {
  StockMovementType? _type;
  HistoryPeriod _period = HistoryPeriod.last30;
  String? _itemId;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _applyRoute();
  }

  /// Re-reads the route when it changes underneath a page that is still alive.
  ///
  /// The shell keeps a section page mounted while it is the current one, so
  /// `initState` runs once and going from a product's log to the sidebar's
  /// "Mouvements" would otherwise leave the product filter on — the sidebar
  /// destination showing a filtered list nobody asked it for, with no
  /// indication that it was inherited from the screen before.
  ///
  /// Guarded on the route actually having changed, so a filter the user picked
  /// by hand survives an ordinary rebuild.
  @override
  void didUpdateWidget(StockHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItemId != oldWidget.initialItemId) {
      setState(_applyRoute);
    }
  }

  /// The filters the route asks for.
  ///
  /// Arriving on one product widens the period to everything. The product page
  /// lists its last movements with no date limit at all, so "voir tout" under
  /// a delivery from two months ago would otherwise land on an empty screen —
  /// the filter the user did not choose silently hiding the rows they clicked
  /// to see. Thirty days is the right default for the whole store, where the
  /// list is long; it is the wrong one for a single product, where it is
  /// short.
  void _applyRoute() {
    _itemId = widget.initialItemId;
    _period = _itemId == null ? HistoryPeriod.last30 : HistoryPeriod.all;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Every movement recorded anywhere in the app lands in this list, and it
    // arrives here without being announced: the query watches the table.
    //
    // The four filters stay in Dart. They are all over rows already in hand,
    // and pushing them into SQL would put four more shapes of query behind a
    // screen whose entire job is to let somebody try one filter after another.
    final rows = ref.watch(movementRowsForStoreProvider(widget.storeId));

    // Empty while its query is out. The menu shows only "tous les articles"
    // for that frame, which is the correct set of choices given what is known.
    final items = ref.watch(itemsByNameProvider(widget.storeId)).value ?? const [];

    return ShellPage(
      title: l10n.movementsTitle,
      subtitle: l10n.movementsSubtitle,
      scrollable: false,
      actions: [
        SecondaryButton(
          label: l10n.actionAdjustStock,
          icon: LucideIcons.clipboardCheck,
          onPressed: () =>
              context.pushScreen(Routes.toAdjustment(widget.storeId)),
        ),
        SecondaryButton(
          label: l10n.actionLogUsage,
          icon: LucideIcons.arrowUpFromLine,
          onPressed: () =>
              context.pushScreen(Routes.toStockOut(widget.storeId)),
        ),
        PrimaryButton(
          label: l10n.actionAddDelivery,
          icon: LucideIcons.arrowDownToLine,
          onPressed: () => context.pushScreen(Routes.toStockIn(widget.storeId)),
        ),
      ],
      child: AsyncContent<List<MovementRowView>>(
        value: rows,
        onRetry: () => ref.invalidate(movementRowsForStoreProvider(widget.storeId)),
        builder: (context, allMovements) {
          final movements = _filtered(allMovements);
          final users =
              allMovements.map((row) => row.movement.userName).toSet().toList()
                ..sort();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Menu<StockMovementType?>(
                    label: l10n.movementsFilterType,
                    selectedLabel: _type == null
                        ? null
                        : movementTypeLabel(l10n, _type!),
                    entries: {
                      null: l10n.movementsFilterAllTypes,
                      for (final type in StockMovementType.values)
                        type: movementTypeLabel(l10n, type),
                    },
                    onSelected: (value) => setState(() => _type = value),
                  ),
                  _Menu<HistoryPeriod>(
                    label: l10n.movementsFilterPeriod,
                    selectedLabel: _periodLabel(l10n, _period),
                    entries: {
                      for (final period in HistoryPeriod.values)
                        period: _periodLabel(l10n, period),
                    },
                    onSelected: (value) => setState(() => _period = value),
                  ),
                  _Menu<String?>(
                    label: l10n.stockInItem,
                    selectedLabel: _itemName(items),
                    entries: {
                      null: l10n.inventoryFilterAllSuppliers,
                      for (final item in items) item.id: item.name,
                    },
                    onSelected: (value) => setState(() => _itemId = value),
                  ),
                  _Menu<String?>(
                    label: l10n.movementsFilterUser,
                    selectedLabel: _userName,
                    entries: {
                      null: l10n.movementsFilterAllUsers,
                      for (final user in users) user: user,
                    },
                    onSelected: (value) => setState(() => _userName = value),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.movementsCount(movements.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),

              Expanded(
                child: movements.isEmpty
                    ? EmptyState(
                        icon: LucideIcons.arrowRightLeft,
                        title: allMovements.isEmpty
                            ? l10n.movementsEmpty
                            : l10n.emptyStateNoResultsTitle,
                        message: allMovements.isEmpty
                            ? l10n.movementsEmptyBody
                            : l10n.emptyStateNoResultsBody,
                        actionLabel: allMovements.isEmpty
                            ? l10n.actionAddDelivery
                            : l10n.inventoryClearFilters,
                        onAction: allMovements.isEmpty
                            ? () => context.pushScreen(
                                Routes.toStockIn(widget.storeId),
                              )
                            : _clearFilters,
                      )
                    : ListView.separated(
                        itemCount: movements.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => MovementRow(
                          view: movements[index],
                          storeId: widget.storeId,
                          onTap: () => context.pushScreen(
                            Routes.toItem(
                              widget.storeId,
                              movements[index].movement.itemId,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _itemName(List<Item> items) {
    if (_itemId == null) return null;
    for (final item in items) {
      if (item.id == _itemId) return item.name;
    }
    return null;
  }

  void _clearFilters() {
    setState(() {
      _type = null;
      _period = HistoryPeriod.all;
      _itemId = null;
      _userName = null;
    });
  }

  String _periodLabel(AppLocalizations l10n, HistoryPeriod period) =>
      switch (period) {
        HistoryPeriod.last7 => l10n.periodLast7Days,
        HistoryPeriod.last30 => l10n.periodLast30Days,
        HistoryPeriod.last90 => l10n.periodLast90Days,
        HistoryPeriod.all => l10n.periodAll,
      };

  List<MovementRowView> _filtered(List<MovementRowView> rows) {
    final cutoff = _period.days == null
        ? null
        : DateTime.now().subtract(Duration(days: _period.days!));

    return rows.where((row) {
      final movement = row.movement;
      if (_type != null && movement.type != _type) return false;
      if (_itemId != null && movement.itemId != _itemId) return false;
      if (_userName != null && movement.userName != _userName) return false;
      if (cutoff != null && movement.occurredAt.isBefore(cutoff)) return false;
      return true;
    }).toList();
  }
}

/// A chip-shaped dropdown filter.
class _Menu<T> extends StatelessWidget {
  const _Menu({
    required this.label,
    required this.selectedLabel,
    required this.entries,
    required this.onSelected,
  });

  final String label;
  final String? selectedLabel;
  final Map<T, String> entries;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (index) => onSelected(entries.keys.elementAt(index)),
      itemBuilder: (context) => [
        for (var i = 0; i < entries.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(entries.values.elementAt(i)),
          ),
      ],
      child: FilterPill(label: label, selectedLabel: selectedLabel),
    );
  }
}
