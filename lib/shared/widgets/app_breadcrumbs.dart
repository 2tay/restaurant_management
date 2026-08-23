import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// A breadcrumb trail for screens more than one level deep.
///
/// The back control answers "how do I leave"; the breadcrumbs answer "where am
/// I". Both are needed on a screen like Inventaire → Blanc de poulet →
/// Historique des prix, where back only gets you one step and the user may want
/// to jump two.
///
/// Every segment except the last navigates. The last is the current screen and
/// renders as plain text — a link to where you already are is noise.
class AppBreadcrumbs extends StatelessWidget {
  const AppBreadcrumbs({required this.crumbs, super.key});

  final List<Crumb> crumbs;

  @override
  Widget build(BuildContext context) {
    if (crumbs.length < 2) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      label: l10n.breadcrumbLabel,
      container: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              const Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: AppColors.textDisabled,
              ),
            _Segment(crumb: crumbs[i]),
          ],
        ],
      ),
    ).withTextStyle(theme);
  }
}

extension on Widget {
  /// Keeps the trail visually quiet — it is orientation, not content.
  Widget withTextStyle(ThemeData theme) => DefaultTextStyle.merge(
    style: theme.textTheme.bodySmall ?? const TextStyle(),
    child: this,
  );
}

class _Segment extends StatelessWidget {
  const _Segment({required this.crumb});

  final Crumb crumb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (crumb.isCurrent) {
      return Text(
        crumb.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        onTap: () => context.goSection(crumb.path!),
        borderRadius: AppRadius.smAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 2,
          ),
          child: Text(
            crumb.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
