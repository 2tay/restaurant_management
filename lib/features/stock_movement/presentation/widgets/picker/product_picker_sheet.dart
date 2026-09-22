import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../core/utils/stock_status.dart';
import '../../../../../data/providers.dart';
import '../../../../../data/repositories/repositories.dart';
import '../../../../../data/view_models/view_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/widgets.dart';

/// Pick several products at once, by their picture.
///
/// Replaces a dropdown of names on the three movement forms. A cook finds
/// "the red tin" faster than they read "Tomates pelées 2,5 kg" in a list of
/// sixty, and a delivery of eight products used to mean opening that list
/// eight times. Here it is one sheet: tap the cards, confirm, and each one
/// becomes its own line on the form.
///
/// Products already on the form show as picked and cannot be picked again,
/// so a line can never be doubled by accident.
///
/// A bottom sheet on a phone, where the thumb is; a dialog on anything wider,
/// where a sheet stretched across a desktop window would be all margin.
abstract final class ProductPickerSheet {
  /// The products newly picked, in the order they were tapped, or null when
  /// the picker was dismissed.
  static Future<List<ItemRowView>?> show(
    BuildContext context, {
    required String storeId,
    Set<String> alreadyPicked = const {},
    List<String> featured = const [],
    String? featuredTitle,
    Set<String>? onlyItemIds,
  }) {
    final body = _ProductPicker(
      storeId: storeId,
      alreadyPicked: alreadyPicked,
      featured: featured,
      featuredTitle: featuredTitle,
      onlyItemIds: onlyItemIds,
    );

    if (context.isPhone) {
      return showModalBottomSheet<List<ItemRowView>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        builder: (context) =>
            FractionallySizedBox(heightFactor: 0.92, child: body),
      );
    }

    return showDialog<List<ItemRowView>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
          child: body,
        ),
      ),
    );
  }
}

class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker({
    required this.storeId,
    required this.alreadyPicked,
    required this.featured,
    required this.featuredTitle,
    this.onlyItemIds,
  });

  final String storeId;
  final Set<String> alreadyPicked;

  /// Limits the grid to these products — a supplier's, on an order.
  final Set<String>? onlyItemIds;

  /// Products worth putting first — the ones running low on a delivery, the
  /// ones used lately on a stock-out — shown in their own section under
  /// [featuredTitle] until the user searches or picks a category.
  final List<String> featured;
  final String? featuredTitle;

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  /// Picked in this session, in tap order — the order the lines appear in.
  final List<String> _picked = [];

  String _query = '';
  String? _category;

  void _toggle(String itemId) {
    setState(() {
      if (!_picked.remove(itemId)) _picked.add(itemId);
    });
  }

  Widget _card(ItemRowView row) {
    final id = row.item.id;
    final locked = widget.alreadyPicked.contains(id);
    return PickerProductCard(
      view: row,
      selected: locked || _picked.contains(id),
      locked: locked,
      onTap: locked ? null : () => _toggle(id),
    );
  }

  SliverGrid _sliverGrid(BuildContext context, List<ItemRowView> rows) =>
      SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          mainAxisExtent: PickerProductCard.heightFor(context),
        ),
        itemCount: rows.length,
        itemBuilder: (context, index) => _card(rows[index]),
      );

  Widget _header(BuildContext context, String title, IconData icon) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppSizing.iconSm,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );

  /// The grid — split in two, featured first, while nothing narrows it.
  Widget _grid(
    BuildContext context,
    List<ItemRowView> visible,
    Map<String, ItemRowView> byId,
  ) {
    final l10n = AppLocalizations.of(context);
    final browsing = _query.trim().isEmpty && _category == null;
    final featured = browsing && widget.featuredTitle != null
        ? [
            for (final id in widget.featured)
              if (byId[id] != null) byId[id]!,
          ]
        : const <ItemRowView>[];
    final featuredIds = {for (final row in featured) row.item.id};
    final rest = [
      for (final row in visible)
        if (!featuredIds.contains(row.item.id)) row,
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (featured.isNotEmpty) ...[
                _header(context, widget.featuredTitle!, LucideIcons.sparkles),
                _sliverGrid(context, featured),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg),
                ),
                _header(context, l10n.pickerSectionAll, LucideIcons.layoutGrid),
              ],
              _sliverGrid(context, rest),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final only = widget.onlyItemIds;
    final rows = [
      for (final row
          in ref
                  .watch(
                    itemRowsProvider((
                      storeId: widget.storeId,
                      filter: ItemFilter.none,
                    )),
                  )
                  .value ??
              const <ItemRowView>[])
        if (only == null || only.contains(row.item.id)) row,
    ];

    final categories = {for (final row in rows) row.categoryName}.toList()
      ..sort();

    final query = _query.trim().toLowerCase();
    final visible = [
      for (final row in rows)
        if ((_category == null || row.categoryName == _category) &&
            (query.isEmpty || row.item.name.toLowerCase().contains(query)))
          row,
    ];

    final byId = {for (final row in rows) row.item.id: row};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.pickerTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: SearchField(
            hint: l10n.pickerSearchHint,
            maxWidth: double.infinity,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        if (categories.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                for (final (i, category) in [null, ...categories].indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(
                    label: Text(category ?? l10n.pickerAllCategories),
                    selected: _category == category,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),

        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      l10n.pickerNoResults,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : _grid(context, visible, byId),
        ),

        // The confirm button says how many, so the count is never a
        // surprise when the form fills in behind the sheet.
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PrimaryButton(
                label: l10n.pickerConfirm(_picked.length),
                icon: LucideIcons.plus,
                fullWidth: true,
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop([
                        for (final id in _picked)
                          if (byId[id] != null) byId[id]!,
                      ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One product in the picker: picture, name, what is on the shelf.
///
/// Smaller than the catalogue's `ItemCard` — this grid is for recognising, not
/// for reading — and with a tick in the corner once picked.
class PickerProductCard extends StatelessWidget {
  const PickerProductCard({
    required this.view,
    required this.selected,
    required this.onTap,
    this.locked = false,
    super.key,
  });

  final ItemRowView view;
  final bool selected;

  /// Already on the form: shown picked, and not tappable.
  final bool locked;

  final VoidCallback? onTap;

  static const double _imageHeight = 96;
  static const double _textHeight = 62;

  /// The tile height, grown with the user's type size.
  static double heightFor(BuildContext context) {
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      2.0,
    );
    return _imageHeight + _textHeight * scale + AppCard.verticalBorderAllowance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = view.item;

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: AppCard(
        onTap: onTap,
        selected: selected,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(
                    imagePath: item.imagePath,
                    size: double.infinity,
                    radius: 0,
                    placeholder: ProductImagePlaceholder.disc,
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: StockStatusBadge(
                      status: stockStatusOf(item),
                      compact: true,
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.primary600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          size: AppSizing.iconSm,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.quantityWithUnit(
                        item.quantity,
                        view.unitAbbreviation,
                      ),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
