import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// Précédent / Suivant plus an "X–Y sur Z" range, for a table that caps its
/// rows and pages the rest — see decision 7 in the Gestion Employée brief.
///
/// Shown as soon as there is a row, even on a single page, so the table always
/// says how many rows it holds. With [onPageSizeChanged], a « Lignes par
/// page » menu lets the reader pick among [pageSizeOptions].
class Paginator extends StatelessWidget {
  const Paginator({
    required this.page,
    required this.pageCount,
    required this.totalCount,
    required this.pageSize,
    required this.onChanged,
    this.onPageSizeChanged,
    this.pageSizeOptions = defaultPageSizes,
    super.key,
  });

  /// The rows-per-page choices the tables offer; the first is the default.
  static const defaultPageSizes = [10, 25, 50];

  /// Zero-based.
  final int page;
  final int pageCount;
  final int totalCount;
  final int pageSize;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final List<int> pageSizeOptions;

  @override
  Widget build(BuildContext context) {
    if (totalCount <= 0) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final first = page * pageSize + 1;
    final last = (first + pageSize - 1).clamp(first, totalCount);

    final range = Text(
      l10n.paginatorRange(first, last, totalCount),
      style: theme.textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
      ),
    );

    final onSize = onPageSizeChanged;
    final arrows = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          icon: LucideIcons.chevronLeft,
          tooltip: l10n.paginatorPrevious,
          onPressed: page > 0 ? () => onChanged(page - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          // « 1 / 10 », the current page in the brand green.
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${page + 1}',
                  style: const TextStyle(
                    color: AppColors.primary600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: ' / $pageCount'),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        _ArrowButton(
          icon: LucideIcons.chevronRight,
          tooltip: l10n.paginatorNext,
          onPressed: page < pageCount - 1 ? () => onChanged(page + 1) : null,
        ),
      ],
    );

    // The rows-per-page menu sits before the arrows, and drops under them
    // where a phone has no room for both.
    final controls = onSize == null
        ? arrows
        : Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _PageSizeMenu(
                pageSize: pageSize,
                options: pageSizeOptions,
                onSelected: onSize,
              ),
              arrows,
            ],
          );

    // A `Wrap` rather than a `Row` with a `Spacer`: the range, the menu and
    // the arrows do not fit a phone on one line. Wrapping drops the controls
    // onto their own line instead of overflowing. Full width, so
    // `spaceBetween` pins the range left and the controls right — a `Wrap`
    // alone shrinks to its content.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [range, controls],
      ),
    );
  }
}

/// The arrows' and the rows-per-page menu's side, a notch under the 40dp
/// filter controls.
const double _controlSize = 32;

/// A white square with a green chevron, no border; greyed out at either end.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: AppSizing.iconSm),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.white,
        foregroundColor: AppColors.primary600,
        disabledForegroundColor: AppColors.neutral300,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        minimumSize: const Size.square(_controlSize),
        fixedSize: const Size.square(_controlSize),
        padding: EdgeInsets.zero,
        // Flush with the table's right edge, not inset by a 48dp halo.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// « Lignes par page : 10 ▾ » on a white chip, a white menu dropped under it.
class _PageSizeMenu extends StatelessWidget {
  const _PageSizeMenu({
    required this.pageSize,
    required this.options,
    required this.onSelected,
  });

  final int pageSize;
  final List<int> options;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopupMenuButton<int>(
      key: const ValueKey('paginator-page-size'),
      tooltip: l10n.paginatorPageSize,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      offset: const Offset(0, AppSpacing.xs),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      initialValue: pageSize,
      onSelected: (size) {
        if (size != pageSize) onSelected(size);
      },
      itemBuilder: (context) => [
        for (final size in options)
          PopupMenuItem<int>(value: size, child: Text('$size')),
      ],
      child: Container(
        height: _controlSize,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        // White, like the arrows beside it.
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.paginatorPageSize,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('$pageSize', style: theme.textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.xxs),
            const Icon(
              LucideIcons.chevronDown,
              size: AppSizing.iconSm,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
