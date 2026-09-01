import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'supplier_detail_page.dart';

/// The supplier list.
///
/// A master–detail split on a wide tablet, matching the inventory list. On a
/// landscape tablet a single column of cards leaves half the screen empty, and
/// comparing two suppliers means navigating back and forth.
///
/// Below the split breakpoint, tapping a card pushes the detail as its own
/// page.
class SuppliersListPage extends ConsumerStatefulWidget {
  const SuppliersListPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<SuppliersListPage> createState() => _SuppliersListPageState();
}

class _SuppliersListPageState extends ConsumerState<SuppliersListPage> {
  String _query = '';
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSplit = context.canSplitView;

    // Suppliers are creatable and deletable, and each row counts the articles
    // it supplies — all in the one query, so a link made on another screen
    // moves the number here without anything telling it to.
    final rows = ref.watch(supplierRowsProvider(widget.storeId));

    return ShellPage(
      title: l10n.suppliersTitle,
      subtitle: l10n.suppliersSubtitle,
      scrollable: false,
      actions: [
        PrimaryButton(
          label: l10n.suppliersAdd,
          icon: LucideIcons.plus,
          onPressed: () =>
              context.pushScreen(Routes.toAddSupplier(widget.storeId)),
        ),
      ],
      child: AsyncContent<List<SupplierRowView>>(
        value: rows,
        onRetry: () => ref.invalidate(supplierRowsProvider(widget.storeId)),
        builder: (context, all) {
          final suppliers = _filtered(all);
          final selected = _resolveSelection(suppliers, canSplit);

          if (!canSplit) {
            return _ListPane(
              storeId: widget.storeId,
              suppliers: suppliers,
              allCount: all.length,
              selectedId: null,
              canSplit: false,
              onQueryChanged: (value) => setState(() => _query = value),
              onSelected: (id) =>
                  context.pushScreen(Routes.toSupplier(widget.storeId, id)),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _ListPane(
                  storeId: widget.storeId,
                  suppliers: suppliers,
                  allCount: all.length,
                  selectedId: selected?.supplier.id,
                  canSplit: true,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onSelected: (id) => setState(() => _selectedId = id),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                flex: 5,
                child: selected == null
                    ? AppCard(
                        child: EmptyState(
                          icon: LucideIcons.mousePointerClick,
                          title: l10n.suppliersTitle,
                          message: l10n.suppliersSubtitle,
                        ),
                      )
                    : SupplierDetailPage(
                        key: ValueKey(selected.supplier.id),
                        storeId: widget.storeId,
                        supplierId: selected.supplier.id,
                        embedded: true,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The search box, applied over rows already in hand.
  ///
  /// Three fields, matched as substrings. Kept in Dart for the same reason
  /// `itemMatchesSearch` is: SQLite's `LOWER()` folds ASCII only, so a SQL
  /// version would stop matching accented names.
  List<SupplierRowView> _filtered(List<SupplierRowView> all) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all
        .where(
          (row) =>
              row.supplier.name.toLowerCase().contains(query) ||
              row.supplier.city.toLowerCase().contains(query) ||
              row.supplier.contactName.toLowerCase().contains(query),
        )
        .toList();
  }

  /// Keeps the detail pane populated rather than blank — a split view whose
  /// right half is empty on load looks broken.
  SupplierRowView? _resolveSelection(
    List<SupplierRowView> suppliers,
    bool canSplit,
  ) {
    if (!canSplit || suppliers.isEmpty) return null;
    for (final row in suppliers) {
      if (row.supplier.id == _selectedId) return row;
    }
    return suppliers.first;
  }
}

class _ListPane extends StatelessWidget {
  const _ListPane({
    required this.storeId,
    required this.suppliers,
    required this.allCount,
    required this.selectedId,
    required this.canSplit,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final String storeId;
  final List<SupplierRowView> suppliers;
  final int allCount;
  final String? selectedId;
  final bool canSplit;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchField(hint: l10n.suppliersSearchHint, onChanged: onQueryChanged),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.suppliersProductCount(suppliers.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: suppliers.isEmpty
              ? (allCount == 0
                    ? EmptyState(
                        icon: LucideIcons.truck,
                        title: l10n.suppliersEmpty,
                        message: l10n.suppliersEmptyBody,
                        actionLabel: l10n.suppliersAdd,
                        actionIcon: LucideIcons.plus,
                        onAction: () =>
                            context.pushScreen(Routes.toAddSupplier(storeId)),
                      )
                    : EmptyState.noResults(l10n))
              : ListView.separated(
                  itemCount: suppliers.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final row = suppliers[index];
                    return _SupplierRow(
                      view: row,
                      selected: canSplit && row.supplier.id == selectedId,
                      onTap: () => onSelected(row.supplier.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SupplierRow extends StatelessWidget {
  const _SupplierRow({
    required this.view,
    required this.selected,
    required this.onTap,
  });

  final SupplierRowView view;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final supplier = view.supplier;
    final productCount = view.productCount;
    // The pill shows a bare count; the tooltip says what it counts, so the
    // number is scannable without being cryptic.

    return AppCard(
      onTap: onTap,
      selected: selected,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.truck,
              size: AppSizing.iconMd,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${supplier.contactName} · ${supplier.city}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppRadius.pillAll,
            ),
            child: Tooltip(
              message: l10n.suppliersProductCount(productCount),
              child: Text(
                '$productCount',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            LucideIcons.chevronRight,
            size: AppSizing.iconMd,
            color: AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}
