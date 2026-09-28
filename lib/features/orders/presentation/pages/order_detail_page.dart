import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../documents/order_document_button.dart';
import '../widgets/order_actions.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/order_detail_view.dart';

/// One commande: what was ordered, what has arrived, and what can still be done
/// to it.
///
/// The action row is driven entirely by status. Actions that a status does not
/// allow are absent rather than disabled — a greyed-out "Réceptionner" on a
/// cancelled order invites the user to work out why, and there is no answer
/// they need.
class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({
    required this.storeId,
    required this.orderId,
    super.key,
  });

  final String storeId;
  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  static const String _tabLines = OrderDetailBody.tabLines;
  static const String _tabReceipts = OrderDetailBody.tabReceipts;

  String _tab = _tabLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Receiving, sending and closing all happen from here or from a screen
    // pushed above it, and the query behind this watches every table they
    // touch — so the page is right when the user comes back to it.
    final detail = ref.watch(orderDetailProvider(widget.orderId));
    final view = detail.value;

    if (view == null) {
      return ShellPage(
        title: l10n.ordersTitle,
        child: detail.isLoading
            ? const SkeletonList(rows: 4, rowHeight: 110)
            : ErrorState(
                message: l10n.errorStateBody,
                onRetry: () =>
                    context.goSection(Routes.toOrders(widget.storeId)),
              ),
      );
    }

    final order = view.order;
    final supplierName = view.supplierName;

    return ShellPage(
      back: BackDestination(
        label: l10n.ordersTitle,
        path: Routes.toOrders(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.ordersTitle, Routes.toOrders(widget.storeId)),
        Crumb(order.reference),
      ],
      title: l10n.orderDetailTitle(order.reference),
      subtitle: supplierName,
      actions: [
        OrderStatusBadge(status: order.status),
        // Every status: a draft to check before sending, a sent order to
        // forward again, a finished one for the records.
        OrderDocumentButton(order: order),
        ..._actionsFor(context, l10n, order, supplierName),
      ],
      tabs: SectionTabs(
        currentPath: _tab,
        onSelected: (value) => setState(() => _tab = value),
        tabs: [
          SectionTab(label: l10n.orderTabLines, path: _tabLines),
          SectionTab(label: l10n.orderTabReceipts, path: _tabReceipts),
        ],
      ),
      child: OrderDetailBody(
        storeId: widget.storeId,
        orderId: widget.orderId,
        tab: _tab,
        onTabChanged: (value) => setState(() => _tab = value),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions, by status
  // ---------------------------------------------------------------------------

  List<Widget> _actionsFor(
    BuildContext context,
    AppLocalizations l10n,
    PurchaseOrder order,
    String supplierName,
  ) {
    switch (order.status) {
      case PurchaseOrderStatus.draft:
        return [
          DestructiveButton(
            label: l10n.orderActionDelete,
            icon: LucideIcons.trash2,
            filled: false,
            onPressed: () => _confirmDelete(order),
          ),
          SecondaryButton(
            label: l10n.orderActionEdit,
            icon: LucideIcons.pencil,
            onPressed: () => context.pushScreen(
              Routes.toEditOrder(widget.storeId, order.id),
            ),
          ),
          PrimaryButton(
            label: l10n.orderActionSend,
            icon: LucideIcons.send,
            onPressed: () => _confirmSend(order, supplierName),
          ),
        ];

      case PurchaseOrderStatus.sent:
        return [
          if (orderCanCancel(order))
            DestructiveButton(
              label: l10n.orderActionCancel,
              icon: LucideIcons.ban,
              filled: false,
              onPressed: () => _confirmCancel(order),
            ),
          PrimaryButton(
            label: l10n.orderActionReceive,
            icon: LucideIcons.packageCheck,
            onPressed: () => context.pushScreen(
              Routes.toReceiveOrder(widget.storeId, order.id),
            ),
          ),
        ];

      case PurchaseOrderStatus.partial:
        return [
          SecondaryButton(
            label: l10n.orderActionCloseShort,
            icon: LucideIcons.packageX,
            onPressed: () => _confirmClose(order),
          ),
          PrimaryButton(
            label: l10n.orderActionReceive,
            icon: LucideIcons.packageCheck,
            onPressed: () => context.pushScreen(
              Routes.toReceiveOrder(widget.storeId, order.id),
            ),
          ),
        ];

      // Final. Nothing left to do but read it — or order the same again.
      case PurchaseOrderStatus.received:
      case PurchaseOrderStatus.cancelled:
        return [
          PrimaryButton(
            label: l10n.orderActionDuplicate,
            icon: LucideIcons.copy,
            onPressed: () =>
                duplicateOrder(context, ref, widget.storeId, order),
          ),
        ];
    }
  }

  Future<void> _confirmSend(PurchaseOrder order, String supplierName) =>
      confirmSendOrder(context, ref, order, supplierName);

  Future<void> _confirmDelete(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: order.reference,
      extraWarning: l10n.orderDeleteWarning,
    );
    if (!confirmed || !mounted) return;

    await ref.read(orderRepositoryProvider).deleteDraft(order.id);

    if (!mounted) return;
    AppSnackBar.success(context, l10n.orderDeleted);
    context.goSection(Routes.toOrders(widget.storeId));
  }

  Future<void> _confirmCancel(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.orderCancelConfirmTitle(order.reference),
      message: l10n.orderCancelConfirmBody,
      confirmLabel: l10n.orderCancelConfirmAction,
    );
    if (!confirmed || !mounted) return;

    await ref.read(orderRepositoryProvider).cancel(order.id);

    if (!mounted) return;
    AppSnackBar.success(context, l10n.orderCancelled);
  }

  Future<void> _confirmClose(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);
    final outstanding = order.lines.where((l) => !lineIsSettled(l)).length;

    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.orderCloseConfirmTitle(order.reference),
      message: l10n.orderCloseConfirmBody(outstanding),
      confirmLabel: l10n.orderCloseConfirmAction,
    );
    if (!confirmed || !mounted) return;

    await ref.read(orderRepositoryProvider).closeShort(order.id);

    if (!mounted) return;
    AppSnackBar.success(context, l10n.orderClosed);
  }
}
