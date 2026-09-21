import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../data/view_models/view_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/widgets.dart';

/// The pieces the three movement forms share: an empty state that opens the
/// picker, one card per product line, the "add another" button, and the
/// summary beside the submit button.
///
/// The forms differ in the fields each line asks for — a supplier and a price
/// for a delivery, a count for an inventory — so the line takes those as a
/// child, and everything around them is here, drawn once.

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

    return AppCard(
      onTap: onPick,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
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

/// One product on a movement form.
///
/// The product — picture, name, what is on the shelf — along the top, with a
/// way to take it off the form; the fields for this kind of movement under
/// it. On a phone a swipe removes it too.
class MovementLineCard extends StatelessWidget {
  const MovementLineCard({
    required this.view,
    required this.onRemove,
    required this.child,
    this.trailing,
    this.invalid = false,
    super.key,
  });

  final ItemRowView view;
  final VoidCallback onRemove;

  /// The fields for this line.
  final Widget child;

  /// Beside the name, before the remove button — the line total on a
  /// delivery, the difference on a count.
  final Widget? trailing;

  /// Draws the line in the error colour: it cannot be saved as it stands.
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = view.item;

    final card = AppCard(
      accentColor: invalid ? AppColors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProductImage(imagePath: item.imagePath, size: 48, radius: 8),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n.cartInStock(
                        Formatters.quantityWithUnit(
                          item.quantity,
                          view.unitAbbreviation,
                        ),
                      ),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
              IconButton(
                onPressed: onRemove,
                tooltip: l10n.cartRemoveLine,
                icon: const Icon(LucideIcons.x),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );

    if (!context.isPhone) return card;

    return Dismissible(
      key: ValueKey('line-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: const BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: AppRadius.lgAll,
        ),
        child: const Icon(
          LucideIcons.trash2,
          color: AppColors.onErrorContainer,
        ),
      ),
      child: card,
    );
  }
}

/// The lines, then a button to add more — or the empty card when there are
/// none yet.
class MovementCartList extends StatelessWidget {
  const MovementCartList({
    required this.lines,
    required this.onPick,
    this.accent,
    super.key,
  });

  final List<Widget> lines;
  final VoidCallback onPick;
  final StockStatusColors? accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (lines.isEmpty) return CartEmptyCard(onPick: onPick, accent: accent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines) ...[
          line,
          const SizedBox(height: AppSpacing.md),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: SecondaryButton(
            label: l10n.cartAddProduct,
            icon: LucideIcons.plus,
            onPressed: onPick,
          ),
        ),
      ],
    );
  }
}

/// "3 produits · 142,50 €", beside the submit button.
class CartSummary extends StatelessWidget {
  const CartSummary({required this.count, this.total, super.key});

  final int count;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: l10n.cartLineCount(count),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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

/// The small label over a field inside a line.
class LineFieldLabel extends StatelessWidget {
  const LineFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text, style: Theme.of(context).textTheme.labelMedium),
  );
}
