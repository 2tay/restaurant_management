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

/// Correct the recorded stock after a physical count — a whole shelf at once.
///
/// The system quantity is shown but not editable — the user counts, the app
/// works out the difference. Asking them to compute the delta themselves is how
/// adjustments get entered backwards.
///
/// A product that counts right is one tap — "Juste" — and its row turns
/// green, so a shelf of twenty with two gaps is twenty taps and two numbers.
/// Only the gaps are saved: a count that matched is a check, not a
/// correction.
///
/// A large downward correction confirms first, per the brief, and the dialog
/// states the size of the drop. Someone who typed 8 when they meant 80 should
/// be stopped by reading the number back to them. Each row also warns on its
/// own, before the save, so the one that needs a second look is findable.
class StockAdjustmentPage extends ConsumerStatefulWidget {
  const StockAdjustmentPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<StockAdjustmentPage> createState() =>
      _StockAdjustmentPageState();
}

class _CountLine {
  _CountLine(this.itemId, this.counted);

  final String itemId;
  final FocusNode focus = FocusNode();
  double counted;

  /// Marked "Juste": counted and found to match. Cleared by any change to the
  /// count, so a green row always means what it says.
  bool confirmed = false;
}

/// Below this share, a downward correction is routine. At or beyond it, the
/// user is asked to confirm.
const double _largeDropThreshold = 0.15;

/// Counted minus system: negative means stock is missing.
double _delta(double system, double counted) => counted - system;

bool _hasChange(double system, double counted) =>
    _delta(system, counted).abs() > 0.001;

bool _isLargeDrop(double system, double counted) {
  final delta = _delta(system, counted);
  if (system <= 0 || delta >= 0) return false;
  return delta.abs() / system >= _largeDropThreshold;
}

