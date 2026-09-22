import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../documents/order_document_button.dart';
import '../widgets/order_status_badge.dart';

/// Réceptions — what is due to arrive, and what has arrived.
///
/// The page for whoever is at the door when the van pulls up. Receiving used
/// to mean opening Commandes, finding the order among drafts and finished
/// ones, opening it, then pressing Réceptionner. Here every order waiting for
/// its delivery is a card with that button on it.
///
/// Two tabs:
/// - **À réceptionner** — every order sent or partly received, the late ones
///   first, then the oldest.
/// - **Historique** — every bon de réception in the store, newest first.
class ReceptionsPage extends ConsumerStatefulWidget {
  const ReceptionsPage({
    required this.storeId,
    this.showHistory = false,
    super.key,
  });

  final String storeId;

  /// Opens on the Historique tab.
  final bool showHistory;

  @override
  ConsumerState<ReceptionsPage> createState() => _ReceptionsPageState();
}

class _ReceptionsPageState extends ConsumerState<ReceptionsPage> {
  static const _pending = 'pending';
  static const _history = 'history';

  late String _tab = widget.showHistory ? _history : _pending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.receptionsTitle,
      subtitle: l10n.receptionsSubtitle,
      tabs: SectionTabs(
        currentPath: _tab,
        onSelected: (value) => setState(() => _tab = value),
        tabs: [
          SectionTab(label: l10n.receptionsTabPending, path: _pending),
          SectionTab(label: l10n.receptionsTabHistory, path: _history),
        ],
      ),
      child: _tab == _pending
          ? _Pending(storeId: widget.storeId)
          : _History(storeId: widget.storeId),
    );
  }
}

// -----------------------------------------------------------------------------
// À réceptionner
// -----------------------------------------------------------------------------

class _Pending extends ConsumerWidget {
  const _Pending({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final staleDays =
        ref.watch(stalePartialOrderDaysProvider(storeId)).value ??
        OrderRules.defaultStalePartialDays;

    return AsyncContent<List<OrderRowView>>(
      value: ref.watch(openOrderRowsProvider(storeId)),
      onRetry: () => ref.invalidate(openOrderRowsProvider(storeId)),
      builder: (context, rows) {
        if (rows.isEmpty) {
          return EmptyState(
            icon: LucideIcons.packageCheck,
            title: l10n.receptionsPendingEmpty,
            message: l10n.receptionsPendingEmptyBody,
          );
        }

        // Late first — an order left half-received keeps the "en commande"
        // figure inflated until somebody deals with it — then the one waiting
        // longest.
        final sorted = [...rows]
          ..sort((a, b) {
            final lateA = orderIsStale(a.order, staleDays);
            final lateB = orderIsStale(b.order, staleDays);
            if (lateA != lateB) return lateA ? -1 : 1;
            return daysOpen(b.order).compareTo(daysOpen(a.order));
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final view in sorted) ...[
              _PendingCard(
                storeId: storeId,
                view: view,
                late: orderIsStale(view.order, staleDays),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

/// One order waiting for its delivery: who, which, since when, how much is
/// left — and the button to receive it.
class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.storeId,
    required this.view,
    required this.late,
  });

  final String storeId;
  final OrderRowView view;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final order = view.order;
    final linesLeft = order.lines
        .where((line) => lineOutstanding(line) > 0)
        .length;
    final sentAt = order.sentAt ?? order.createdAt;

    final receive = PrimaryButton(
      label: l10n.receptionsReceive,
      icon: LucideIcons.packageCheck,
      onPressed: () =>
          context.pushScreen(Routes.toReceiveOrder(storeId, order.id)),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(view.supplierName, style: theme.textTheme.titleMedium),
            OrderStatusBadge(status: order.status),
            if (late)
              StatusPill(
                colors: AppColors.lowStock,
                icon: LucideIcons.clock,
                label: l10n.receptionsLate,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${order.reference} · '
          '${l10n.receptionsSentOn(Formatters.date(sentAt))} · '
          '${Formatters.relative(sentAt)}',
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.receptionsLinesLeft(linesLeft),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return AppCard(
      onTap: () => context.pushScreen(Routes.toOrder(storeId, order.id)),
      accentColor: late ? AppColors.lowStock.solid : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow: the buttons go under the details, receive at full width.
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: receive),
                    const SizedBox(width: AppSpacing.sm),
                    OrderDocumentButton(order: order, compact: true),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: AppSpacing.md),
              OrderDocumentButton(order: order, compact: true),
              const SizedBox(width: AppSpacing.sm),
              receive,
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Historique
// -----------------------------------------------------------------------------

class _History extends ConsumerWidget {
  const _History({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AsyncContent<List<StoreReceiptRowView>>(
      value: ref.watch(storeReceiptRowsProvider(storeId)),
      onRetry: () => ref.invalidate(storeReceiptRowsProvider(storeId)),
      builder: (context, rows) {
        if (rows.isEmpty) {
          return EmptyState(
            icon: LucideIcons.receiptText,
            title: l10n.receptionsHistoryEmpty,
            message: l10n.receptionsHistoryEmptyBody,
          );
        }

        return AppTable<StoreReceiptRowView>(
          rows: rows,
          shrinkWrap: true,
          onRowTap: (row) =>
              context.pushScreen(Routes.toReceipt(storeId, row.receipt.id)),
          columns: [
            AppTableColumn(label: l10n.tableColDate, width: 150),
            AppTableColumn(label: l10n.tableColReceipt, width: 150),
            AppTableColumn(label: l10n.tableColSupplier, flex: 3),
            AppTableColumn(
              label: l10n.tableColOrder,
              width: 140,
              minTableWidth: 820,
            ),
            AppTableColumn(
              label: l10n.tableColReceivedBy,
              flex: 2,
              minTableWidth: 700,
            ),
            AppTableColumn(
              label: l10n.tableColValue,
              width: 112,
              numeric: true,
              minTableWidth: 560,
            ),
            AppTableColumn(label: l10n.tableColDiscrepancies, width: 132),
          ],
          cell: (context, row, column) => switch (column) {
            0 => Text(
              Formatters.dateTime(row.receipt.receivedAt),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            1 => Text(
              row.reference,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            2 => Text(
              row.supplierName,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            3 => Text(
              row.orderReference,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            4 => Text(
              row.receipt.receivedByName,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            5 => Text(
              Formatters.price(row.value),
              style: AppTypography.numeric,
              maxLines: 1,
            ),
            _ =>
              row.discrepancies == 0
                  ? StatusDot(
                      color: AppColors.inStock.solid,
                      label: l10n.receptionsConform,
                    )
                  : StatusDot(
                      color: AppColors.lowStock.solid,
                      label: l10n.receptionsDiscrepancies(row.discrepancies),
                    ),
          },
        );
      },
    );
  }
}
