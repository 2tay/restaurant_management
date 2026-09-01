import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
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
class ReceiveOrderPage extends ConsumerWidget {
  const ReceiveOrderPage({
    required this.storeId,
    required this.orderId,
    super.key,
  });

  final String storeId;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(orderDetailProvider(orderId));
    final view = detail.value;

    if (view == null) {
      return ShellPage(
        title: l10n.ordersTitle,
        child: detail.isLoading
            ? const SkeletonList(rows: 4, rowHeight: 110)
            : ErrorState(
                message: l10n.errorStateBody,
                onRetry: () => context.goSection(Routes.toOrders(storeId)),
              ),
      );
    }

    return _ReceiveForm(
      // Keyed on the commande so opening a different one rebuilds the lines
      // rather than keeping the previous delivery's numbers.
      key: ValueKey(orderId),
      storeId: storeId,
      view: view,
    );
  }
}

class _ReceiveForm extends ConsumerStatefulWidget {
  const _ReceiveForm({required this.storeId, required this.view, super.key});

  final String storeId;
  final OrderDetailView view;

  @override
  ConsumerState<_ReceiveForm> createState() => _ReceiveOrderPageState();
}

class _ReceiveOrderPageState extends ConsumerState<_ReceiveForm> {
  final _noteController = TextEditingController();
  final List<ReceiveLineDraft> _lines = [];

  /// The article on each line, by id — for the row labels and the price
  /// warnings. Taken from the commande, which already names every line.
  late final Map<String, OrderLineView> _lineViews = {
    for (final line in widget.view.lines) line.line.itemId: line,
  };

  @override
  void initState() {
    super.initState();

    for (final line in widget.view.order.lines) {
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
    final order = widget.view.order;

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
                  itemName: _nameOf(line.itemId),
                  unitAbbreviation: _unitOf(line.itemId),
                  onChanged: () => setState(() {}),
                  onRemove: line.wasUnordered ? () => _removeLine(line) : null,
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
    final order = widget.view.order;
    final onReceipt = _lines.map((line) => line.itemId).toSet();
    final choice = await _UnorderedItemSheet.show(
      context,
      storeId: widget.storeId,
      supplierId: order.supplierId,
      excludedItemIds: onReceipt,
    );
    if (choice == null || !mounted) return;

    setState(() {
      _lineViews[choice.itemId] = OrderLineView(
        // A line that was never ordered still needs a name and a unit on the
        // row, and the picker has just handed both over.
        line: PurchaseOrderLine(
          id: 'unordered-${choice.itemId}',
          itemId: choice.itemId,
          quantityOrdered: 0,
          quantityReceived: 0,
          unitPrice: choice.unitPrice,
        ),
        itemName: choice.itemName,
        unitAbbreviation: choice.unitAbbreviation,
      );
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

      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.receivePriceConfirmTitle,
        message: l10n.receivePriceConfirmBody(
          _nameOf(line.itemId),
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

    final orderId = widget.view.order.id;
    await ref
        .read(orderRepositoryProvider)
        .confirmReceipt(
          orderId: orderId,
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
    context.backTo(Routes.toOrder(widget.storeId, orderId));
  }

  String _nameOf(String itemId) => _lineViews[itemId]?.itemName ?? '—';

  String _unitOf(String itemId) => _lineViews[itemId]?.unitAbbreviation ?? '';
}

/// What the receiver picked when adding a line that was not on the order.
@immutable
class _UnorderedChoice {
  const _UnorderedChoice({
    required this.itemId,
    required this.itemName,
    required this.unitAbbreviation,
    required this.unitPrice,
  });

  final String itemId;

  /// Carried back with the id so the row it becomes has a name without asking
  /// again — the sheet was already showing one.
  final String itemName;
  final String unitAbbreviation;

  final double unitPrice;
}

/// Picks an item for an unordered line.
///
/// Offers every item in the store rather than only this supplier's, because the
/// point of the case is that something turned up which the order did not
/// anticipate. The supplier's own price is pre-filled when there is one.
class _UnorderedItemSheet extends ConsumerStatefulWidget {
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
  ConsumerState<_UnorderedItemSheet> createState() =>
      _UnorderedItemSheetState();
}

class _UnorderedItemSheetState extends ConsumerState<_UnorderedItemSheet> {
  String? _itemId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final rows =
        ref.watch(itemRowsProvider((
              storeId: widget.storeId,
              filter: ItemFilter.none,
            ))).value ??
        const <ItemRowView>[];

    final items = [
      for (final row in rows)
        if (!widget.excludedItemIds.contains(row.item.id)) row,
    ];

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
              for (final row in items)
                DropdownOption(
                  value: row.item.id,
                  label: row.item.name,
                  secondaryLabel: row.categoryName,
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
                onPressed: _itemId == null ? null : () => _submit(items),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit(List<ItemRowView> items) async {
    final itemId = _itemId!;
    final price = await ref
        .read(supplierRepositoryProvider)
        .priceFor(itemId, widget.supplierId);
    if (!mounted) return;

    var name = '—';
    var unit = '';
    for (final row in items) {
      if (row.item.id == itemId) {
        name = row.item.name;
        unit = row.unitAbbreviation;
      }
    }

    Navigator.of(context).pop(
      _UnorderedChoice(
        itemId: itemId,
        itemName: name,
        unitAbbreviation: unit,
        // Zero when this supplier has no price on file for the article, which
        // is ordinary for something that was not ordered from them.
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
