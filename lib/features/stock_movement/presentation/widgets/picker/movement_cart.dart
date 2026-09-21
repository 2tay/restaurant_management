import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../data/view_models/view_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../models/models.dart';
import '../../../../../shared/widgets/widgets.dart';

/// The pieces the three movement forms share: a tinted banner saying which
/// form this is, one card listing the products as compact rows, and the
/// summary beside the submit button.
///
/// The forms differ in the controls each row asks for — a supplier, a price
/// and a quantity for a delivery, a count for an inventory — so a row takes
/// those as a child, and everything around them is drawn here, once.

/// A tinted strip across the top of a form, in its movement's colour, so the
/// person holding the tablet knows at a glance whether they are receiving,
/// removing or counting. [trailing] carries the one form-wide setting — the
/// delivery date.
class MovementBanner extends StatelessWidget {
  const MovementBanner({
    required this.colors,
    required this.icon,
    required this.message,
    this.trailing,
    super.key,
  });

  final StockStatusColors colors;
  final IconData icon;
  final String message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.lgAll,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final lead = Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.solid,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AppSizing.iconSm,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.foreground),
                ),
              ),
            ],
          );
          if (trailing == null) return lead;

          // On a phone the setting takes its own line: beside the message
          // it squeezed the sentence into a column one word wide.
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lead,
                const SizedBox(height: AppSpacing.sm),
                trailing!,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: lead),
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          );
        },
      ),
    );
  }
}

/// The products on the form: one card, a header with the count and an "add"
/// button, and a compact row per product separated by hairlines — a table
/// rather than a stack of forms.
class MovementProductsCard extends StatelessWidget {
  const MovementProductsCard({
    required this.rows,
    required this.onPick,
    this.accent,
    super.key,
  });

  final List<Widget> rows;
  final VoidCallback onPick;
  final StockStatusColors? accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (rows.isEmpty) return CartEmptyCard(onPick: onPick, accent: accent);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    l10n.cartProducts,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    '${rows.length}',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                const Spacer(),
                // Shrinks before it overflows: on a narrow phone with the
                // type turned up, the label gives way before the row does.
                Flexible(
                  flex: 3,
                  child: TextButton.icon(
                    onPressed: onPick,
                    icon: const Icon(LucideIcons.plus, size: AppSizing.iconSm),
                    label: Text(
                      l10n.cartAddProduct,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows) ...[
            const Divider(height: 1, color: AppColors.hairline),
            row,
          ],
        ],
      ),
    );
  }
}

/// What the form shows before anything is picked: one large target that
/// opens the picker, rather than an empty dropdown to decode.
class CartEmptyCard extends StatelessWidget {
  const CartEmptyCard({required this.onPick, this.accent, super.key});

  final VoidCallback onPick;

  /// The movement type's colour, so the form is visibly the one it is.
  final StockStatusColors? accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = accent ?? AppColors.onBreak;

    // Tighter on a phone, where the pinned action bar already takes the
    // bottom of the screen and a tall card put the one thing to do under it.
    final phone = context.isPhone;

