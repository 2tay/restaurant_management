import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
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
class StockAdjustmentPage extends StatefulWidget {
  const StockAdjustmentPage({required this.storeId, super.key});

  final String storeId;

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
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

  Item? get _item => _itemId == null ? null : MockQueries.itemById(_itemId!);

  double get _difference => (_item?.quantity ?? 0) - _counted;

  /// Counted minus system: negative means stock is missing.
  double get _delta => _counted - (_item?.quantity ?? 0);

  bool get _hasChange => _item != null && _delta.abs() > 0.001;

  bool get _isLargeDrop {
    final item = _item;
    if (item == null || item.quantity <= 0 || _delta >= 0) return false;
    return (_delta.abs() / item.quantity) >= _largeDropThreshold;
  }

  void _onItemChanged(String? itemId) {
    setState(() {
      _itemId = itemId;
      // Seed the count with what the system believes, so the user adjusts from
      // there rather than typing a number from scratch.
      _counted = itemId == null
          ? 0
          : MockQueries.itemById(itemId)?.quantity ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final item = _item;
    final unit = item == null
        ? ''
        : MockQueries.unitAbbreviationOf(item.unitId);

    final items = MockQueries.itemsForStore(widget.storeId)
        .map(
          (i) => DropdownOption(
            value: i.id,
            label: i.name,
            secondaryLabel: Formatters.quantityWithUnit(
              i.quantity,
              MockQueries.unitAbbreviationOf(i.unitId),
            ),
          ),
        )
        .toList();

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
      onSubmit: _hasChange ? _submit : null,
      isDirty: _hasChange,
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: AppDropdown<String>(
              label: l10n.stockInItem,
              value: _itemId,
              options: items,
              onChanged: _onItemChanged,
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
                  _DifferenceRow(delta: _delta, unit: unit),
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

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final item = _item;
    if (item == null) return;

    if (_isLargeDrop) {
      final share = _delta.abs() / item.quantity;
      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.adjustmentLargeConfirmTitle,
        message: l10n.adjustmentLargeConfirmBody(
          Formatters.quantityWithUnit(
            _difference,
            MockQueries.unitAbbreviationOf(item.unitId),
          ),
          item.name,
          Formatters.percent(share),
        ),
        confirmLabel: l10n.actionConfirm,
      );
      if (!confirmed || !mounted) return;
    }

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
            style: AppTypography.numericLarge.copyWith(
              fontSize: 26,
              color: colors?.foreground ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
