import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Price history for one item–supplier **pair**.
///
/// Scoped to the pair, never to the item alone. "What has this supplier charged
/// us for chicken over six months" is answerable; "what has chicken cost" is
/// not, because several suppliers charge different amounts at the same time.
class ItemPriceHistoryPage extends ConsumerWidget {
  const ItemPriceHistoryPage({
    required this.storeId,
    required this.itemId,
    required this.supplierId,
    super.key,
  });

  final String storeId;
  final String itemId;
  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Receiving a delivery at a different price appends to this history, and
    // both queries below watch the tables it touches — so the chart grows a row
    // while somebody is looking at it.
    final data = asyncAll3(
      ref.watch(itemRowProvider(itemId)),
      ref.watch(itemPricingProvider(itemId)),
      ref.watch(
        priceHistoryProvider((itemId: itemId, supplierId: supplierId)),
      ),
      (row, pricing, entries) => (
        row: row,
        pricing: pricing,
        entries: entries,
      ),
    );

    return AsyncContent<
      ({
        ItemRowView? row,
        ItemPricing pricing,
        List<PriceHistoryEntry> entries,
      })
    >(
      value: data,
      skeleton: ShellPage(
        title: l10n.priceHistoryTitle,
        child: const SkeletonList(rows: 4, rowHeight: 90),
      ),
      onRetry: () {
        ref.invalidate(itemRowProvider(itemId));
        ref.invalidate(itemPricingProvider(itemId));
        ref.invalidate(
          priceHistoryProvider((itemId: itemId, supplierId: supplierId)),
        );
      },
      builder: (context, data) {
        final row = data.row;

        // The offer this page is about. Null when the supplier has been
        // unlinked since — the history survives the link, but a page titled
        // "prices from this supplier" has nothing left to head itself with.
        SupplierPriceView? entry;
        for (final candidate in data.pricing.prices) {
          if (candidate.price.supplierId == supplierId) entry = candidate;
        }

        if (row == null || entry == null) {
          return ShellPage(
            title: l10n.priceHistoryTitle,
            child: ErrorState(
              onRetry: () => context.goSection(Routes.toInventory(storeId)),
            ),
          );
        }

        return _body(context, l10n, row, entry, data.entries);
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ItemRowView row,
    SupplierPriceView entry,
    List<PriceHistoryEntry> entries,
  ) {
    final item = row.item;
    final unit = row.unitAbbreviation;
    final current = entry.price;
    final supplierName = entry.supplierName;

    // Oldest recorded price, for the total-change figure. Falls back to the
    // current price when nothing has ever changed.
    final firstPrice = entries.isEmpty
        ? current.pricePerUnit
        : entries.last.oldPrice;
    final totalChange = current.pricePerUnit - firstPrice;

    return ShellPage(
      back: BackDestination(
        label: item.name,
        path: Routes.toItem(storeId, itemId),
      ),
      crumbs: [
        Crumb(l10n.inventoryTitle, Routes.toInventory(storeId)),
        Crumb(item.name, Routes.toItem(storeId, itemId)),
        Crumb(l10n.priceHistoryTitle),
      ],
      title: l10n.priceHistoryTitle,
      subtitle: l10n.priceHistoryFor(item.name, supplierName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // IntrinsicHeight so the two tiles match height regardless of which
          // has the longer caption. CrossAxisAlignment.stretch would be the
          // obvious choice but needs a bounded height, and this Row sits in a
          // scrollable where height is unbounded.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: l10n.priceHistoryCurrent,
                    value: '${Formatters.price(current.pricePerUnit)} / $unit',
                    caption: l10n.priceHistorySince(
                      Formatters.date(current.effectiveDate),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _SummaryTile(
                    label: l10n.priceHistoryTotalChange,
                    value: Formatters.priceDelta(totalChange),
                    caption: l10n.priceHistoryChanges(entries.length),
                    // Rising costs are the bad direction here, so up is amber.
                    valueColor: totalChange > 0
                        ? AppColors.lowStock.foreground
                        : totalChange < 0
                        ? AppColors.inStock.foreground
                        : null,
                    icon: totalChange > 0
                        ? LucideIcons.trendingUp
                        : totalChange < 0
                        ? LucideIcons.trendingDown
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (entries.isEmpty)
            AppCard(
              child: EmptyState(
                icon: LucideIcons.chartLine,
                title: l10n.priceHistoryEmpty,
                message: l10n.priceHistoryEmptyBody,
              ),
            )
          else ...[
            AppCard(
              child: SizedBox(
                height: 260,
                child: _PriceChart(
                  entries: entries,
                  currentPrice: current.pricePerUnit,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: l10n.priceHistoryChanges(entries.length),
              count: null,
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final entry in entries)
                    _HistoryRow(entry: entry, unit: unit),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The price line over time.
///
/// A stepped line, not a smooth curve: a price holds flat until it is changed,
/// and interpolating between changes would draw movement that never happened.
class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.entries, required this.currentPrice});

  final List<PriceHistoryEntry> entries;
  final double currentPrice;

  @override
  Widget build(BuildContext context) {
    // Oldest first for plotting; the list above is newest first.
    final ordered = entries.reversed.toList();

    final spots = <FlSpot>[
      FlSpot(0, ordered.first.oldPrice),
      for (var i = 0; i < ordered.length; i++)
        FlSpot((i + 1).toDouble(), ordered[i].newPrice),
    ];

    final values = spots.map((spot) => spot.y).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxValue - minValue) * 0.25).clamp(0.2, 5.0);

    return LineChart(
      LineChartData(
        minY: minValue - padding,
        maxY: maxValue + padding,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 64,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  Formatters.priceCompact(value),
                  style: AppTypography.chartLabel,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 1 || index > ordered.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    Formatters.dayMonth(ordered[index - 1].changedAt),
                    style: AppTypography.chartLabel,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            isStepLineChart: true,
            color: AppColors.primary600,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.primary600,
                strokeColor: AppColors.surface,
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.neutral900,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  Formatters.price(spot.y),
                  const TextStyle(color: AppColors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.unit});

  final PriceHistoryEntry entry;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final difference = entry.newPrice - entry.oldPrice;
    final rose = difference > 0;
    final colors = rose ? AppColors.lowStock : AppColors.inStock;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.container,
              shape: BoxShape.circle,
            ),
            child: Icon(
              rose ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
              size: AppSizing.iconSm,
              color: colors.foreground,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.date(entry.changedAt),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  l10n.priceHistoryChangedBy(entry.changedByName),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${Formatters.price(entry.oldPrice)} → ${Formatters.price(entry.newPrice)}',
                style: AppTypography.numeric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 96,
            child: Text(
              Formatters.priceDelta(difference),
              textAlign: TextAlign.right,
              style: AppTypography.numeric.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.caption,
    this.valueColor,
    this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: valueColor, size: AppSizing.iconLg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  value,
                  style: AppTypography.numericHero.copyWith(color: valueColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(caption, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
