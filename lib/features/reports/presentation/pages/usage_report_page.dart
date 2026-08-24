import 'package:fl_chart/fl_chart.dart';
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
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../dashboard/presentation/widgets/summary_tile.dart';
import '../widgets/export_dialog.dart';

/// What left the stock, and how much of it was wasted.
///
/// Two charts: daily consumption value, and waste as a share of it. Waste is
/// shown as a share rather than an absolute, because absolute waste rises with
/// a busy week and tells you nothing on its own.
class UsageReportPage extends ConsumerStatefulWidget {
  const UsageReportPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<UsageReportPage> createState() => _UsageReportPageState();
}

class _UsageReportPageState extends ConsumerState<UsageReportPage> {
  int _rangeDays = 30;

  @override
  Widget build(BuildContext context) {
    // Usage is read from the movement log, which every stock-out appends to.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);

    final usage = mockUsageTrend
        .where(
          (point) => point.date.isAfter(
            DateTime.now().subtract(Duration(days: _rangeDays)),
          ),
        )
        .toList();

    final total = usage.fold<double>(0, (sum, point) => sum + point.value);

    return ShellPage(
      back: BackDestination(
        label: l10n.reportsTitle,
        path: Routes.toReports(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.reportsTitle, Routes.toReports(widget.storeId)),
        Crumb(l10n.usageReportTitle),
      ],
      title: l10n.usageReportTitle,
      subtitle: l10n.reportsUsageBody,
      actions: [
        _RangeSelector(
          days: _rangeDays,
          onChanged: (value) => setState(() => _rangeDays = value),
        ),
        SecondaryButton(
          label: l10n.actionExport,
          icon: LucideIcons.download,
          onPressed: () => ExportDialog.show(context),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: context.gridColumns(max: 3),
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.6,
            children: [
              SummaryTile(
                label: l10n.usageTotal,
                value: Formatters.priceCompact(total),
                icon: LucideIcons.chartLine,
              ),
              SummaryTile(
                label: l10n.reportsWasteShare,
                value: Formatters.percent(mockWasteShareLast30Days),
                icon: LucideIcons.trash2,
                accent: AppColors.lowStock,
              ),
              SummaryTile(
                label: l10n.usageWasteValue,
                value: Formatters.priceCompact(mockWasteValueLast30Days),
                icon: LucideIcons.ban,
                accent: AppColors.lowStock,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.usageTrend),
          AppCard(
            child: SizedBox(height: 280, child: _UsageChart(points: usage)),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.usageWasteTrend),
          AppCard(
            child: SizedBox(
              height: 240,
              child: _WasteChart(points: mockWasteTrend),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final labels = {
      7: l10n.periodLast7Days,
      30: l10n.periodLast30Days,
      90: l10n.periodLast90Days,
    };

    return PopupMenuButton<int>(
      tooltip: l10n.movementsFilterPeriod,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final entry in labels.entries)
          PopupMenuItem<int>(value: entry.key, child: Text(entry.value)),
      ],
      child: FilterPill(
        label: l10n.movementsFilterPeriod,
        selectedLabel: labels[days],
        icon: LucideIcons.calendar,
      ),
    );
  }
}

/// Daily consumption value.
class _UsageChart extends StatelessWidget {
  const _UsageChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).emptyStateNoResultsTitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final maxValue = points
        .map((point) => point.value)
        .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxValue * 1.15,
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
              reservedSize: 60,
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
              reservedSize: 30,
              // Every label would be unreadable at 30 bars, so show roughly
              // one a week.
              interval: (points.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    Formatters.dayMonth(points[index].date),
                    style: AppTypography.chartLabel,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].value,
                  color: AppColors.primary600,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.neutral900,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  '${Formatters.dayMonth(points[group.x].date)}\n'
                  '${Formatters.price(rod.toY)}',
                  const TextStyle(color: AppColors.white),
                ),
          ),
        ),
      ),
    );
  }
}

/// Waste as a share of consumption, weekly.
class _WasteChart extends StatelessWidget {
  const _WasteChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 0.1,
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
              reservedSize: 60,
              interval: 0.025,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  Formatters.percent(value),
                  style: AppTypography.chartLabel,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    Formatters.dayMonth(points[index].date),
                    style: AppTypography.chartLabel,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            color: AppColors.lowStock.solid,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.lowStock.solid,
                strokeColor: AppColors.surface,
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.lowStock.container.withValues(alpha: 0.6),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.neutral900,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  Formatters.percent(spot.y),
                  const TextStyle(color: AppColors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
