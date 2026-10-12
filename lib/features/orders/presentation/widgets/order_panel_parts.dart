import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../documents/order_document_button.dart';
import 'order_detail_view.dart';
import 'order_status_badge.dart';
import 'order_visuals.dart';

/// The pieces of a commande shown as a panel: a header that names it, a
/// summary card, tabs, the lines, the total and a footer for the PDF.
///
/// Laid out by `OrderDetailBody`; kept apart from it so the page's layout and
/// the panel's can each be read on their own.

/// The panel's top: the commande, who it is with, where it stands, and the
/// way out.
class OrderPanelHeader extends StatelessWidget {
  const OrderPanelHeader({
    required this.panel,
    required this.order,
    required this.supplierName,
    super.key,
  });

  final PanelController panel;
  final PurchaseOrder order;
  final String supplierName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (panel.canGoBack) ...[
          IconButton(
            onPressed: panel.back,
            tooltip: l10n.actionBack,
            icon: const Icon(LucideIcons.arrowLeft, size: AppSizing.iconMd),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.6),
            borderRadius: AppRadius.mdAll,
          ),
          child: const Icon(
            LucideIcons.fileText,
            size: AppSizing.iconMd,
            color: AppColors.primary700,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.orderDetailTitle(order.reference),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                supplierName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        OrderDocumentButton(order: order, compact: true),
        IconButton(
          onPressed: panel.close,
          tooltip: l10n.actionClose,
          icon: const Icon(LucideIcons.x, size: AppSizing.iconMd),
        ),
      ],
    );
  }
}

/// The figures that answer "how much, and when", then the three facts the
/// commande is looked up by.
class OrderPanelSummary extends StatelessWidget {
  const OrderPanelSummary({
    required this.order,
    required this.supplierName,
    super.key,
  });

  final PurchaseOrder order;
  final String supplierName;

  /// Below this the summary's cells stack instead of sharing a row.
  static const double _stacksBelow = 420;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final total = _Cell(
      label: l10n.orderTotalLabel,
      child: Text(
        Formatters.price(orderTotal(order)),
        style: AppTypography.numericHero,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final date = _Cell(
      label: l10n.orderPanelDate,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.calendar,
            size: AppSizing.iconSm,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              Formatters.dateTime(order.createdAt),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final lines = _Cell(
      label: l10n.orderTabLines,
      child: Text(
        l10n.orderPanelItems(order.lines.length),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
      ),
    );
    final supplier = _Cell(
      label: l10n.tableColSupplier,
      child: Row(
        children: [
          SupplierMonogram(name: supplierName, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              supplierName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    final reference = _Cell(
      label: l10n.tableColReference,
      child: Row(
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                order.reference,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.orderPanelCopyReference,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: order.reference));
              if (context.mounted) {
                AppSnackBar.success(context, l10n.orderPanelReferenceCopied);
              }
            },
            icon: const Icon(
              LucideIcons.copy,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < _stacksBelow;
          const hDivider = Divider(height: 1, color: AppColors.hairline);
          const vDivider = VerticalDivider(width: 1, color: AppColors.hairline);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The headline band, lightly tinted so the total reads first.
              Container(
                color: AppColors.neutral50,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: total),
                      vDivider,
                      Expanded(child: date),
                    ],
                  ),
                ),
              ),
              hDivider,
              // On a phone the supplier, whose name is the longest of the
              // three, takes a row of its own under the other two.
              if (narrow) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: lines),
                      vDivider,
                      Expanded(child: reference),
                    ],
                  ),
                ),
                hDivider,
                supplier,
              ] else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 2, child: lines),
                      vDivider,
                      Expanded(flex: 3, child: supplier),
                      vDivider,
                      Expanded(flex: 4, child: reference),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// One tab of an [OrderPanelTabs] bar.
@immutable
class OrderPanelTab {
  const OrderPanelTab({
    required this.id,
    required this.label,
    this.shortLabel,
    this.count,
  });

  final String id;
  final String label;

  /// Used instead of [label] on a phone-width panel.
  final String? shortLabel;

  /// Shown in a small counter after the label.
  final int? count;
}

/// The panel's tabs: teal for the open one, each with what it holds.
///
/// Scrolls sideways rather than wrapping when a phone cannot fit the three
/// French labels — a bar broken over two lines reads as two bars.
class OrderPanelTabs extends StatelessWidget {
  const OrderPanelTabs({
    required this.tabs,
    required this.current,
    required this.onSelected,
    super.key,
  });

  final List<OrderPanelTab> tabs;
  final String current;
  final ValueChanged<String>? onSelected;

  /// Below this a tab with a [OrderPanelTab.shortLabel] uses it.
  static const double _shortLabelsBelow = 420;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (i, tab) in tabs.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                _TabChip(
                  tab: tab,
                  selected: tab.id == current,
                  compact: constraints.maxWidth < _shortLabelsBelow,
                  onTap: () => onSelected?.call(tab.id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final OrderPanelTab tab;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = selected ? AppColors.white : AppColors.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary700 : Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: selected ? null : onTap,
          borderRadius: AppRadius.mdAll,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizing.toolbarControlHeight + 4,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  compact ? tab.shortLabel ?? tab.label : tab.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (tab.count != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.white.withValues(alpha: 0.22)
                          : AppColors.neutral100,
                      borderRadius: AppRadius.pillAll,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${tab.count}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ordered lines, one structured row each, in a single bordered card.
class OrderPanelLines extends StatelessWidget {
  const OrderPanelLines({required this.lines, super.key});

  final List<OrderLineView> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, line) in lines.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.hairline),
            _LineRow(view: line),
          ],
        ],
      ),
    );
  }
}

