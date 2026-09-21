import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../data/view_models/view_models.dart';
import '../../../../../l10n/app_localizations.dart';

/// The supplier on a delivery line, as a chip: who, and at what price.
///
/// A chip rather than a dropdown because the choice needs more than a name —
/// which one is cheapest, which one is usual — and a menu has no room to say
/// so. Tapping opens [SupplierChoiceSheet]. With no supplier yet it reads as
/// a call to action in the error colour, since the line cannot be saved.
class SupplierChip extends StatelessWidget {
  const SupplierChip({
    required this.name,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  /// Null when no supplier is chosen.
  final String? name;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final missing = name == null;
    final foreground = missing ? AppColors.error : AppColors.textPrimary;

    return Material(
      color: missing ? AppColors.errorContainer : AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.pillAll,
        side: BorderSide(color: missing ? AppColors.error : AppColors.border),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizing.minTapTarget,
            maxWidth: 220,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.truck,
                  size: AppSizing.iconSm,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    name ?? l10n.lineChooseSupplier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: foreground),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  LucideIcons.chevronDown,
                  size: AppSizing.iconSm,
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the supplier sheet returns.
typedef SupplierChoice = ({String supplierId, bool applyToAll});

/// Choose the supplier for one product: each one that offers it, with its
/// price, the cheapest tagged "Meilleur prix" and the usual one "Habituel".
abstract final class SupplierChoiceSheet {
  static Future<SupplierChoice?> show(
    BuildContext context, {
    required String itemName,
    required String unit,
    required List<SupplierPriceView> offers,
    required String? selectedId,
    bool canApplyToAll = false,
  }) {
    final body = _SupplierChoice(
      itemName: itemName,
      unit: unit,
      offers: offers,
      selectedId: selectedId,
      canApplyToAll: canApplyToAll,
    );

    if (context.isPhone) {
      return showModalBottomSheet<SupplierChoice>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        builder: (_) => body,
      );
    }
    return showDialog<SupplierChoice>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: body,
        ),
      ),
    );
  }
}

class _SupplierChoice extends StatefulWidget {
  const _SupplierChoice({
    required this.itemName,
    required this.unit,
    required this.offers,
    required this.selectedId,
    required this.canApplyToAll,
  });

  final String itemName;
  final String unit;
  final List<SupplierPriceView> offers;
  final String? selectedId;
  final bool canApplyToAll;

  @override
  State<_SupplierChoice> createState() => _SupplierChoiceState();
}

class _SupplierChoiceState extends State<_SupplierChoice> {
  bool _applyToAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    double? cheapest;
    for (final offer in widget.offers) {
      final price = offer.price.pricePerUnit;
      if (cheapest == null || price < cheapest) cheapest = price;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.supplierSheetTitle(widget.itemName),
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            children: [
              for (final offer in widget.offers)
                _OfferTile(
                  offer: offer,
                  unit: widget.unit,
                  selected: offer.price.supplierId == widget.selectedId,
                  isCheapest:
                      widget.offers.length > 1 &&
                      offer.price.pricePerUnit == cheapest,
                  onTap: () => Navigator.of(context).pop((
                    supplierId: offer.price.supplierId,
                    applyToAll: _applyToAll,
                  )),
                ),
            ],
          ),
        ),
        if (widget.canApplyToAll)
          CheckboxListTile(
            value: _applyToAll,
            onChanged: (value) => setState(() => _applyToAll = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              l10n.supplierApplyAll,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.offer,
    required this.unit,
    required this.selected,
    required this.isCheapest,
    required this.onTap,
  });

  final SupplierPriceView offer;
  final String unit;
  final bool selected;
  final bool isCheapest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget tag(String label, StockStatusColors colors) => Container(
      margin: const EdgeInsets.only(right: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.primaryContainer : Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: AppSizing.iconMd,
                  color: selected
                      ? AppColors.primary600
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.supplierName,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (isCheapest || offer.price.isDefault) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isCheapest)
                              tag(l10n.supplierBestPrice, AppColors.inStock),
                            if (offer.price.isDefault)
                              tag(l10n.supplierUsual, AppColors.info),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${Formatters.price(offer.price.pricePerUnit)} / $unit',
                  style: AppTypography.numeric,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The unit price on a delivery line: a small field with the currency and
/// unit beside the number, typed with a comma or a point.
class LinePriceField extends StatelessWidget {
  const LinePriceField({
    required this.controller,
    required this.unit,
    required this.onChanged,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String unit;
  final VoidCallback onChanged;
  final bool enabled;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: 132,
      child: TextField(
        controller: controller,
        enabled: enabled,
        textAlign: TextAlign.right,
        style: AppTypography.numeric,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        textInputAction: textInputAction,
        onChanged: (_) => onChanged(),
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        decoration: InputDecoration(
          isDense: true,
          labelText: l10n.linePriceLabel(unit.isEmpty ? '—' : unit),
          suffixText: '€',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}
