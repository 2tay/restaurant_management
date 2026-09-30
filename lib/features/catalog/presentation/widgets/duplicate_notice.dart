import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/name_matching.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// Rows sharing a name, as the name rule compares them.
///
/// Two tablets working offline can each create "Boissons" (SYNC_PLAN.md,
/// Phase 7). In each group, [keep] is the row to merge the others into: the
/// one holding the most articles, the first by id on a tie, so every device
/// picks the same.
class DuplicateGroup<T> {
  const DuplicateGroup({required this.keep, required this.others});

  final T keep;
  final List<T> others;
}

List<DuplicateGroup<T>> duplicateGroups<T>(
  List<T> rows, {
  required String Function(T row) name,
  required String Function(T row) id,
  required int Function(T row) itemCount,
}) {
  final byName = <String, List<T>>{};
  for (final row in rows) {
    (byName[normaliseName(name(row))] ??= []).add(row);
  }
  return [
    for (final group in byName.values)
      if (group.length > 1)
        () {
          final sorted = [...group]
            ..sort((a, b) {
              final byCount = itemCount(b).compareTo(itemCount(a));
              return byCount != 0 ? byCount : id(a).compareTo(id(b));
            });
          return DuplicateGroup(keep: sorted.first, others: sorted.sublist(1));
        }(),
  ];
}

/// A card above the list for each duplicated name, with a merge button.
class DuplicateNotice extends StatelessWidget {
  const DuplicateNotice({required this.name, required this.onMerge, super.key});

  final String name;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: AdaptiveRow(
          cells: [
            AdaptiveCell(
              flex: 1,
              child: Row(
                children: [
                  Icon(
                    LucideIcons.copy,
                    size: AppSizing.iconMd,
                    color: AppColors.lowStock.foreground,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.catalogDuplicate(name),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            AdaptiveCell(
              child: SecondaryButton(
                label: l10n.catalogMerge,
                icon: LucideIcons.merge,
                onPressed: onMerge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
