import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'filter_pill.dart';

/// A [FilterPill] wearing a dropdown — the pairing every filterable list in
/// the app uses ([FilterPill] as the [PopupMenuButton]'s `child`, not its
/// menu). [entries] maps each value to its menu label; [selectedLabel] is the
/// text shown on the pill when a non-default value is picked (null → the pill
/// shows only [label]).
class FilterMenu<T> extends StatelessWidget {
  const FilterMenu({
    required this.label,
    required this.selectedLabel,
    required this.entries,
    required this.onSelected,
    super.key,
  });

  final String label;
  final String? selectedLabel;
  final Map<T, String> entries;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      // White, and dropped straight under the pill rather than laid over it,
      // like a select's list.
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      offset: const Offset(0, AppSpacing.xs),
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
