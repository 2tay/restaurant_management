import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import 'filter_pill.dart';

/// The control strip above an employee list — Personnel, Historique de
/// pointage, Historique de paiement — so the three pages read as one design.
///
/// [FilterToolbar] is the strip itself. Under it, a row of
/// [RemovableFilterChip]s shows whatever is currently applied (and carries
/// the "clear filters" action, so the strip itself has no reset button).

/// A search bar on the left, the filter controls at the right edge.
///
/// The search is as wide as [AppSizing.searchFieldMaxWidth] allows; the free
/// space between it and the controls is what spreads the strip across the
/// whole page. Where both do not fit on one line the controls drop to the next
/// one rather than squeezing the search — a 100dp search bar is no search bar.
/// On a phone the search simply fills the width.
class FilterToolbar extends StatelessWidget {
  const FilterToolbar({required this.search, required this.filters, super.key});

  /// A [SearchField], or an [EmployeeSelector] with `searchBar: true`.
  final Widget search;

  /// Pills and toggles, in reading order.
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final searchWidth = constraints.maxWidth < AppSizing.searchFieldMaxWidth
            ? constraints.maxWidth
            : AppSizing.searchFieldMaxWidth;
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(width: searchWidth, child: search),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: filters,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The period filter: one pill showing the range, which opens the range
/// calendar. Replaces a pair of "Du" / "Au" fields — one control, and the
/// picker keeps the start before the end by construction.
///
/// Tinted like any other active [FilterPill] once the range is not
/// [isDefault].
class DateRangeFilter extends StatelessWidget {
  const DateRangeFilter({
    required this.from,
    required this.to,
    required this.firstDate,
    required this.lastDate,
    required this.isDefault,
    required this.onChanged,
    super.key,
  });

  final DateTime from;
  final DateTime to;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isDefault;
  final ValueChanged<DateTimeRange> onChanged;

  /// `01/09 – 24/09/2026`, or both years in full when they differ.
  static String label(DateTime from, DateTime to) {
    final start = from.year == to.year
        ? Formatters.date(from).substring(0, 5)
        : Formatters.date(from);
    return '$start – ${Formatters.date(to)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = label(from, to);
    return Tooltip(
      message: AppLocalizations.of(context).historyFilterPeriod,
      child: InkWell(
        key: const ValueKey('date-range-filter'),
        borderRadius: AppRadius.smAll,
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            initialDateRange: DateTimeRange(start: from, end: to),
            firstDate: firstDate,
            lastDate: lastDate,
            locale: const Locale('fr', 'BE'),
          );
          if (picked != null) onChanged(picked);
        },
        child: FilterPill(
          label: text,
          selectedLabel: isDefault ? null : text,
          icon: LucideIcons.calendar,
        ),
      ),
    );
  }
}

/// One applied filter, shown beneath the bar with an ✕ that clears just that
/// one. Teal-tinted, matching the app's other selected-state chips.
class RemovableFilterChip extends StatelessWidget {
  const RemovableFilterChip({
    required this.label,
    required this.onRemove,
    super.key,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
      backgroundColor: AppColors.primaryContainer,
      labelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: AppColors.onPrimaryContainer),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.pillAll,
        side: BorderSide(color: AppColors.primary600),
      ),
      side: BorderSide.none,
    );
  }
}
