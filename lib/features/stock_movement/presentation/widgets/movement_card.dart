import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../orders/presentation/widgets/order_detail_view.dart';
import 'movement_labels.dart';
import 'movement_type_badge.dart';

/// One movement, drawn like a product card — on every screen, in a grid of
/// cards like the catalogue's:
///
/// - **Top:** the product's photo; beside it the type's icon in a round wash,
///   the product's name, the type badge right under it, then where the stock
///   came from or went (supplier and commande, or the reason).
/// - **Middle:** the quantity — signed, in the type's colour — and what it
///   was worth, each beside a round icon, split by a hairline.
/// - **Footer:** who recorded it (their avatar, or initials) and when, in
///   the left, and a green chevron: the card opens the product.
///
/// The day is the list's heading, so the footer gives the time only.
class MovementCard extends ConsumerWidget {
  const MovementCard({
    required this.view,
    required this.storeId,
    this.onTap,
    super.key,
  });

  final MovementRowView view;
  final String storeId;
  final VoidCallback? onTap;

  static const double _photoSide = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final movement = view.movement;
    final colors = movementColors(movement.type);

    final source = movementDescription(
      l10n,
      movement,
      view.supplierName ?? '—',
      orderReference: view.orderReference,
      unit: view.unitAbbreviation,
      withType: false,
    );
    final unitValue = movement.unitCost ?? movement.unitPrice;
    final value = unitValue == null
        ? '—'
        : Formatters.price(unitValue * movement.quantity.abs());

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md + 2,
        AppSpacing.md + 2,
        AppSpacing.md + 2,
        AppSpacing.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImage(
                imagePath: view.itemImagePath,
                size: _photoSide,
                radius: 14,
                placeholder: ProductImagePlaceholder.disc,
              ),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RoundIcon(
                      icon: movementTypeIcon(movement.type),
                      foreground: colors.foreground,
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.xs,
                            ),
                            child: Text(
                              Formatters.capitalized(view.itemName),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          MovementTypeBadge(type: movement.type),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            source,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // From a delivery back to what arrived.
                    if (movement.receiptId != null)
                      IconButton(
                        onPressed: () => openReceiptPanel(
                          context,
                          storeId: storeId,
                          receiptId: movement.receiptId!,
                        ),
                        tooltip: l10n.movementViewReceipt,
                        icon: const Icon(
                          LucideIcons.receiptText,
                          size: AppSizing.iconSm,
                        ),
                        color: AppColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Fact(
                    icon: LucideIcons.package,
                    caption: l10n.tableColQuantity,
                    value: Text(
                      Formatters.quantityDelta(
                        movement.quantity,
                        view.unitAbbreviation,
                      ),
                      style: AppTypography.numeric.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: movementQuantityColor(movement.type),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Fact(
                    icon: LucideIcons.euro,
                    caption: l10n.tableColValue,
                    value: Text(
                      value,
                      style: AppTypography.numeric.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(
            height: 1,
            thickness: 0.5,
            indent: AppSpacing.sm,
            endIndent: AppSpacing.sm,
            color: AppColors.border.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          _Footer(view: view, storeId: storeId),
        ],
      ),
    );
  }
}

/// Who recorded the movement and when, on the left, then the chevron.
class _Footer extends ConsumerWidget {
  const _Footer({required this.view, required this.storeId});

  final MovementRowView view;
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final movement = view.movement;

    Employee? employee;
    final id = movement.employeeId;
    if (id != null) {
      final roster = ref.watch(employeesProvider(storeId)).value;
      for (final e in roster ?? const <Employee>[]) {
        if (e.id == id) employee = e;
      }
    }

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (employee != null)
                EmployeeAvatar(employee: employee, size: 22)
              else
                _Initials(name: movement.userName),
              const SizedBox(width: AppSpacing.xs + 2),
              Flexible(
                child: Text(
                  movement.userName,
                  key: const ValueKey('movement-card-actor'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              const Icon(
                LucideIcons.clock,
                size: 14,
                color: AppColors.primary600,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                Formatters.time(movement.occurredAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          LucideIcons.chevronRight,
          size: AppSizing.iconSm,
          color: AppColors.primary600,
        ),
      ],
    );
  }
}

/// A name's initials in a small grey disc — for a movement whose recorder is
/// no longer on the roster.
class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.neutral200,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One fact of the middle row: the icon, the value, its caption under it.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.caption,
    required this.value,
  });

  final IconData icon;
  final String caption;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIcon(icon: icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              value,
              Text(
                caption,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An icon in the KPI tiles' round seat — the brand green's translucent
/// wash — or, given [foreground], the movement type's own colour.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.foreground});

  final IconData icon;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final color = foreground ?? AppColors.primary600;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: AppSizing.iconSm, color: color),
    );
  }
}
