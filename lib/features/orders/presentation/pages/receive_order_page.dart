import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/receive_line_row.dart';
import '../widgets/order_summary_card.dart';

/// Check in a delivery.
///
/// The screen the whole feature exists for, and the only place stock moves
/// through an order. Its shape follows from what actually happens at a
/// restaurant's back door:
///
/// - **Quantities are pre-filled with what is outstanding.** The delivery
///   usually matches the order, and making staff retype the common case is how
///   a receiving screen ends up bypassed.
/// - **Short deliveries are handled inline, never in a dialog.** A van holds
///   twenty lines; a modal per shortfall would make checking one in a sequence
///   of interruptions.
/// - **Unordered items are allowed but flagged.** The driver brought something
///   extra; refusing it would only push staff to the manual stock-in screen and
///   lose the link to the delivery.
class ReceiveOrderPage extends StatefulWidget {
  const ReceiveOrderPage({
    required this.storeId,
    required this.orderId,
    super.key,
  });

  final String storeId;
  final String orderId;

  @override
  State<ReceiveOrderPage> createState() => _ReceiveOrderPageState();
}

class _ReceiveOrderPageState extends State<ReceiveOrderPage> {
  final _noteController = TextEditingController();
  final List<ReceiveLineDraft> _lines = [];

  @override
  void initState() {
    super.initState();

    final order = MockQueries.orderById(widget.orderId);
    if (order == null) return;

    for (final line in order.lines) {
      final outstanding = lineOutstanding(line);
      // Settled lines are not shown. They are done, and listing them would bury
      // the two lines that actually need attention.
      if (outstanding <= 0) continue;
      _lines.add(
        ReceiveLineDraft(
          itemId: line.itemId,
          quantityOrdered: outstanding,
          orderedUnitPrice: line.unitPrice,
        ),
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit => _lines.any((line) => line.quantityReceived > 0);

  /// Any input at all is worth protecting — the whole screen starts pre-filled,
  /// so leaving it always throws work away.
  bool get _isDirty => _lines.isNotEmpty;

  double get _receivedValue {
    var total = 0.0;
    for (final line in _lines) {
      total += line.lineValue;
    }
    return total;
  }

  int get _receivedLines =>
      _lines.where((line) => line.quantityReceived > 0).length;

  int get _discrepancies =>
      _lines.where((line) => isDiscrepancy(line.outcome)).length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = MockQueries.orderById(widget.orderId);

    if (order == null) {
      return ShellPage(
        title: l10n.ordersTitle,
        child: ErrorState(
          message: l10n.errorStateBody,
          onRetry: () => context.goSection(Routes.toOrders(widget.storeId)),
        ),
      );
    }

    final back = BackDestination(
      label: order.reference,
      path: Routes.toOrder(widget.storeId, order.id),
    );

    return FormScaffold(
      title: l10n.receiveOrderTitle(order.reference),
      subtitle: l10n.receiveOrderSubtitle,
      back: back,
      crumbs: [
        Crumb(l10n.ordersTitle, Routes.toOrders(widget.storeId)),
        Crumb(order.reference, Routes.toOrder(widget.storeId, order.id)),
        Crumb(l10n.orderActionReceive),
      ],
      submitLabel: l10n.receiveConfirm,
      submitIcon: LucideIcons.packageCheck,
      onSubmit: _canSubmit ? _confirm : null,
      isDirty: _isDirty,
      maxWidth: 1080,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ManagerNotice(message: l10n.receiveManagerNotice),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(
            title: l10n.orderTabLines,
            count: _lines.isEmpty ? null : _lines.length,
            trailing: SecondaryButton(
              label: l10n.receiveAddUnordered,
              icon: LucideIcons.circlePlus,
              onPressed: _addUnorderedLine,
            ),
          ),

          if (_lines.isEmpty)
            AppCard(
              child: EmptyState(
                icon: LucideIcons.packageCheck,
                title: l10n.receiveNothing,
                message: l10n.orderReceiptsEmpty,
                actionLabel: l10n.receiveAddUnordered,
                actionIcon: LucideIcons.circlePlus,
                onAction: _addUnorderedLine,
              ),
            )
          else
            for (final line in _lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ReceiveLineRow(
                  key: ValueKey('${line.itemId}-${line.wasUnordered}'),
                  draft: line,
                  onChanged: () => setState(() {}),
                  onRemove: line.wasUnordered
                      ? () => _removeLine(line)
                      : null,
                ),
              ),

          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: AppTextField(
              label: l10n.receiveNoteLabel,
              controller: _noteController,
              hint: l10n.receiveNoteHint,
              maxLines: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Stated before the confirm button is reached. Receiving moves stock
          // and money; the totals should not have to be worked out from the
          // lines above.
          OrderSummaryCard(
            title: l10n.receiveSummaryTitle,
            figures: [
              OrderFigure(
                label: l10n.receiveSummaryValue,
                value: Formatters.price(_receivedValue),
                emphasis: true,
              ),
              OrderFigure(
                label: l10n.receiveSummaryLines,
                value: '$_receivedLines',
              ),
              OrderFigure(
                label: l10n.receiveSummaryDiscrepancies,
                value: '$_discrepancies',
                accent: _discrepancies == 0 ? null : AppColors.lowStock,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _removeLine(ReceiveLineDraft line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
    AppSnackBar.success(
      context,
      AppLocalizations.of(context).receiveUnorderedRemoved,
    );
  }

  Future<void> _addUnorderedLine() async {
    final order = MockQueries.orderById(widget.orderId);
    if (order == null) return;

    final onReceipt = _lines.map((line) => line.itemId).toSet();
    final choice = await _UnorderedItemSheet.show(
      context,
      storeId: widget.storeId,
      supplierId: order.supplierId,
      excludedItemIds: onReceipt,
    );
    if (choice == null || !mounted) return;

    setState(() {
      _lines.add(
        ReceiveLineDraft(
          itemId: choice.itemId,
          // Nothing was ordered, so there is no outstanding quantity to
          // compare against. The line is flagged rather than measured.
          quantityOrdered: 0,
          orderedUnitPrice: choice.unitPrice,
          wasUnordered: true,
        ),
      );
      // Pre-filling the received quantity from the order is meaningless here,
      // so start at one and let the receiver step it up.
      _lines.last.quantityReceived = 1;
    });
    AppSnackBar.success(
      context,
      AppLocalizations.of(context).receiveUnorderedAdded,
    );
  }

  // ---------------------------------------------------------------------------
  // Confirming
  // ---------------------------------------------------------------------------

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);

    // A price that has moved a long way is usually either a real increase the
    // owner needs to know about or a typo. Both are worth one interruption;
    // neither is worth silently writing into the price history.
    for (final line in _lines) {
      if (line.quantityReceived <= 0) continue;
      if (!priceMovedSignificantly(
        line.orderedUnitPrice,
        line.actualUnitPrice,
      )) {
        continue;
      }

      final item = MockQueries.itemById(line.itemId);
      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.receivePriceConfirmTitle,
        message: l10n.receivePriceConfirmBody(
          item?.name ?? '—',
          Formatters.price(line.orderedUnitPrice),
          Formatters.price(line.actualUnitPrice),
        ),
        confirmLabel: l10n.receivePriceConfirmAction,
        isDestructive: false,
      );
      // Declining leaves the receiver on the form with the field still focused
      // on the number they need to fix, rather than throwing the whole delivery
      // away.
      if (!confirmed) return;
      if (!mounted) return;
    }

    MockOperations.confirmReceipt(
      orderId: widget.orderId,
      lines: [
        for (final line in _lines)
          if (line.quantityReceived > 0) line.toDraftLine(),
      ],
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    if (!mounted) return;
    AppSnackBar.success(context, l10n.receiveConfirmed);
    context.backTo(Routes.toOrder(widget.storeId, widget.orderId));
  }
}

/// What the receiver picked when adding a line that was not on the order.
@immutable
class _UnorderedChoice {
  const _UnorderedChoice({required this.itemId, required this.unitPrice});

  final String itemId;
  final double unitPrice;
}

/// Picks an item for an unordered line.
///
/// Offers every item in the store rather than only this supplier's, because the
/// point of the case is that something turned up which the order did not
/// anticipate. The supplier's own price is pre-filled when there is one.
class _UnorderedItemSheet extends StatefulWidget {
  const _UnorderedItemSheet({
    required this.storeId,
    required this.supplierId,
    required this.excludedItemIds,
  });

  final String storeId;
  final String supplierId;
  final Set<String> excludedItemIds;

  static Future<_UnorderedChoice?> show(
    BuildContext context, {
    required String storeId,
    required String supplierId,
    required Set<String> excludedItemIds,
  }) {
    return showModalBottomSheet<_UnorderedChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _UnorderedItemSheet(
        storeId: storeId,
        supplierId: supplierId,
        excludedItemIds: excludedItemIds,
      ),
    );
  }

  @override
  State<_UnorderedItemSheet> createState() => _UnorderedItemSheetState();
}

class _UnorderedItemSheetState extends State<_UnorderedItemSheet> {
  String? _itemId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final items = MockQueries.itemsForStore(widget.storeId)
        .where((item) => !widget.excludedItemIds.contains(item.id))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.receiveAddUnordered,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppDropdown<String>(
            label: l10n.orderLinePickerLabel,
            value: _itemId,
            options: [
              for (final item in items)
                DropdownOption(
                  value: item.id,
                  label: item.name,
                  secondaryLabel: MockQueries.categoryNameOf(item.categoryId),
                ),
            ],
            onChanged: (value) => setState(() => _itemId = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SecondaryButton(
                label: l10n.actionCancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
              PrimaryButton(
                label: l10n.orderAddLine,
                icon: LucideIcons.plus,
                onPressed: _itemId == null ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final price = MockQueries.priceFor(_itemId!, widget.supplierId);
    Navigator.of(context).pop(
      _UnorderedChoice(
        itemId: _itemId!,
        unitPrice: price?.pricePerUnit ?? 0,
      ),
    );
  }
}

/// Says why this screen is a manager's job.
class _ManagerNotice extends StatelessWidget {
  const _ManagerNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.shieldCheck,
            size: AppSizing.iconMd,
            color: AppColors.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
