import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/movement_labels.dart';
import '../../../../core/utils/employee_status.dart';
import '../widgets/picker/movement_cart.dart';
import '../widgets/picker/product_picker_sheet.dart';

/// Record stock leaving — sold, used, wasted or transferred — for several
/// products at once.
///
/// The reason is a row of large chips rather than a dropdown, and it is chosen
/// once for the whole form. This is the screen used most often mid-service,
/// the options never change, and "everything that went in the bin tonight" is
/// one reason with many products, not many forms with one.
///
/// Each row says what the shelf will hold afterwards, in red when that goes
/// below zero — the warning, before the save rather than after it.
class StockOutPage extends ConsumerStatefulWidget {
  const StockOutPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<StockOutPage> createState() => _StockOutPageState();
}

class _StockOutLine {
  _StockOutLine(this.itemId);

  final String itemId;
  final FocusNode focus = FocusNode();
  final GlobalKey key = GlobalKey();
  double quantity = 1;
}

class _StockOutPageState extends ConsumerState<StockOutPage> {
  final List<_StockOutLine> _lines = [];
  StockOutReason _reason = StockOutReason.sale;
  bool _saving = false;

  @override
  void dispose() {
    for (final line in _lines) {
      line.focus.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit =>
      !_saving && _lines.isNotEmpty && _lines.every((l) => l.quantity > 0);

  Future<void> _pick() async {
    final picked = await ProductPickerSheet.show(
      context,
      storeId: widget.storeId,
      alreadyPicked: {for (final line in _lines) line.itemId},
      featured: recentItemIds(
        ref.read(movementRowsForStoreProvider(widget.storeId)).value,
        StockMovementType.stockOut,
      ),
      featuredTitle: AppLocalizations.of(context).pickerSectionRecent,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _lines.addAll([for (final row in picked) _StockOutLine(row.item.id)]);
    });
  }

  void _remove(_StockOutLine line) {
    setState(() => _lines.remove(line));
    WidgetsBinding.instance.addPostFrameCallback((_) => line.focus.dispose());
  }

  void _focusAfter(_StockOutLine line) {
    final index = _lines.indexOf(line);
    if (index >= 0 && index + 1 < _lines.length) {
      _lines[index + 1].focus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = movementColors(StockMovementType.stockOut);

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

    final noQuantity = [
      for (final line in _lines)
        if (line.quantity <= 0) line,
    ];

    return FormScaffold(
      title: l10n.stockOutTitle,
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
      submitSecondary: CartSummary(
        count: _lines.length,
        issue: noQuantity.isEmpty
            ? null
            : l10n.cartIssueNoQuantity(noQuantity.length),
        onIssueTap: noQuantity.isEmpty
            ? null
            : () => scrollToLine(noQuantity.first.key),
      ),
      onSubmit: _canSubmit ? _submit : null,
      isDirty: _lines.isNotEmpty,
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MovementBanner(
            colors: colors,
            icon: LucideIcons.arrowUpFromLine,
            message: l10n.stockOutSubtitle,
          ),
          const SizedBox(height: AppSpacing.md),

          // The reason, once, for every row below.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final reason in StockOutReason.values)
                _ReasonChip(
                  reason: reason,
                  selected: _reason == reason,
                  colors: colors,
                  onTap: () => setState(() => _reason = reason),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          MovementProductsCard(
            accent: colors,
            onPick: _pick,
            rows: [
              for (final line in _lines)
                if (byId[line.itemId] != null)
                  _stockOutRow(line, byId[line.itemId]!),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _stockOutRow(_StockOutLine line, ItemRowView view) {
    final unit = view.unitAbbreviation;
    final stock = view.item.quantity;

    return MovementLineCard(
      key: line.key,
      view: view,
      onRemove: () => _remove(line),
      inlineMinWidth: 600,
      state: line.quantity <= 0 ? LineState.invalid : LineState.normal,
      // Recorded as entered even when it takes the item below zero — stock
      // counts drift, and refusing what actually left the building makes the
      // data worse. The red "after" figure is the whole intervention.
      subtitle: StockAfter(
        before: stock,
        after: stock - line.quantity,
        unit: unit,
      ),
      trailing: Text(
        Formatters.quantityDelta(-line.quantity, unit),
        style: AppTypography.numeric.copyWith(
          fontWeight: FontWeight.w700,
          color: quantityDeltaColor(-line.quantity),
        ),
      ),
      controls: QuantityStepper(
        compact: true,
        value: line.quantity,
        unitAbbreviation: unit,
        onChanged: (value) => setState(() => line.quantity = value),
        focusNode: line.focus,
        textInputAction: TextInputAction.next,
        onSubmitted: () => _focusAfter(line),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final movements = ref.read(movementRepositoryProvider);
    final lines = List.of(_lines);

    // Who is at the tablet. Asked here, at the save, so the person who
    // confirms is the person who saves.
    final actor = await ActorConfirmSheet.show(
      context,
      storeId: widget.storeId,
      actionLabel: l10n.stockOutSubmit,
    );
    if (actor == null || !mounted) return;
    final actorName = employeeDisplayName(actor);

    setState(() => _saving = true);
    try {
      await movements.batch(() async {
        for (final line in lines) {
          await movements.recordStockOut(
            storeId: widget.storeId,
            itemId: line.itemId,
            quantity: line.quantity,
            reason: _reason,
            userName: actorName,
            employeeId: actor.id,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    AppSnackBar.success(
      context,
      l10n.movementsRecordedBy(lines.length, actor.firstName),
    );
    context.goSection(Routes.toMovements(widget.storeId));
  }
}

/// A large, single-tap reason selector, in the stock-out colour when picked.
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.reason,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final StockOutReason reason;
  final bool selected;
  final StockStatusColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foreground = selected ? colors.foreground : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          height: AppSizing.minTapTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? colors.container : AppColors.surface,
            borderRadius: AppRadius.pillAll,
            border: Border.all(
              color: selected ? colors.solid : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? LucideIcons.circleCheck : reasonIcon(reason),
                size: AppSizing.iconSm,
                color: selected ? colors.solid : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                reasonLabel(l10n, reason),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
