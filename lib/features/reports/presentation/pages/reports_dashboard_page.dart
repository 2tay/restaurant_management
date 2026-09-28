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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Consumption and waste over the last month, valued at what the stock
    // actually cost. Every figure here is a query over the movement log, so
    // recording waste and then opening this screen shows it — a number that
    // ignores what you just told it is worse than no number.
    const window = 30;
    final consumed =
        ref
            .watch(consumptionValueProvider((storeId: storeId, days: window)))
            .value ??
        0;
    final wasted =
        ref.watch(wasteValueProvider((storeId: storeId, days: window))).value ??
        0;
    final saving = ref.watch(potentialAnnualSavingProvider(storeId)).value ?? 0;
    final valuation = ref.watch(stockValuationProvider(storeId)).value ?? 0;
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
                          Formatters.priceCompact(saving),
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

          // The figures — one row, always, like the dashboard's.
          CardRow(
            minCardWidth: 190,
            scrollCardWidth: 180,
            spacing: context.isPhone ? AppSpacing.md : AppSpacing.lg,
            children: [
              SummaryTile(
                label: l10n.dashboardTileStockValue,
                value: Formatters.priceCompact(valuation),
                icon: LucideIcons.wallet,
                iconColors: AppColors.onBreak,
                caption: l10n.valuationBasis,
                onTap: () =>
                    context.pushScreen(Routes.toValuationReport(storeId)),
              ),
              SummaryTile(
                label: l10n.reportsUsage30Days,
                value: Formatters.priceCompact(consumed),
                icon: LucideIcons.chartLine,
                iconColors: AppColors.info,
                onTap: () => context.pushScreen(Routes.toUsageReport(storeId)),
              ),
              SummaryTile(
                label: l10n.reportsWasteShare,
                value: Formatters.percent(wasteShare),
                icon: LucideIcons.trash2,
                // Amber only when something was thrown away.
                accent: wasted > 0 ? AppColors.lowStock : null,
                iconColors: AppColors.inStock,
                caption: Formatters.price(wasted),
                onTap: () => context.pushScreen(Routes.toUsageReport(storeId)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.reportsTitle),
          // The three reports, side by side — one row, scrolling sideways on
          // a phone like the figures above.
          CardRow(
            minCardWidth: 220,
            scrollCardWidth: 240,
            spacing: context.isPhone ? AppSpacing.md : AppSpacing.lg,
            children: [
              _ReportCard(
                icon: LucideIcons.scale,
                colors: AppColors.inStock,
                title: l10n.reportsComparison,
                body: l10n.reportsComparisonBody,
                onOpen: () =>
                    context.pushScreen(Routes.toComparisonReport(storeId)),
              ),
              _ReportCard(
                icon: LucideIcons.wallet,
                colors: AppColors.onBreak,
                title: l10n.reportsValuation,
                body: l10n.reportsValuationBody,
                onOpen: () =>
                    context.pushScreen(Routes.toValuationReport(storeId)),
              ),
              _ReportCard(
                icon: LucideIcons.chartColumn,
                colors: AppColors.info,
                title: l10n.reportsUsage,
                body: l10n.reportsUsageBody,
                onOpen: () => context.pushScreen(Routes.toUsageReport(storeId)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One report, as a card in a row of three: its icon in its own colour, what
/// it answers, and a way in. The whole card opens it; the link at the foot
/// says so.
class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.colors,
    required this.title,
    required this.body,
    required this.onOpen,
  });

  final IconData icon;
  final StockStatusColors colors;
  final String title;
  final String body;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.container,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, size: AppSizing.iconMd, color: colors.foreground),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: theme.textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Flexible(
                child: Text(
                  l10n.reportsOpen,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primary600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                LucideIcons.arrowRight,
                size: AppSizing.iconSm,
                color: AppColors.primary600,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
