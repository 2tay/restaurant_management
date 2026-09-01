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

/// Correct the recorded stock after a physical count.
///
/// The system quantity is shown but not editable — the user counts, the app
/// works out the difference. Asking them to compute the delta themselves is how
/// adjustments get entered backwards.
///
/// A large downward correction confirms first, per the brief, and the dialog
/// states the size of the drop. Someone who typed 8 when they meant 80 should
/// be stopped by reading the number back to them.
class StockAdjustmentPage extends ConsumerStatefulWidget {
  const StockAdjustmentPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<StockAdjustmentPage> createState() =>
      _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends ConsumerState<StockAdjustmentPage> {
  final _noteController = TextEditingController();

  String? _itemId;
  double _counted = 0;

  /// Below this share, a downward correction is routine. At or beyond it, the
  /// user is asked to confirm.
  static const double _largeDropThreshold = 0.15;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// The picked article, resolved from the list the dropdown already shows.
  ///
  /// Read fresh on every build rather than cached, so a delivery landing while
  /// somebody is counting moves the "système" figure under their eyes instead
  /// of leaving them comparing against a number that has stopped being true.
  ItemRowView? _selected(List<ItemRowView> rows) {
    for (final row in rows) {
      if (row.item.id == _itemId) return row;
    }
    return null;
  }

  double _difference(Item? item) => (item?.quantity ?? 0) - _counted;

  /// Counted minus system: negative means stock is missing.
  double _delta(Item? item) => _counted - (item?.quantity ?? 0);

  bool _hasChange(Item? item) => item != null && _delta(item).abs() > 0.001;

  bool _isLargeDrop(Item? item) {
    if (item == null || item.quantity <= 0 || _delta(item) >= 0) return false;
    return (_delta(item).abs() / item.quantity) >= _largeDropThreshold;
  }

  void _onItemChanged(String? itemId, List<ItemRowView> rows) {
    setState(() {
      _itemId = itemId;
      // Seed the count with what the system believes, so the user adjusts from
      // there rather than typing a number from scratch.
      _counted = 0;
      for (final row in rows) {
        if (row.item.id == itemId) _counted = row.item.quantity;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Alphabetical, not worst-first: this is a picker.
    final rows =
        ref.watch(itemRowsProvider((
              storeId: widget.storeId,
              filter: ItemFilter.none,
            ))).value ??
        const <ItemRowView>[];

    final row = _selected(rows);
    final item = row?.item;
    final unit = row?.unitAbbreviation ?? '';

    final items = [
      for (final row in rows)
        DropdownOption(
          value: row.item.id,
          label: row.item.name,
          secondaryLabel: Formatters.quantityWithUnit(
            row.item.quantity,
            row.unitAbbreviation,
          ),
        ),
    ];

    return FormScaffold(
      title: l10n.adjustmentTitle,
      subtitle: l10n.adjustmentSubtitle,
      back: BackDestination(
        label: l10n.movementsTitle,
        path: Routes.toMovements(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.movementsTitle, Routes.toMovements(widget.storeId)),
        Crumb(l10n.adjustmentTitle),
      ],
      submitLabel: l10n.adjustmentSubmit,
      submitIcon: LucideIcons.clipboardCheck,
      onSubmit: _hasChange(item) ? () => _submit(row) : null,
      isDirty: _hasChange(item),
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: AppDropdown<String>(
              label: l10n.stockInItem,
              value: _itemId,
              options: items,
              onChanged: (value) => _onItemChanged(value, rows),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (item != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.adjustmentSystemQuantity,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        Formatters.quantityWithUnit(item.quantity, unit),
                        style: AppTypography.numeric,
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.xl),
                  Text(
                    l10n.adjustmentCountedQuantity,
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuantityStepper(
                    value: _counted,
                    unitAbbreviation: unit,
                    onChanged: (value) => setState(() => _counted = value),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _DifferenceRow(delta: _delta(item), unit: unit),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              child: AppTextField(
                label: l10n.adjustmentNote,
                controller: _noteController,
                hint: l10n.adjustmentNoteHint,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }

  Future<void> _submit(ItemRowView? row) async {
    final l10n = AppLocalizations.of(context);
    if (row == null) return;

    // Re-read rather than trusting the row on screen. A correction says what
    // the system believed at the moment it was made, and between the last
    // rebuild and this tap a delivery may have changed that — recording a stale
    // "système" figure would put a wrong number into the audit trail for ever.
    final item = await ref.read(itemRepositoryProvider).item(row.item.id);
    if (!mounted || item == null) return;

    if (_isLargeDrop(item)) {
      final share = _delta(item).abs() / item.quantity;
      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.adjustmentLargeConfirmTitle,
        message: l10n.adjustmentLargeConfirmBody(
          Formatters.quantityWithUnit(
            _difference(item),
            row.unitAbbreviation,
          ),
          item.name,
          Formatters.percent(share),
        ),
        confirmLabel: l10n.actionConfirm,
      );
      if (!confirmed || !mounted) return;
    }

    // Both figures are recorded, not just the difference: "we thought 40, we
    // counted 31" is the useful record and "−9" on its own is not.
    await ref
        .read(movementRepositoryProvider)
        .recordAdjustment(
          storeId: widget.storeId,
          itemId: item.id,
          systemQuantity: item.quantity,
          countedQuantity: _counted,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (!mounted) return;
    AppSnackBar.success(context, l10n.adjustmentRecorded);
    context.goSection(Routes.toMovements(widget.storeId));
  }
}

/// The computed gap between counted and system.
class _DifferenceRow extends StatelessWidget {
  const _DifferenceRow({required this.delta, required this.unit});

  final double delta;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final isNeutral = delta.abs() < 0.001;
    final colors = isNeutral
        ? null
        : delta < 0
        ? AppColors.lowStock
        : AppColors.inStock;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors?.container ?? AppColors.surfaceVariant,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.adjustmentDifference,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors?.foreground ?? AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            isNeutral ? '—' : Formatters.quantityDelta(delta, unit),
            style: AppTypography.numericHero.copyWith(
              color: colors?.foreground ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
