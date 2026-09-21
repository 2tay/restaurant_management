import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/movement_labels.dart';
import '../widgets/picker/movement_cart.dart';
import '../widgets/picker/product_picker_sheet.dart';

/// Record stock leaving — sold, used, wasted or transferred — for several
/// products at once.
///
/// The reason is a row of large chips rather than a dropdown, and it is chosen
/// once for the whole form. This is the screen used most often mid-service,
/// the options never change, and "everything that went in the bin tonight" is
/// one reason with many products, not many forms with one.
class StockOutPage extends ConsumerStatefulWidget {
  const StockOutPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<StockOutPage> createState() => _StockOutPageState();
}

class _StockOutLine {
  _StockOutLine(this.itemId);

  final String itemId;
  double quantity = 1;
}

class _StockOutPageState extends ConsumerState<StockOutPage> {
  final List<_StockOutLine> _lines = [];
  StockOutReason _reason = StockOutReason.sale;
  bool _saving = false;

  bool get _canSubmit =>
      !_saving && _lines.isNotEmpty && _lines.every((l) => l.quantity > 0);

  Future<void> _pick() async {
    final picked = await ProductPickerSheet.show(
      context,
      storeId: widget.storeId,
      alreadyPicked: {for (final line in _lines) line.itemId},
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _lines.addAll([for (final row in picked) _StockOutLine(row.item.id)]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final rows =
        ref
            .watch(
              itemRowsProvider((
                storeId: widget.storeId,
                filter: ItemFilter.none,
              )),
            )
            .value ??
        const <ItemRowView>[];
    final byId = {for (final row in rows) row.item.id: row};

    return FormScaffold(
      title: l10n.stockOutTitle,
      subtitle: l10n.stockOutSubtitle,
      back: BackDestination(
        label: l10n.movementsTitle,
        path: Routes.toMovements(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.movementsTitle, Routes.toMovements(widget.storeId)),
        Crumb(l10n.stockOutTitle),
      ],
      submitLabel: l10n.stockOutSubmit,
      submitIcon: LucideIcons.arrowUpFromLine,
      submitSecondary: CartSummary(count: _lines.length),
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _lines.isNotEmpty,
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.stockOutReason, style: theme.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final reason in StockOutReason.values)
                      _ReasonChip(
                        reason: reason,
                        selected: _reason == reason,
                        onTap: () => setState(() => _reason = reason),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          MovementCartList(
            accent: movementColors(StockMovementType.stockOut),
            onPick: _pick,
            lines: [
              for (final line in _lines)
                if (byId[line.itemId] != null)
                  MovementLineCard(
                    key: ObjectKey(line),
                    view: byId[line.itemId]!,
                    onRemove: () => setState(() => _lines.remove(line)),
                    child: _StockOutFields(
                      line: line,
                      view: byId[line.itemId]!,
                      onChanged: (value) =>
                          setState(() => line.quantity = value),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final movements = ref.read(movementRepositoryProvider);
    final lines = List.of(_lines);

    setState(() => _saving = true);
    try {
      // Recorded as entered even when it takes an item below zero. The
      // warning on the line is the whole intervention: refusing would make
      // staff either lie to the app or stop using it, and negative stock is
      // itself a useful signal that a delivery went unrecorded.
      await movements.batch(() async {
        for (final line in lines) {
          await movements.recordStockOut(
            storeId: widget.storeId,
            itemId: line.itemId,
            quantity: line.quantity,
            reason: _reason,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    AppSnackBar.success(
      context,
      lines.length == 1
          ? l10n.stockOutRecorded
          : l10n.movementsRecorded(lines.length),
    );
    context.goSection(Routes.toMovements(widget.storeId));
  }
}

/// The quantity leaving, and a warning when it is more than is on the shelf.
class _StockOutFields extends StatelessWidget {
  const _StockOutFields({
    required this.line,
    required this.view,
    required this.onChanged,
  });

  final _StockOutLine line;
  final ItemRowView view;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exceeds = line.quantity > view.item.quantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LineFieldLabel(l10n.stockOutQuantity),
        QuantityStepper(
          value: line.quantity,
          unitAbbreviation: view.unitAbbreviation,
          onChanged: onChanged,
        ),
        if (exceeds) ...[
          const SizedBox(height: AppSpacing.md),
          // A warning rather than a hard block: stock counts drift, and
          // refusing to record something that actually left the building
          // would make the data worse, not better.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lowStock.container,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  size: AppSizing.iconMd,
                  color: AppColors.lowStock.foreground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.stockOutExceedsStock,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.lowStock.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A large, single-tap reason selector.
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final StockOutReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        height: AppSizing.buttonHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? AppColors.primary600 : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reasonIcon(reason),
              size: AppSizing.iconMd,
              color: selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              reasonLabel(l10n, reason),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? AppColors.onPrimaryContainer
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
