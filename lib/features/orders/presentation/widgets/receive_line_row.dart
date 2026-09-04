import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/widgets.dart';

/// One line of a delivery as it is being checked in.
///
/// Mutable and controller-owning for the same reason as the order line draft:
/// the price and the note are typed, and a controller per line is what keeps
/// them attached to the right line when one is added or removed.
///
/// The page that holds these disposes them.
class ReceiveLineDraft {
  ReceiveLineDraft({
    required this.itemId,
    required this.quantityOrdered,
    required this.orderedUnitPrice,
    this.wasUnordered = false,
  }) : // Pre-filled with the outstanding quantity, because that is what
       // usually turns up. Making staff retype the common case is how a
       // receiving screen ends up unused.
       quantityReceived = quantityOrdered,
       priceController = TextEditingController(
         text: Formatters.quantity(orderedUnitPrice),
       ),
       noteController = TextEditingController();

  final String itemId;

  /// What is still outstanding on this line, not the original order quantity.
  /// Zero for a line that was not ordered at all.
  final double quantityOrdered;

  final double orderedUnitPrice;
  final bool wasUnordered;

  double quantityReceived;

  /// What to do about a shortfall.
  ///
  /// Defaults to closing it. Most restaurant purchasing is fresh goods, where
  /// what did not arrive is gone rather than delayed — and defaulting the other
  /// way produces orders that sit in `partial` forever, which permanently
  /// inflates the "on order" quantity and makes the double-order indicator
  /// lie. One tap changes it in the minority case.
  bool closeShort = true;

  final TextEditingController priceController;
  final TextEditingController noteController;

  double get actualUnitPrice =>
      double.tryParse(priceController.text.replaceAll(',', '.').trim()) ??
      orderedUnitPrice;

  double get lineValue => quantityReceived * actualUnitPrice;

  double get missing {
    final gap = quantityOrdered - quantityReceived;
    return gap > 0 ? gap : 0;
  }

  double get surplus {
    final gap = quantityReceived - quantityOrdered;
    return gap > 0 ? gap : 0;
  }

  ReceiptLineOutcome get outcome => outcomeOf(
    ordered: quantityOrdered,
    received: quantityReceived,
    wasUnordered: wasUnordered,
  );

  /// True when the price on the delivery note differs from the ordered price.
  bool get priceWasEdited => (actualUnitPrice - orderedUnitPrice).abs() > 0.001;

  ReceiptDraftLine toDraftLine() => ReceiptDraftLine(
    itemId: itemId,
    quantityOrdered: quantityOrdered,
    quantityReceived: quantityReceived,
    orderedUnitPrice: orderedUnitPrice,
    actualUnitPrice: actualUnitPrice,
    closeShort: closeShort && missing > 0,
    wasUnordered: wasUnordered,
    note: noteController.text.trim().isEmpty
        ? null
        : noteController.text.trim(),
  );

  void dispose() {
    priceController.dispose();
    noteController.dispose();
  }
}

/// The editor for one [ReceiveLineDraft].
class ReceiveLineRow extends StatelessWidget {
  const ReceiveLineRow({
    required this.draft,
    required this.itemName,
    required this.unitAbbreviation,
    required this.onChanged,
    this.onRemove,
    super.key,
  });

  final ReceiveLineDraft draft;

  /// The article's name, or a dash when it has been deleted since the commande
  /// was sent — the line is still received, because the delivery happened.
  final String itemName;

  final String unitAbbreviation;

  final VoidCallback onChanged;

  /// Only unordered lines can be taken back off the receipt — an ordered line
  /// belongs to the document and is recorded whether or not it arrived.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final unit = unitAbbreviation;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(itemName, style: theme.textTheme.titleSmall),
                    if (draft.wasUnordered)
                      _Flag(
                        label: l10n.receiveUnorderedBadge,
                        icon: LucideIcons.circlePlus,
                        colors: AppColors.lowStock,
                      ),
                    if (draft.surplus > 0)
                      _Flag(
                        label: l10n.receiveOverBadge(
                          Formatters.quantityWithUnit(draft.surplus, unit),
                        ),
                        icon: LucideIcons.trendingUp,
                        colors: AppColors.lowStock,
                      ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: l10n.orderRemoveLine,
                  icon: const Icon(LucideIcons.trash2),
                  color: AppColors.textSecondary,
                  constraints: const BoxConstraints(
                    minWidth: AppSizing.minTapTarget,
                    minHeight: AppSizing.minTapTarget,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.lg,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              // Ordered is stated, not editable. The order is the document;
              // this screen records what arrived against it.
              _ReadOnlyFigure(
                label: l10n.receiveColumnOrdered,
                value: draft.wasUnordered
                    ? '—'
                    : Formatters.quantityWithUnit(draft.quantityOrdered, unit),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.receiveColumnReceived,
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuantityStepper(
                    value: draft.quantityReceived,
                    unitAbbreviation: unit,
                    onChanged: (value) {
                      draft.quantityReceived = value;
                      onChanged();
                    },
                  ),
                ],
              ),
              SizedBox(
                width: 180,
                child: AppTextField.currency(
                  label: l10n.receiveColumnPrice(unit.isEmpty ? '—' : unit),
                  controller: draft.priceController,
                  helperText: draft.priceWasEdited
                      ? l10n.receiveOrderedPrice(
                          Formatters.price(draft.orderedUnitPrice),
                        )
                      : null,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),

          // The short-delivery control. Inline and non-blocking on purpose: a
          // dialog per short line would make checking in a van of goods a
          // sequence of interruptions.
          if (draft.missing > 0 && !draft.wasUnordered) ...[
            const SizedBox(height: AppSpacing.lg),
            _ShortDeliveryChoice(
              missing: Formatters.quantityWithUnit(draft.missing, unit),
              closeShort: draft.closeShort,
              onChanged: (value) {
                draft.closeShort = value;
                onChanged();
              },
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l10n.receiveLineNote,
            controller: draft.noteController,
            hint: l10n.receiveLineNoteHint,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyFigure extends StatelessWidget {
  const _ReadOnlyFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppSizing.inputHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTypography.numericMedium),
          ),
        ),
      ],
    );
  }
}

/// Close the shortfall, or keep the line open for a later delivery.
class _ShortDeliveryChoice extends StatelessWidget {
  const _ShortDeliveryChoice({
    required this.missing,
    required this.closeShort,
    required this.onChanged,
  });

  final String missing;
  final bool closeShort;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lowStock.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.packageX,
                size: AppSizing.iconMd,
                color: AppColors.lowStock.foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.receiveShortTitle(missing),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.lowStock.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Choice(
                label: l10n.receiveShortClose,
                selected: closeShort,
                onTap: () => onChanged(true),
              ),
              _Choice(
                label: l10n.receiveShortKeepOpen,
                selected: !closeShort,
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          height: AppSizing.minTapTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: selected
                  ? AppColors.lowStock.foreground
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.circle,
                size: AppSizing.iconSm,
                color: AppColors.lowStock.foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.lowStock.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill flagging something about a line — unordered, over-delivered.
class _Flag extends StatelessWidget {
  const _Flag({required this.label, required this.icon, required this.colors});

  final String label;
  final IconData icon;
  final StockStatusColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizing.iconSm, color: colors.foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.foreground),
          ),
        ],
      ),
    );
  }
}
