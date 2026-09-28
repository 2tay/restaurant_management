import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
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

/// One end of a period — "Début" or "Fin" — as a pill that opens the
/// calendar. Two of these sit side by side in the [FilterToolbar]; with no
/// label above them, the pill carries its own ("Début : 01/09/2026").
///
/// Tinted like any other active [FilterPill] once [value] is not [isDefault].
class DateFilter extends StatelessWidget {
  const DateFilter({
    required this.label,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.isDefault,
    required this.onChanged,
    super.key,
  });

  /// "Début" / "Fin".
  final String label;
  final DateTime value;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isDefault;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = '$label : ${Formatters.date(value)}';
    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
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