    return AppCard(
      onTap: onPick,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: phone ? AppSpacing.lg : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: phone ? 48 : 64,
            height: phone ? 48 : 64,
            decoration: BoxDecoration(
              color: colors.container,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.layoutGrid,
              size: AppSizing.iconLg,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.pickerTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.cartEmptyBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// How a row reads at a glance.
enum LineState {
  /// Nothing to say.
  normal,

  /// Cannot be saved as it stands — drawn with a red edge.
  invalid,

  /// Checked and right — drawn with a green tint.
  done,
}

/// One product on a movement form, as a compact row.
///
/// Picture, name and a one-line [subtitle] (what is on the shelf, what it
/// will be after) on the left; the [controls] for this kind of movement;
/// the [trailing] figure — the line total, the difference — on the right;
/// and a way to take the product off the form.
///
/// On one line when the row is at least [inlineMinWidth] wide; otherwise the
/// controls drop to a second line under the name, so a phone gets two short
/// lines rather than a squeezed one. On a phone a swipe removes the row too.
class MovementLineCard extends StatelessWidget {
  const MovementLineCard({
    required this.view,
    required this.onRemove,
    required this.controls,
    this.subtitle,
    this.trailing,
    this.state = LineState.normal,
    this.inlineMinWidth = 640,
    super.key,
  });

  final ItemRowView view;
  final VoidCallback onRemove;
  final Widget controls;
  final Widget? subtitle;
  final Widget? trailing;
  final LineState state;
  final double inlineMinWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = view.item;

    final identity = Row(
      children: [
        ProductImage(imagePath: item.imagePath, size: 44, radius: 10),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: subtitle!,
                ),
            ],
          ),
        ),
      ],
    );

    final remove = IconButton(
      onPressed: onRemove,
      tooltip: l10n.cartRemoveLine,
      icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
      color: AppColors.textSecondary,
    );

    final trailingBox = trailing == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: trailing,
            ),
          );

    final body = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= inlineMinWidth) {
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: AppSpacing.md),
              controls,
              if (trailingBox != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailingBox,
              ],
              const SizedBox(width: AppSpacing.xs),
              remove,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: identity),
                if (trailingBox != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailingBox,
                ],
                remove,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerLeft, child: controls),
          ],
        );
      },
    );

    final tint = switch (state) {
      LineState.normal => null,
      LineState.invalid => AppColors.errorContainer.withValues(alpha: 0.35),
      LineState.done => AppColors.inStock.container.withValues(alpha: 0.55),
    };

    final row = AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.fast),
      decoration: BoxDecoration(
        color: tint,
        border: Border(
          left: BorderSide(
            width: 3,
            color: switch (state) {
              LineState.normal => Colors.transparent,
              LineState.invalid => AppColors.error,
              LineState.done => AppColors.inStock.solid,
            },
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: body,
    );

    if (!context.isPhone) return row;

    return Dismissible(
      key: ValueKey('line-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        color: AppColors.errorContainer,
        child: const Icon(
          LucideIcons.trash2,
          color: AppColors.onErrorContainer,
        ),
      ),
      child: row,
    );
  }
}

/// "5 produits · 142,50 €" beside the submit button — or, when something
/// stops the form saving, what it is, tappable to go to it.
class CartSummary extends StatelessWidget {
  const CartSummary({
    required this.count,
    this.total,
    this.detail,
    this.issue,
    this.onIssueTap,
    super.key,
  });

  final int count;
  final double? total;

  /// Replaces the product count, for a form that counts something else
  /// ("3 écarts · 2 justes").
  final String? detail;

  final String? issue;
  final VoidCallback? onIssueTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (count == 0) return const SizedBox.shrink();

    if (issue != null) {
      return TextButton.icon(
        onPressed: onIssueTap,
        style: TextButton.styleFrom(foregroundColor: AppColors.error),
        icon: const Icon(LucideIcons.circleAlert, size: AppSizing.iconSm),
        label: Text(issue!, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: detail ?? l10n.cartLineCount(count),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (total != null && total! > 0) ...[
              const TextSpan(text: '  ·  '),
              TextSpan(
                text: Formatters.price(total!),
                style: AppTypography.numeric.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Scrolls the form to [key]'s row — where a footer issue points.
void scrollToLine(GlobalKey key) {
  final context = key.currentContext;
  if (context == null) return;
  Scrollable.ensureVisible(
    context,
    duration: const Duration(milliseconds: 300),
    alignment: 0.3,
  );
}

/// "4 kg → 9 kg": what is on the shelf now and what it will be after this
/// line, the second figure in the colour of the change.
class StockAfter extends StatelessWidget {
  const StockAfter({
    required this.before,
    required this.after,
    required this.unit,
    super.key,
  });

  final double before;
  final double after;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final color = after < 0
        ? AppColors.outOfStock.foreground
        : after > before
        ? AppColors.inStock.foreground
        : after < before
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: Formatters.quantityWithUnit(before, unit)),
          const TextSpan(text: '  →  '),
          TextSpan(
            text: Formatters.quantityWithUnit(after, unit),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// The products most recently moved this way, newest first and each once —
/// the picker's "Utilisés récemment" section. [rows] come newest first, as
/// the movement history provides them.
List<String> recentItemIds(
  List<MovementRowView>? rows,
  StockMovementType type, {
  int limit = 8,
}) {
  final ids = <String>[];
  for (final row in rows ?? const <MovementRowView>[]) {
    if (row.movement.type != type || ids.contains(row.movement.itemId)) {
      continue;
    }
    ids.add(row.movement.itemId);
    if (ids.length == limit) break;
  }
  return ids;
}
