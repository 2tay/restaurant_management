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
import 'order_status_badge.dart';
import 'order_visuals.dart';

/// The pieces of a commande shown as a panel: a header that names it, a hero
/// card, tabs, the lines and a footer for the PDF.
///
/// Laid out by `OrderDetailBody`; kept apart from it so the page's layout and
/// the panel's can each be read on their own.
///
/// **Read at a glance.** A panel is opened to check something on the way to
/// something else, so it says with figures, colours and icons what the page
/// says in sentences. The long explanations live in tooltips.

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
      children: [
        if (panel.canGoBack) ...[
          IconButton(
            onPressed: panel.back,
            tooltip: l10n.actionBack,
            icon: const Icon(LucideIcons.arrowLeft, size: AppSizing.iconMd),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        SupplierMonogram(name: supplierName, size: 44),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                supplierName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Flexible(
                    child: PanelReferenceCopy(reference: order.reference),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OrderStatusBadge(status: order.status),
                ],
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

/// The reference in tabular figures; tapping it copies it.
class PanelReferenceCopy extends StatelessWidget {
  const PanelReferenceCopy({required this.reference, super.key});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Tooltip(
      message: l10n.orderPanelCopyReference,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: reference));
          if (context.mounted) {
            AppSnackBar.success(context, l10n.orderPanelReferenceCopied);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  reference,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                LucideIcons.copy,
                size: 12,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one card that answers "how much, how far along, since when": the
/// total, a progress bar for what has arrived, and the commande's journey as
/// three steps — which is the timeline the history tab used to spell out.
class OrderPanelHero extends StatelessWidget {
  const OrderPanelHero({
    required this.order,
    required this.receiptDates,
    super.key,
  });

  final PurchaseOrder order;

  /// When each delivery arrived, oldest first.
  final List<DateTime> receiptDates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    var shortfall = 0.0;
    for (final line in order.lines) {
      shortfall += lineShortfall(line);
    }
    final locked =
        order.status == PurchaseOrderStatus.sent ||
        order.status == PurchaseOrderStatus.partial;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      // A soft tint instead of a frame: the card reads as one block without
      // a border competing with the lines' card under it.
      decoration: const BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.orderTotalLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.price(orderTotal(order)),
                        style: AppTypography.numericHero,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked || shortfall > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.end,
                  children: [
                    if (locked)
                      _InfoChip(
                        icon: LucideIcons.lock,
                        label: l10n.orderPanelLocked,
                        tooltip: l10n.orderLockedNotice,
                      ),
                    if (shortfall > 0)
                      _InfoChip(
                        icon: LucideIcons.packageX,
                        label: l10n.orderPanelShortfall(
                          Formatters.quantity(shortfall),
                        ),
                        colors: AppColors.lowStock,
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Journey(order: order, receiptDates: receiptDates),
        ],
      ),
    );
  }
}

/// Créée → Envoyée → Reçue (or Annulée), each step with its date. A step not
/// reached yet is drawn hollow, so what comes next is visible too.
class _Journey extends StatelessWidget {
  const _Journey({required this.order, required this.receiptDates});

  final PurchaseOrder order;
  final List<DateTime> receiptDates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cancelled = order.status == PurchaseOrderStatus.cancelled;
    final partial = order.status == PurchaseOrderStatus.partial;

    final steps = <_Step>[
      _Step(
        icon: LucideIcons.filePlus,
        label: l10n.orderTimelineCreated,
        at: order.createdAt,
        state: _StepState.done,
      ),
      _Step(
        icon: LucideIcons.send,
        label: l10n.orderTimelineSent,
        at: order.sentAt,
        state: order.sentAt != null ? _StepState.done : _StepState.todo,
      ),
      if (cancelled)
        _Step(
          icon: LucideIcons.ban,
          label: l10n.orderTimelineCancelled,
          at: order.closedAt,
          state: _StepState.cancelled,
        )
      else
        _Step(
          icon: partial ? LucideIcons.clock : LucideIcons.packageCheck,
          label: partial ? l10n.orderStatusPartial : l10n.orderStatusReceived,
          at: order.status == PurchaseOrderStatus.received
              ? order.closedAt
              : (receiptDates.isEmpty ? null : receiptDates.last),
          state: switch (order.status) {
            PurchaseOrderStatus.received => _StepState.done,
            PurchaseOrderStatus.partial => _StepState.current,
            _ => _StepState.todo,
          },
        ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in steps.indexed) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Container(
                  height: 2,
                  color: step.state == _StepState.todo
                      ? AppColors.hairline
                      : AppColors.primary600.withValues(alpha: 0.5),
                ),
              ),
            ),
          _StepDot(step: step),
        ],
      ],
    );
  }
}

