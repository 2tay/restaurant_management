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
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../dashboard/presentation/widgets/summary_tile.dart';

/// The reports hub.
///
/// Leads with the potential annual saving rather than with stock value. Stock
/// value is a number an owner already roughly knows; "you could save 3 480 € a
/// year" is the one that makes them open a report.
class ReportsDashboardPage extends ConsumerWidget {
  const ReportsDashboardPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The headline figures are derived from live stock.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Consumption and waste over the last month, valued at what the stock
    // actually cost. These were fixed constants until movements started
    // carrying a cost — which meant recording waste and then opening this
    // screen showed the figure unmoved, and a number that ignores what you just
    // told it is worse than no number.
    final from = DateTime.now().subtract(const Duration(days: 30));
    final consumed = MockQueries.consumptionValue(storeId, from: from);
    final wasted = MockQueries.wasteValue(storeId, from: from);
    final wasteShare = consumed == 0 ? 0.0 : wasted / consumed;

    return ShellPage(
      title: l10n.reportsTitle,
      subtitle: l10n.reportsSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The hook. Deliberately the largest thing on the screen.
          AppCard(
            onTap: () => context.pushScreen(Routes.toComparisonReport(storeId)),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.inStock.container,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.piggyBank,
                    size: 30,
                    color: AppColors.inStock.foreground,
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reportsPotentialSaving,
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.priceCompact(mockPotentialAnnualSaving),
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: AppColors.inStock.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.reportsPotentialSavingBody,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Icon(
                  LucideIcons.chevronRight,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: context.gridColumns(max: 3),
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.6,
            children: [
              SummaryTile(
                label: l10n.dashboardTileStockValue,
                value: Formatters.priceCompact(MockQueries.stockValuation(storeId)),
                icon: LucideIcons.wallet,
                onTap: () =>
                    context.pushScreen(Routes.toValuationReport(storeId)),
              ),
              SummaryTile(
                label: l10n.reportsUsage30Days,
                value: Formatters.priceCompact(consumed),
                icon: LucideIcons.chartLine,
                onTap: () => context.pushScreen(Routes.toUsageReport(storeId)),
              ),
              SummaryTile(
                label: l10n.reportsWasteShare,
                value: Formatters.percent(wasteShare),
                icon: LucideIcons.trash2,
                accent: AppColors.lowStock,
                caption: Formatters.price(wasted),
                onTap: () => context.pushScreen(Routes.toUsageReport(storeId)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          SectionHeader(title: l10n.reportsTitle),
          _ReportCard(
            icon: LucideIcons.scale,
            title: l10n.reportsComparison,
            body: l10n.reportsComparisonBody,
            onOpen: () =>
                context.pushScreen(Routes.toComparisonReport(storeId)),
          ),
          const SizedBox(height: AppSpacing.md),
          _ReportCard(
            icon: LucideIcons.wallet,
            title: l10n.reportsValuation,
            body: l10n.reportsValuationBody,
            onOpen: () => context.pushScreen(Routes.toValuationReport(storeId)),
          ),
          const SizedBox(height: AppSpacing.md),
          _ReportCard(
            icon: LucideIcons.chartColumn,
            title: l10n.reportsUsage,
            body: l10n.reportsUsageBody,
            onOpen: () => context.pushScreen(Routes.toUsageReport(storeId)),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onOpen,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppSizing.iconMd,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Flexible(
            child: SecondaryButton(label: l10n.reportsOpen, onPressed: onOpen),
          ),
        ],
      ),
    );
  }
}
