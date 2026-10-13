import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../orders/presentation/widgets/order_detail_view.dart';
import 'movement_labels.dart';
import 'movement_type_badge.dart' show movementQuantityColor;

/// One movement. On a phone it is drawn like a product card:
///
/// - **Top:** the product's photo; beside it the product's name, the type
///   badge right under it (shaped like the employees' role badge), then where
///   the stock came from or went (supplier and commande, or the reason).
/// - **Middle:** the quantity — signed, in the type's colour — and what it
///   was worth, each beside a round icon, split by a hairline.
/// - **Footer:** who recorded it (their avatar, or initials) and when, in
///   the left, and a green chevron: the card opens the product.
///
/// The day is the list's heading, so the footer gives the time only.
///
/// On a tablet or a desktop it is one wide card per line instead — see
/// [_WideMovementCard].
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
    // A tablet or a desktop gets one wide card per line.
    if (!context.isPhone) {
      return _WideMovementCard(view: view, storeId: storeId, onTap: onTap);
    }

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
                          // The role badge's shape ([EmployeeRoleBadge]).
                          LabelChip(
                            key: const ValueKey('movement-card-type'),
                            label: movementTypeLabel(l10n, movement.type),
                            icon: movementTypeIcon(movement.type),
                            background: colors.container,
                            foreground: colors.foreground,
                            borderRadius: AppRadius.smAll,
                          ),
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

/// A movement on a tablet or a desktop: one wide card per line, in blocks
/// split by hairlines —
///
/// 1. the product: photo, name, the type badge, the source;
/// 2. Quantité, signed, in the type's colour;
/// 3. Valeur;
/// 4. Par: who recorded it, and the time under it;
/// 5. the receipt link when there is one, and the green chevron.
///
/// A thin stripe down the left edge carries the type's colour, so entries,
/// exits and adjustments stand apart down the list. On a narrow pane the
/// value goes first, then « Par » joins the source line — nothing overflows,
/// nothing scrolls sideways.
class _WideMovementCard extends ConsumerWidget {
  const _WideMovementCard({
    required this.view,
    required this.storeId,
    this.onTap,
  });

  final MovementRowView view;
  final String storeId;
  final VoidCallback? onTap;

  static const double _photoSide = 56;
  static const double _stripe = 3;

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

    Widget rule() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: AppColors.border.withValues(alpha: 0.6),
      ),
    );

    // The width is read outside the IntrinsicHeight: a LayoutBuilder cannot
    // answer the intrinsic-size questions IntrinsicHeight asks.
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - _stripe - AppSpacing.md * 2;
          final showBy = width >= 640;
          final showValue = width >= 760;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const ValueKey('movement-card-stripe'),
                  width: _stripe,
                  child: ColoredBox(color: colors.solid),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        // 1. The product.
                        Expanded(
                          child: Row(
                            children: [
                              ProductImage(
                                imagePath: view.itemImagePath,
                                size: _photoSide,
                                radius: 12,
                                placeholder: ProductImagePlaceholder.disc,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      Formatters.capitalized(view.itemName),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    LabelChip(
                                      key: const ValueKey('movement-card-type'),
                                      label: movementTypeLabel(
                                        l10n,
                                        movement.type,
                                      ),
                                      icon: movementTypeIcon(movement.type),
                                      background: colors.container,
                                      foreground: colors.foreground,
                                      borderRadius: AppRadius.smAll,
                                      dense: true,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      showBy
                                          ? source
                                          : '$source · ${movement.userName} · '
                                                '${Formatters.time(movement.occurredAt)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
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
                          ),
                        ),
                        rule(),
                        // 2. Quantité.
                        SizedBox(
                          width: 140,
                          child: _Fact(
                            icon: LucideIcons.package,
                            caption: l10n.tableColQuantity,
                            value: Text(
                              Formatters.quantityDelta(
                                movement.quantity,
                                view.unitAbbreviation,
                              ),
                              style: AppTypography.numeric.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: movementQuantityColor(movement.type),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // 3. Valeur.
                        if (showValue) ...[
                          rule(),
                          SizedBox(
                            width: 130,
                            child: _Fact(
                              icon: LucideIcons.euro,
                              caption: l10n.tableColValue,
                              value: Text(
                                value,
                                style: AppTypography.numeric.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        // 4. Par.
                        if (showBy) ...[
                          rule(),
                          SizedBox(
                            width: 170,
                            child: _Actor(view: view, storeId: storeId),
                          ),
                        ],
                        // 5. The receipt, and the way in.
                        const SizedBox(width: AppSpacing.sm),
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
                          ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: AppSizing.iconSm,
                          color: AppColors.primary600,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// « Par » on the wide card: the recorder's avatar (or initials) and name,
/// the time under them.
class _Actor extends ConsumerWidget {
  const _Actor({required this.view, required this.storeId});

  final MovementRowView view;
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final movement = view.movement;
    final employee = _employeeOf(ref, storeId, movement.employeeId);

    return Row(
      children: [
        if (employee != null)
          EmployeeAvatar(employee: employee, size: 32)
        else
          _Initials(name: movement.userName, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
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
              Text(
                Formatters.time(movement.occurredAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The employee who recorded a movement, when they are on the roster.
Employee? _employeeOf(WidgetRef ref, String storeId, String? id) {
  if (id == null) return null;
  final roster = ref.watch(employeesProvider(storeId)).value;
  for (final e in roster ?? const <Employee>[]) {
    if (e.id == id) return e;
  }
  return null;
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

    final employee = _employeeOf(ref, storeId, movement.employeeId);

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
  const _Initials({required this.name, this.size = 22});

  final String name;
  final double size;

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
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.neutral200,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: size * 0.4,
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
/// wash.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary600;
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