enum _StepState { done, current, todo, cancelled }

@immutable
class _Step {
  const _Step({
    required this.icon,
    required this.label,
    required this.at,
    required this.state,
  });

  final IconData icon;
  final String label;
  final DateTime? at;
  final _StepState state;
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color fill, Color fg, Color border) = switch (step.state) {
      _StepState.done => (
        AppColors.primary600,
        AppColors.white,
        AppColors.primary600,
      ),
      _StepState.current => (
        AppColors.primaryContainer,
        AppColors.primary700,
        AppColors.primary600,
      ),
      _StepState.cancelled => (
        AppColors.outOfStock.container,
        AppColors.outOfStock.foreground,
        AppColors.outOfStock.container,
      ),
      _StepState.todo => (
        AppColors.surface,
        AppColors.textDisabled,
        AppColors.hairline,
      ),
    };

    return SizedBox(
      width: 76,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: border, width: 1.5),
            ),
            child: Icon(step.icon, size: 14, color: fg),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            step.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: step.state == _StepState.todo
                  ? AppColors.textDisabled
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            step.at == null ? '—' : Formatters.date(step.at!),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A small tinted chip — a fact in two words, its explanation in a tooltip.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.tooltip,
    this.colors,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final StockStatusColors? colors;

  @override
  Widget build(BuildContext context) {
    final fg = colors?.foreground ?? AppColors.steel800;
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: colors?.container ?? AppColors.offlineContainer,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
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
/// Scrolls sideways rather than wrapping when a phone cannot fit the French
/// labels — a bar broken over two lines reads as two bars.
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

/// A panel body that uses the whole height it is given.
///
/// With room, [top] stays put and [fill] stretches down to the footer and
/// scrolls inside itself — so a short list never leaves a blank strip under
/// it, and a long one keeps the summary in view. Without room (a phone in
/// landscape) everything scrolls together, [fill] drawn at its natural size.
class PanelFillLayout extends StatelessWidget {
  const PanelFillLayout({required this.top, required this.fill, super.key});

  final Widget top;

  /// Built with `pinned: true` when it is given the remaining height and must
  /// scroll itself, `false` when it is laid out at its natural size.
  final Widget Function(bool pinned) fill;

  /// Below this height the summary would squeeze the list to a sliver.
  static const double _pinsFrom = 540;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight >= _pinsFrom) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              top,
              Expanded(child: fill(true)),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [top, fill(false)],
          ),
        );
      },
    );
  }
}

/// A bordered card holding a list of rows and, pinned along its bottom, a
/// strip of totals. Pinned, the rows scroll inside it and the card reaches
/// the bottom of the panel; unpinned, it is as tall as its rows.
class PanelListCard extends StatelessWidget {
  const PanelListCard({
    required this.pinned,
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
    super.key,
  });

  final bool pinned;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final strip = footer == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.neutral50,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: footer,
          );

    Widget separated(int i) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (i > 0) const Divider(height: 1, color: AppColors.hairline),
        itemBuilder(context, i),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: pinned ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pinned)
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: itemCount,
                itemBuilder: (context, i) => separated(i),
              ),
            )
          else
            for (var i = 0; i < itemCount; i++) separated(i),
          ?strip,
        ],
      ),
    );
  }
}

/// The ordered lines, one row each with the product's photo, and the total
/// along the bottom of the card.
class OrderPanelLines extends StatelessWidget {
  const OrderPanelLines({
    required this.order,
    required this.lines,
    required this.showProgress,
    required this.pinned,
    super.key,
  });