class _StockAdjustmentPageState extends ConsumerState<StockAdjustmentPage> {
  final _noteController = TextEditingController();
  final List<_CountLine> _lines = [];
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    for (final line in _lines) {
      line.focus.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ProductPickerSheet.show(
      context,
      storeId: widget.storeId,
      alreadyPicked: {for (final line in _lines) line.itemId},
      featured: recentItemIds(
        ref.read(movementRowsForStoreProvider(widget.storeId)).value,
        StockMovementType.adjustment,
      ),
      featuredTitle: AppLocalizations.of(context).pickerSectionRecent,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      // Seed each count with what the system believes, so the user adjusts
      // from there rather than typing a number from scratch.
      _lines.addAll([
        for (final row in picked) _CountLine(row.item.id, row.item.quantity),
      ]);
    });
  }

  void _remove(_CountLine line) {
    setState(() => _lines.remove(line));
    WidgetsBinding.instance.addPostFrameCallback((_) => line.focus.dispose());
  }

  void _focusAfter(_CountLine line) {
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
    final colors = movementColors(StockMovementType.adjustment);

    // Read fresh on every build rather than cached, so a delivery landing
    // while somebody is counting moves the "prévu" figure under their eyes
    // instead of leaving them comparing against a number that has stopped
    // being true.
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

    var gaps = 0;
    var correct = 0;
    for (final line in _lines) {
      final row = byId[line.itemId];
      if (row == null) continue;
      if (_hasChange(row.item.quantity, line.counted)) {
        gaps++;
      } else if (line.confirmed) {
        correct++;
      }
    }

    return FormScaffold(
      title: l10n.adjustmentTitle,
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
      submitSecondary: CartSummary(
        count: _lines.length,
        detail: [
          l10n.adjustmentGapCount(gaps),
          if (correct > 0) l10n.adjustmentCorrectCount(correct),
        ].join('  ·  '),
      ),
      onSubmit: !_saving && gaps > 0 ? () => _submit(byId) : null,
      isDirty: _lines.isNotEmpty,
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MovementBanner(
            colors: colors,
            icon: LucideIcons.clipboardCheck,
            message: l10n.adjustmentSubtitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          MovementProductsCard(
            accent: colors,
            onPick: _pick,
            rows: [
              for (final line in _lines)
                if (byId[line.itemId] != null)
                  _countRow(context, line, byId[line.itemId]!),
            ],
          ),
          if (_lines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: AppTextField(
                label: l10n.adjustmentNote,
                controller: _noteController,
                hint: l10n.adjustmentNoteHint,
                maxLines: 2,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _countRow(BuildContext context, _CountLine line, ItemRowView view) {
    final l10n = AppLocalizations.of(context);
    final system = view.item.quantity;
    final unit = view.unitAbbreviation;
    final delta = _delta(system, line.counted);
    final changed = _hasChange(system, line.counted);
    final done = line.confirmed && !changed;

    return MovementLineCard(
      key: ObjectKey(line),
      view: view,
      onRemove: () => _remove(line),
      inlineMinWidth: 700,
      state: done ? LineState.done : LineState.normal,
      subtitle: _isLargeDrop(system, line.counted)
          ? Text(
              l10n.adjustmentLargeDropWarning(
                Formatters.percent(delta.abs() / system),
              ),
              style: TextStyle(
                color: AppColors.lowStock.foreground,
                fontWeight: FontWeight.w600,
              ),
            )
          : Text(
              l10n.adjustmentExpected(
                Formatters.quantityWithUnit(system, unit),
              ),
            ),
      // The difference, in the colour of what it does to the stock.
      trailing: Text(
        changed ? Formatters.quantityDelta(delta, unit) : '—',
        style: AppTypography.numeric.copyWith(
          fontWeight: FontWeight.w700,
          color: quantityDeltaColor(delta),
        ),
      ),
      controls: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          QuantityStepper(
            compact: true,
            value: line.counted,
            unitAbbreviation: unit,
            focusNode: line.focus,
            textInputAction: TextInputAction.next,
            onSubmitted: () => _focusAfter(line),
            onChanged: (value) => setState(() {
              line.counted = value;
              line.confirmed = false;
            }),
          ),
          _CorrectButton(
            selected: done,
            onPressed: () => setState(() {
              line.counted = system;
              line.confirmed = true;
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(Map<String, ItemRowView> byId) async {
    final l10n = AppLocalizations.of(context);
    final items = ref.read(itemRepositoryProvider);
    final movements = ref.read(movementRepositoryProvider);

    // Re-read rather than trusting the rows on screen. A correction says what
    // the system believed at the moment it was made, and between the last
    // rebuild and this tap a delivery may have changed that — recording a
    // stale "système" figure would put a wrong number into the audit trail
    // for ever.
    final counts = <(Item, double)>[];
    for (final line in _lines) {
      final item = await items.item(line.itemId);
      if (item != null && _hasChange(item.quantity, line.counted)) {
        counts.add((item, line.counted));
      }
    }
    if (!mounted || counts.isEmpty) return;

    final drops = [
      for (final count in counts)
        if (_isLargeDrop(count.$1.quantity, count.$2)) count,
    ];
    if (drops.isNotEmpty) {
      final String message;
      if (drops.length == 1) {
        final (item, counted) = drops.single;
        message = l10n.adjustmentLargeConfirmBody(
          Formatters.quantityWithUnit(
            item.quantity - counted,
            byId[item.id]?.unitAbbreviation ?? '',
          ),
          item.name,
          Formatters.percent((item.quantity - counted) / item.quantity),
        );
      } else {
        message = l10n.adjustmentLargeConfirmBodyMany(
          drops.length,
          Formatters.percent(_largeDropThreshold),
        );
      }
      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.adjustmentLargeConfirmTitle,
        message: message,
        confirmLabel: l10n.actionConfirm,
      );
      if (!confirmed || !mounted) return;
    }

    // Who is at the tablet. Asked here, at the save, so the person who
    // confirms is the person who saves.
    final actor = await ActorConfirmSheet.show(
      context,
      storeId: widget.storeId,
      actionLabel: l10n.adjustmentSubmit,
    );
    if (actor == null || !mounted) return;
    final actorName = employeeDisplayName(actor);

    final note = _noteController.text.trim();
    setState(() => _saving = true);
    try {
      await movements.batch(() async {
        for (final (item, counted) in counts) {
          // Both figures are recorded, not just the difference: "we thought
          // 40, we counted 31" is the useful record and "−9" on its own is
          // not.
          await movements.recordAdjustment(
            storeId: widget.storeId,
            itemId: item.id,
            systemQuantity: item.quantity,
            countedQuantity: counted,
            note: note.isEmpty ? null : note,
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
      l10n.movementsRecordedBy(counts.length, actor.firstName),
    );
    context.goSection(Routes.toMovements(widget.storeId));
  }
}

/// "Juste" — the count matches. Filled green once pressed.
class _CorrectButton extends StatelessWidget {
  const _CorrectButton({required this.selected, required this.onPressed});

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const colors = AppColors.inStock;

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppSizing.minTapTarget),
        foregroundColor: colors.foreground,
        backgroundColor: selected ? colors.container : null,
        side: BorderSide(
          color: selected ? colors.solid : AppColors.border,
          width: selected ? 2 : 1,
        ),
        shape: const StadiumBorder(),
      ),
      icon: const Icon(LucideIcons.check, size: AppSizing.iconSm),
      label: Text(l10n.adjustmentMarkCorrect),
    );
  }
}
