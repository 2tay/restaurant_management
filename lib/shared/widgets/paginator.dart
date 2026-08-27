import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Précédent / Suivant plus an "X–Y sur Z" range, for a table that caps its
/// rows and pages the rest — see decision 7 in the Gestion Employée brief.
///
/// Renders nothing when everything fits on one page, so a small list never
/// grows a redundant control.
class Paginator extends StatelessWidget {
  const Paginator({
    required this.page,
    required this.pageCount,
    required this.totalCount,
    required this.pageSize,
    required this.onChanged,
    super.key,
  });

  /// Zero-based.
  final int page;
  final int pageCount;
  final int totalCount;
  final int pageSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final first = page * pageSize + 1;
    final last = (first + pageSize - 1).clamp(first, totalCount);

    return Row(
      children: [
        Text(
          l10n.paginatorRange(first, last, totalCount),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: page > 0 ? () => onChanged(page - 1) : null,
          icon: const Icon(LucideIcons.chevronLeft),
          tooltip: l10n.paginatorPrevious,
        ),
        Text(
          l10n.paginatorPage(page + 1, pageCount),
          style: theme.textTheme.bodyMedium,
        ),
        IconButton(
          onPressed: page < pageCount - 1 ? () => onChanged(page + 1) : null,
          icon: const Icon(LucideIcons.chevronRight),
          tooltip: l10n.paginatorNext,
        ),
      ],
    );
  }
}
