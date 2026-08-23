import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
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
class StockHistoryPage extends StatefulWidget {
  const StockHistoryPage({required this.storeId, super.key});

  final String storeId;

  @override
  State<StockHistoryPage> createState() => _StockHistoryPageState();
}

class _StockHistoryPageState extends State<StockHistoryPage> {
  StockMovementType? _type;
  HistoryPeriod _period = HistoryPeriod.last30;
  String? _itemId;
  String? _userName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final movements = _filtered();
    final allMovements = MockQueries.movementsForStore(widget.storeId);

    final users = allMovements.map((m) => m.userName).toSet().toList()..sort();
    final items = MockQueries.itemsForStore(widget.storeId);

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
      child: Column(
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
                selectedLabel: _itemId == null
                    ? null
                    : MockQueries.itemById(_itemId!)?.name,
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
                      movement: movements[index],
                      onTap: () => context.pushScreen(
                        Routes.toItem(widget.storeId, movements[index].itemId),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
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

  List<StockMovement> _filtered() {
    final cutoff = _period.days == null
        ? null
        : DateTime.now().subtract(Duration(days: _period.days!));

    return MockQueries.movementsForStore(widget.storeId).where((movement) {
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