/// One line: the article and where it stands on top, its four figures in
/// aligned columns underneath.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.view});

  final OrderLineView view;

  /// Below this the four figures take two rows of two.
  static const double _figuresWrapBelow = 320;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final line = view.line;
    final unit = view.unitAbbreviation;
    final received = line.quantityReceived > 0;

    final figures = [
      _Figure(
        label: l10n.orderColumnOrdered,
        value: Formatters.quantityWithUnit(line.quantityOrdered, unit),
      ),
      _Figure(
        label: l10n.orderColumnReceived,
        value: Formatters.quantityWithUnit(line.quantityReceived, unit),
        muted: !received,
      ),
      _Figure(
        label: l10n.orderColumnUnitPrice,
        value: Formatters.price(line.unitPrice),
      ),
      _Figure(
        label: l10n.orderColumnLineTotal,
        value: Formatters.price(lineTotal(line)),
        strong: true,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(
                SupplierMonogram.initialsOf(view.itemName),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          view.itemName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: OrderLineState(
                        line: line,
                        outstanding: lineOutstanding(line),
                        unit: unit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < _figuresWrapBelow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: figures[0]),
                              Expanded(child: figures[1]),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(child: figures[2]),
                              Expanded(child: figures[3]),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (final figure in figures) Expanded(child: figure),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.muted = false,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool muted;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The commande's total, set apart under its lines.
class OrderPanelGrandTotal extends StatelessWidget {
  const OrderPanelGrandTotal({required this.order, super.key});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.primary600.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdAll,
            ),
            child: const Icon(
              LucideIcons.package,
              size: AppSizing.iconMd,
              color: AppColors.primary700,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.orderPanelGrandTotal,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  Formatters.price(orderTotal(order)),
                  style: AppTypography.numericHero.copyWith(
                    color: AppColors.primary800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            l10n.orderPanelItems(order.lines.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// What happened to the commande, oldest first, as a vertical timeline.
/// The steps still to come are not drawn; the status says what is next.
class OrderPanelHistory extends StatelessWidget {
  const OrderPanelHistory({
    required this.order,
    required this.receiptDates,
    super.key,
  });

  final PurchaseOrder order;
  final List<DateTime> receiptDates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final events = <(String, DateTime, IconData)>[
      (l10n.orderTimelineCreated, order.createdAt, LucideIcons.filePlus),
      if (order.sentAt != null)
        (l10n.orderTimelineSent, order.sentAt!, LucideIcons.send),
      for (final (i, at) in receiptDates.indexed)
        (l10n.orderTimelineReceipt(i + 1), at, LucideIcons.packageCheck),
      if (order.closedAt != null)
        order.status == PurchaseOrderStatus.cancelled
            ? (l10n.orderTimelineCancelled, order.closedAt!, LucideIcons.ban)
            : (
                l10n.orderTimelineDone,
                order.closedAt!,
                LucideIcons.circleCheck,
              ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (label, at, icon)) in events.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == events.length - 1
                                ? AppColors.primaryContainer
                                : AppColors.neutral50,
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Icon(
                            icon,
                            size: 16,
                            color: i == events.length - 1
                                ? AppColors.primary700
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (i < events.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xxs,
                              ),
                              color: AppColors.hairline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 5,
                        bottom: i < events.length - 1 ? AppSpacing.lg : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            Formatters.dateTime(at),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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

/// The panel's bottom bar, pinned under the scrolling body: read the PDF, and
/// either receive the delivery or download the PDF.
///
/// Receiving is a form, and a form in a 560dp panel is cramped — so it leaves
/// for the page; `DrawerScope` closes the panel first.
class OrderPanelFooter extends StatelessWidget {
  const OrderPanelFooter({
    required this.order,
    required this.onReceive,
    super.key,
  });

  final PurchaseOrder order;

  /// Null when the commande cannot be received, which puts the download in
  /// the primary slot.
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OrderDocumentButton.footer(order: order, preview: true),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: onReceive == null
                ? OrderDocumentButton.footer(order: order, prominent: true)
                : PrimaryButton(
                    label: l10n.shortReceive,
                    icon: LucideIcons.packageCheck,
                    fullWidth: true,
                    onPressed: onReceive,
                  ),
          ),
        ],
      ),
    );
  }
}

/// A one-line notice under the summary — the shortfall recorded on a closed
/// commande.
class OrderPanelShortfall extends StatelessWidget {
  const OrderPanelShortfall({required this.shortfall, super.key});

  final double shortfall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.lowStock.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.packageX,
            size: AppSizing.iconSm,
            color: AppColors.lowStock.foreground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.orderShortfallNotice(Formatters.quantity(shortfall)),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.lowStock.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
