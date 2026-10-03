import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import 'app_date_picker.dart';
import 'filter_pill.dart';
import 'filter_sheet.dart';

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
/// On a phone the filters go behind one icon beside the search, opening the
/// same [FilterSheet] the stock pages use — see there for why.
class FilterToolbar extends StatefulWidget {
  const FilterToolbar({
    required this.search,
    required this.filters,
    this.activeCount = 0,
    this.onClear,
    super.key,
  });

  /// A [SearchField], or an [EmployeeSelector] with `searchBar: true`.
  final Widget search;

  /// Pills and toggles, in reading order.
  final List<Widget> filters;

  /// How many of [filters] are off their default — the count on the phone's
  /// filter icon.
  final int activeCount;

  /// Resets [filters] — the sheet's "Tout effacer". Offered only while
  /// [activeCount] is above zero.
  final VoidCallback? onClear;

  @override
  State<FilterToolbar> createState() => _FilterToolbarState();
}

class _FilterToolbarState extends State<FilterToolbar> {
  /// The latest [FilterToolbar.filters], for the sheet. The sheet is its own
  /// route, built once when it opens; without this its pills would keep the
  /// state they had then and never follow the taps made on them.
  late final _filters = ValueNotifier<List<Widget>>(widget.filters);

  @override
  void didUpdateWidget(FilterToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // After the frame: this runs mid-build, and the sheet is another route
    // that cannot be marked dirty from inside this one's build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _filters.value = widget.filters;
    });
  }

  @override
  void dispose() {
    _filters.dispose();
    super.dispose();
  }

  void _openSheet() {
    FilterSheet.show(
      context,
      onClear: widget.activeCount > 0 ? widget.onClear : null,
      builder: (context) => ValueListenableBuilder<List<Widget>>(
        valueListenable: _filters,
        builder: (context, filters, _) => Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: filters,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.search;
    final filters = widget.filters;

    if (context.isPhone) {
      return Row(
        children: [
          Expanded(child: search),
          if (filters.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            FilterSheetButton(
              compact: true,
              activeCount: widget.activeCount,
              onPressed: _openSheet,
            ),
          ],
        ],
      );
    }

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
        final picked = await showAppDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate,
          lastDate: lastDate,
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
