import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
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

  /// How many filters are narrowing the log, for the button that stands in for
  /// them on a phone.
  ///
  /// The period counts whenever it is not "tout", including the thirty days
  /// the screen opens on. That reads as "Filtres · 1" on a page nobody has
  /// touched, which is the truth: the log on screen is not the whole log. It
  /// also matches what [_clearFilters] does, which is to widen the period back
  /// out to everything — a count that ignored the period would leave the clear
  /// button changing something the count said was not set.
  /// Filters behind the phone's filter button. The type is not one of them:
  /// it has its own row of chips, always on screen.
  int get _activeFilterCount =>
      (_period != HistoryPeriod.all ? 1 : 0) +
      (_itemId != null ? 1 : 0) +
      (_userName != null ? 1 : 0);

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
    final items =
        ref.watch(itemsByNameProvider(widget.storeId)).value ?? const [];

    // Everyone, archived included: a movement keeps the person who recorded
    // it after they have left.
    final employeesById = {
      for (final employee
          in ref.watch(employeesProvider(widget.storeId)).value ??
              const <Employee>[])
        employee.id: employee,
    };

    return ShellPage(
      title: l10n.movementsTitle,
      subtitle: l10n.movementsSubtitle,
      scrollable: false,
      actions: [
        SecondaryButton(
          label: l10n.actionAdjustStock,
          shortLabel: l10n.shortAdjustStock,
          icon: LucideIcons.clipboardCheck,
          onPressed: () =>
              context.pushScreen(Routes.toAdjustment(widget.storeId)),
        ),
        SecondaryButton(
          label: l10n.actionLogUsage,
          shortLabel: l10n.shortLogUsage,
          icon: LucideIcons.arrowUpFromLine,
          onPressed: () =>
              context.pushScreen(Routes.toStockOut(widget.storeId)),
        ),
        PrimaryButton(
          label: l10n.actionAddDelivery,
          shortLabel: l10n.shortAddDelivery,
          icon: LucideIcons.arrowDownToLine,
          onPressed: () => context.pushScreen(Routes.toStockIn(widget.storeId)),
        ),
      ],
      child: AsyncContent<List<MovementRowView>>(
        value: rows,
        onRetry: () =>
            ref.invalidate(movementRowsForStoreProvider(widget.storeId)),
        builder: (context, allMovements) {
          // Every filter but the type, so each type chip can say how many
          // rows tapping it would show.
          final beforeType = _filtered(allMovements);
          final movements = _type == null
              ? beforeType
              : [
                  for (final row in beforeType)
                    if (row.movement.type == _type) row,
                ];
          final users =
              allMovements.map((row) => row.movement.userName).toSet().toList()
                ..sort();

          final filters = <Widget>[
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
          ];

          final counts = {
            for (final type in StockMovementType.values)
              type: beforeType.where((row) => row.movement.type == type).length,
          };
          void onType(StockMovementType? type) => setState(() => _type = type);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One row of chrome, not three. The type chips carry their own
              // counts, so the separate "N mouvements" line went; on a phone
              // the chips share their row with an icon-only filter button,
              // and the four menus live behind it.
              if (context.isPhone)
                Row(
                  children: [
                    Expanded(
                      child: _TypeSegments(
                        selected: _type,
                        total: beforeType.length,
                        counts: counts,
                        onSelected: onType,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilterSheetButton(
                      compact: true,
                      activeCount: _activeFilterCount,
                      onPressed: () => FilterSheet.show(
                        context,
                        onClear: _activeFilterCount > 0 ? _clearFilters : null,
                        // A `StatefulBuilder` so a tap inside the sheet
                        // redraws the sheet as well as the page behind it:
                        // this screen keeps its filters in `State`, not in a
                        // provider the sheet could watch.
                        builder: (context) => StatefulBuilder(
                          builder: (context, _) => Column(
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
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ..._typeChips(l10n, beforeType.length, counts, onType),
                    // A hairline between "what kind" and "which ones".
                    Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      color: AppColors.border,
                    ),
                    ...filters,
                  ],
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
                    : _GroupedList(
                        movements: movements,
                        rowBuilder: (view) => MovementRow(
                          view: view,
                          employee: view.movement.employeeId == null
                              ? null
                              : employeesById[view.movement.employeeId],
                          storeId: widget.storeId,
                          onTap: () => context.pushScreen(
                            Routes.toItem(widget.storeId, view.movement.itemId),
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

  /// One chip per movement type, in that type's colour, each with its count.
  ///
  /// Replaces a "Type" menu: the type is the filter people reach for most on
  /// this screen, and a chip is one tap where a menu was two — and the row
  /// doubles as a legend for the colours the rows below are drawn in.
  /// Tapping the chip that is already on turns it off.
  List<Widget> _typeChips(
    AppLocalizations l10n,
    int total,
    Map<StockMovementType, int> counts,
    ValueChanged<StockMovementType?> onSelected,
  ) => [
    _TypeChip(
      label: l10n.movementsFilterAllTypes,
      icon: LucideIcons.arrowRightLeft,
      count: total,
      colors: null,
      selected: _type == null,
      onTap: () => onSelected(null),
    ),
    for (final type in StockMovementType.values)
      _TypeChip(
        label: movementTypeLabel(l10n, type),
        icon: movementTypeIcon(type),
        count: counts[type] ?? 0,
        colors: movementColors(type),
        selected: _type == type,
        onTap: () => onSelected(_type == type ? null : type),
      ),
  ];

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
      if (_itemId != null && movement.itemId != _itemId) return false;
      if (_userName != null && movement.userName != _userName) return false;
      if (cutoff != null && movement.occurredAt.isBefore(cutoff)) return false;
      return true;
    }).toList();
  }
}

/// A chip-shaped dropdown filter.
/// Segments that always fit: the four types share the phone's width
/// equally, label over icon and count, and the label shrinks rather than
/// being cut off. A scrolling row of chips hid "Ajustement" off the edge of a
/// 360dp screen, where nobody knew to swipe for it.
class _TypeSegments extends StatelessWidget {
  const _TypeSegments({
    required this.selected,
    required this.total,
    required this.counts,
    required this.onSelected,
  });

  final StockMovementType? selected;
  final int total;
  final Map<StockMovementType, int> counts;
  final ValueChanged<StockMovementType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget segment({
      required String label,
      required IconData icon,
      required int count,
      required StockStatusColors? colors,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      final theme = Theme.of(context);
      final solid = colors?.solid ?? AppColors.primary600;
      final foreground = colors?.foreground ?? AppColors.onPrimaryContainer;
      final container = colors?.container ?? AppColors.primaryContainer;

      return Expanded(
        child: Semantics(
          button: true,
          selected: isSelected,
          label: '$label, $count',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.mdAll,
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.fast),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected ? container : AppColors.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: isSelected ? solid : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected ? foreground : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: AppSizing.iconSm, color: solid),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '$count',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        segment(
          label: l10n.movementsFilterAllTypes,
          icon: LucideIcons.arrowRightLeft,
          count: total,
          colors: null,
          isSelected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final type in StockMovementType.values) ...[
          const SizedBox(width: AppSpacing.xs),
          segment(
            label: movementTypeLabel(l10n, type),
            icon: movementTypeIcon(type),
            count: counts[type] ?? 0,
            colors: movementColors(type),
            isSelected: selected == type,
            onTap: () => onSelected(selected == type ? null : type),
          ),
        ],
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;

  /// Null for "Tous", which is drawn in the primary teal.
  final StockStatusColors? colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final solid = colors?.solid ?? AppColors.primary600;
    final foreground = colors?.foreground ?? AppColors.onPrimaryContainer;
    final container = colors?.container ?? AppColors.primaryContainer;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? container : AppColors.surface,
            borderRadius: AppRadius.pillAll,
            border: Border.all(
              color: selected ? solid : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppSizing.iconSm, color: solid),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? foreground : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : container,
                  borderRadius: AppRadius.pillAll,
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The history, under a header per day.
///
/// "Aujourd'hui", "Hier", then the date. Somebody checking what came in this
/// morning reads the first block and stops, instead of scanning a timestamp
/// on every row to find where today ends.
class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.movements, required this.rowBuilder});

  /// Newest first, as the repository returns them.
  final List<MovementRowView> movements;
  final Widget Function(MovementRowView view) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Headers and rows flattened into one list, so it stays lazy.
    final entries = <Object>[];
    DateTime? day;
    for (final row in movements) {
      final at = row.movement.occurredAt;
      final rowDay = DateTime(at.year, at.month, at.day);
      if (rowDay != day) {
        entries.add(rowDay);
        day = rowDay;
      }
      entries.add(row);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry is DateTime) {
          final label = entry == today
              ? l10n.dateToday
              : entry == yesterday
              ? l10n.dateYesterday
              : Formatters.dateWithWeekday(entry);
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: rowBuilder(entry as MovementRowView),
        );
      },
    );
  }
}

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
