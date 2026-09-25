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
import '../../../../core/utils/responsive.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../documents/order_document_button.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/order_visuals.dart';
import '../widgets/order_detail_view.dart';

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

/// Lays [children] out [columns] to a row, each row as tall as its tallest
/// card so the buttons along their bottoms line up.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            child,
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < children.length; start += columns) ...[
          if (start > 0) const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < start + columns; i++) ...[
                  if (i > start) const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: i < children.length
                        ? children[i]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
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
    final theme = Theme.of(context);
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
        final late = sorted
            .where((view) => orderIsStale(view.order, staleDays))
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l10n.ordersCount(sorted.length),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (late > 0) ...[
                    const TextSpan(text: '  ·  '),
                    TextSpan(
                      text: '$late ${l10n.receptionsLate.toLowerCase()}',
                      style: TextStyle(
                        color: AppColors.lowStock.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) => _CardGrid(
                columns: cardGridColumns(
                  constraints.maxWidth,
                  minCardWidth: 380,
                  singleColumnBelow: 640,
                  maxColumns: 3,
                ),
                children: [
                  for (final view in sorted)
                    _PendingCard(
                      storeId: storeId,
                      view: view,
                      late: orderIsStale(view.order, staleDays),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One order waiting for its delivery: who, which, since when, how much has
/// arrived — and, along the bottom, the button to receive it.
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

    return AppCard(
      // A panel, so checking what is on a commande does not cost the place in
      // the list. The card keeps its own Réceptionner button, which is what
      // makes the split worth having: the button goes straight to the form,
      // tapping the card opens the commande to look first.
      onTap: () => openOrderPanel(context, storeId: storeId, orderId: order.id),
      accentColor: late ? AppColors.lowStock.solid : null,
      padding: EdgeInsets.zero,
      // spaceBetween rather than a Spacer: it pushes the footer to the bottom
      // when the grid stretches a card to its neighbour's height, and does
      // nothing — rather than throw — in a single column of unbounded height.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SupplierMonogram(name: view.supplierName),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            view.supplierName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            order.reference,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OrderStatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    MetaItem(
                      icon: LucideIcons.send,
                      label: l10n.receptionsSentOn(Formatters.date(sentAt)),
                    ),
                    MetaItem(
                      icon: LucideIcons.clock,
                      label: Formatters.relative(sentAt),
                    ),
                    if (late)
                      MetaItem(
                        icon: LucideIcons.triangleAlert,
                        label: l10n.receptionsLate,
                        color: AppColors.lowStock.foreground,
                        emphasis: true,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.receptionsLinesLeft(linesLeft),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      Formatters.price(orderTotal(order)),
                      style: AppTypography.numeric.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ReceivedProgress(
                  share: orderReceivedShare(order),
                  label: l10n.tableColReceived,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.neutral50,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                OrderDocumentButton(order: order, compact: true),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    label: l10n.receptionsReceive,
                    icon: LucideIcons.packageCheck,
                    onPressed: () => context.pushScreen(
                      Routes.toReceiveOrder(storeId, order.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

        // A recorded réception is pure reference — there is nothing to do with
        // it but read it — which is exactly what a panel is for.
        void open(StoreReceiptRowView row) =>
            openReceiptPanel(context, storeId: storeId, receiptId: row.receipt.id);

        // A table only where it has the width to be one; below that, a table
        // would keep three of its seven columns and read as a list anyway.
        return LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 640
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, row) in rows.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      _ReceiptCard(row: row, onTap: () => open(row)),
                    ],
                  ],
                )
              : _ReceiptTable(rows: rows, onOpen: open),
        );
      },
    );
  }
}

/// Conforme in green, or how many lines disagreed with the order in amber.
class _Conformity extends StatelessWidget {
  const _Conformity({required this.discrepancies});

  final int discrepancies;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return discrepancies == 0
        ? StatusPill(
            colors: AppColors.inStock,
            icon: LucideIcons.circleCheck,
            label: l10n.receptionsConform,
          )
        : StatusPill(
            colors: AppColors.lowStock,
            icon: LucideIcons.triangleAlert,
            label: l10n.receptionsDiscrepancies(discrepancies),
          );
  }
}

class _ReceiptTable extends StatelessWidget {
  const _ReceiptTable({required this.rows, required this.onOpen});

  final List<StoreReceiptRowView> rows;
  final ValueChanged<StoreReceiptRowView> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    return AppTable<StoreReceiptRowView>(
      rows: rows,
      shrinkWrap: true,
      rowHeight: 64,
      onRowTap: onOpen,
      rowAccent: (row) =>
          row.discrepancies > 0 ? AppColors.lowStock.solid : null,
      columns: [
        AppTableColumn(label: l10n.tableColDate, width: 132),
        AppTableColumn(label: l10n.tableColReceipt, width: 140),
        AppTableColumn(label: l10n.tableColSupplier, flex: 3),
        AppTableColumn(
          label: l10n.tableColOrder,
          width: 140,
          minTableWidth: 900,
        ),
        AppTableColumn(
          label: l10n.tableColReceivedBy,
          flex: 2,
          minTableWidth: 1040,
        ),
        AppTableColumn(
          label: l10n.tableColValue,
          width: 120,
          numeric: true,
          minTableWidth: 760,
        ),
        AppTableColumn(label: l10n.tableColDiscrepancies, width: 144),
      ],
      cell: (context, row, column) => switch (column) {
        0 => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.date(row.receipt.receivedAt),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
            ),
            Text(
              Formatters.time(row.receipt.receivedAt),
              style: muted,
              maxLines: 1,
            ),
          ],
        ),
        1 => Text(
          row.reference,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        2 => Row(
          children: [
            SupplierMonogram(name: row.supplierName, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                row.supplierName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        3 => MetaItem(
          icon: LucideIcons.clipboardList,
          label: row.orderReference,
        ),
        4 => MetaItem(
          icon: LucideIcons.user,
          label: row.receipt.receivedByName,
        ),
        5 => Text(
          Formatters.price(row.value),
          style: AppTypography.numeric.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
        ),
        _ => _Conformity(discrepancies: row.discrepancies),
      },
    );
  }
}

/// A bon de réception on a phone: supplier and value on top, the paperwork
/// underneath, conformity along the bottom.
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.row, required this.onTap});

  final StoreReceiptRowView row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      accentColor: row.discrepancies > 0 ? AppColors.lowStock.solid : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SupplierMonogram(name: row.supplierName, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.supplierName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        MetaItem(
                          icon: LucideIcons.receiptText,
                          label: row.reference,
                        ),
                        MetaItem(
                          icon: LucideIcons.clipboardList,
                          label: row.orderReference,
                        ),
                        MetaItem(
                          icon: LucideIcons.calendar,
                          label: Formatters.dateTime(row.receipt.receivedAt),
                        ),
                        MetaItem(
                          icon: LucideIcons.user,
                          label: row.receipt.receivedByName,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Formatters.price(row.value),
                style: AppTypography.numeric.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: _Conformity(discrepancies: row.discrepancies),
          ),
        ],
      ),
    );
  }
}
