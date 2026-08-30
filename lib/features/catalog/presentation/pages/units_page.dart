import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/create_sheets.dart';
import 'categories_page.dart';

/// Manage the store's units of measure.
///
/// Deliberately the same shape as the categories screen — they do the same job
/// and a user who has learned one has learned both.
///
/// The unit list is where the case for user-created units is clearest: a
/// Belgian kitchen counts beer in `bac` and produce in `caisse`, and no
/// hardcoded list ships with those.
///
/// As with categories, deleting a unit that is still in use is refused rather
/// than warned about — and the abbreviation is checked for collisions as well
/// as the name, because the abbreviation is what appears beside every quantity
/// in the app.
class UnitsPage extends ConsumerWidget {
  const UnitsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same as categories: the usage count per unit comes from the same query
    // as the unit, so it cannot lag behind it.
    final rows = ref.watch(unitRowsProvider(storeId));

    final l10n = AppLocalizations.of(context);

    return ShellPage(
      tabs: SectionTabs(
        currentPath: Routes.toUnits(storeId),
        tabs: [
          SectionTab(
            label: l10n.catalogTabCategories,
            path: Routes.toCategories(storeId),
          ),
          SectionTab(
            label: l10n.catalogTabUnits,
            path: Routes.toUnits(storeId),
          ),
        ],
      ),
      title: l10n.unitsTitle,
      subtitle: l10n.unitsSubtitle,
      actions: [
        PrimaryButton(
          label: l10n.unitsAdd,
          icon: LucideIcons.plus,
          onPressed: () => _create(context),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: AsyncListContent<UnitRowView>(
          value: rows,
          onRetry: () => ref.invalidate(unitRowsProvider(storeId)),
          skeleton: const SkeletonList(rows: 5, rowHeight: 64),
          empty: AppCard(
            child: EmptyState(
              icon: LucideIcons.scale,
              title: l10n.unitsEmpty,
              message: l10n.unitsEmptyBody,
              actionLabel: l10n.unitsAdd,
              actionIcon: LucideIcons.plus,
              onAction: () => _create(context),
            ),
          ),
          builder: (context, rows) => AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final row in rows)
                  CatalogTile(
                    icon: LucideIcons.scale,
                    title: row.unit.name,
                    subtitle: l10n.categoriesItemCount(row.itemCount),
                    trailingLabel: row.unit.abbreviation,
                    onEdit: () => _edit(context, row.unit),
                    onDelete: () => _delete(context, ref, row),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final created = await CreateSheets.unit(context, storeId: storeId);
    if (created == null || !context.mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).unitCreated);
  }

  Future<void> _edit(BuildContext context, UnitOfMeasure unit) async {
    final updated = await CreateSheets.unit(
      context,
      storeId: storeId,
      existing: unit,
    );
    if (updated == null || !context.mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).unitUpdated);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    UnitRowView row,
  ) async {
    final l10n = AppLocalizations.of(context);
    final unit = row.unit;

    if (row.itemCount > 0) {
      await ConfirmDialog.blocked(
        context,
        title: l10n.unitDeleteBlockedTitle(unit.name),
        message: l10n.unitDeleteBlockedBody(row.itemCount),
      );
      return;
    }

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: unit.name,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(catalogRepositoryProvider).deleteUnit(unit.id);

    if (!context.mounted) return;
    AppSnackBar.success(context, l10n.unitDeleted);
  }
}