  final PurchaseOrder order;
  final List<OrderLineView> lines;

  /// False on a draft or a cancelled commande, where nothing is expected to
  /// arrive and a bar stuck at zero would only be noise.
  final bool showProgress;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settled = order.lines.where(lineIsSettled).length;

    return PanelListCard(
      pinned: pinned,
      itemCount: lines.length,
      itemBuilder: (context, i) =>
          _LineRow(view: lines[i], showProgress: showProgress),
      footer: Row(
        children: [
          Icon(
            showProgress ? LucideIcons.packageCheck : LucideIcons.package,
            size: AppSizing.iconSm,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              showProgress
                  ? '$settled / ${order.lines.length}'
                  : l10n.orderPanelItems(order.lines.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            Formatters.price(orderTotal(order)),
            style: AppTypography.numeric.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primary800,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line: the product's photo, its name with "received / ordered" and a
/// slim bar, then the money. Its colour says where it stands — teal while
/// owed, green once in, amber when closed short.
///
/// With room (a tablet, a desktop panel) the quantity and the unit price get
/// columns of their own; on a phone they fold under the name and the total.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.view, required this.showProgress});

  final OrderLineView view;
  final bool showProgress;

  /// From this width the figures sit in columns.
  static const double _columnsFrom = 500;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final line = view.line;
    final unit = view.unitAbbreviation;
    final ordered = line.quantityOrdered;
    final share = ordered <= 0
        ? 0.0
        : (line.quantityReceived / ordered).clamp(0.0, 1.0);
    final complete = lineOutstanding(line) <= 0 && !line.closedShort;

    final (Color color, IconData? icon, String? tip) = line.closedShort
        ? (
            AppColors.lowStock.solid,
            LucideIcons.packageX,
            l10n.orderLineClosedShort,
          )
        : complete
        ? (
            AppColors.inStock.solid,
            LucideIcons.circleCheck,
            l10n.orderStatusReceived,
          )
        : (AppColors.primary600, null, null);

    final figure = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final quantity = Text(
      showProgress
          ? '${Formatters.quantity(line.quantityReceived)} / '
                '${Formatters.quantityWithUnit(ordered, unit)}'
          : Formatters.quantityWithUnit(ordered, unit),
      style: figure,
      maxLines: 1,
    );
    final bar = ClipRRect(
      borderRadius: AppRadius.pillAll,
      child: LinearProgressIndicator(
        value: share,
        minHeight: 4,
        color: color,
        backgroundColor: AppColors.neutral100,
      ),
    );
    final name = Row(
      children: [
        Flexible(
          child: Text(
            view.itemName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showProgress && icon != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Tooltip(
            message: tip,
            child: Icon(icon, size: 14, color: color),
          ),
        ],
      ],
    );
    final total = Text(
      Formatters.price(lineTotal(line)),
      style: AppTypography.numeric.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 1,
    );
    final unitPrice = Text(
      '× ${Formatters.price(line.unitPrice)}',
      style: theme.textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      maxLines: 1,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _columnsFrom;
        final photo = ProductImage(
          imagePath: view.imagePath,
          size: wide ? 52 : 44,
          radius: 10,
          placeholder: ProductImagePlaceholder.disc,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              photo,
              const SizedBox(width: AppSpacing.md),
              if (wide) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      if (showProgress) ...[
                        const SizedBox(height: AppSpacing.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: bar,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 104,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: quantity,
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: unitPrice,
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: Align(alignment: Alignment.centerRight, child: total),
                ),
              ] else ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          quantity,
                          if (showProgress) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                child: bar,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    total,
                    const SizedBox(height: AppSpacing.xxs),
                    unitPrice,
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A note left on the commande or the réception: an icon and the words, no
/// heading.
class PanelNote extends StatelessWidget {
  const PanelNote({required this.note, super.key});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.stickyNote,
            size: AppSizing.iconSm,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(note, style: Theme.of(context).textTheme.bodyMedium),
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
