import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
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
class UnitsPage extends StatelessWidget {
  const UnitsPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final units = MockQueries.unitsForStore(storeId);

    return ShellPage(
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
        child: units.isEmpty
            ? AppCard(
                child: EmptyState(
                  icon: LucideIcons.scale,
                  title: l10n.unitsEmpty,
                  message: l10n.unitsEmptyBody,
                  actionLabel: l10n.unitsAdd,
                  actionIcon: LucideIcons.plus,
                  onAction: () => _create(context),
                ),
              )
            : AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final unit in units)
                      CatalogTile(
                        icon: LucideIcons.scale,
                        title: unit.name,
                        subtitle: l10n.categoriesItemCount(
                          MockQueries.itemCountUsingUnit(unit.id),
                        ),
                        trailingLabel: unit.abbreviation,
                        onEdit: () => _edit(context),
                        onDelete: () => _delete(
                          context,
                          name: unit.name,
                          usageCount: MockQueries.itemCountUsingUnit(unit.id),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final name = await CreateSheets.unit(context);
    if (name == null || !context.mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).unitCreated);
  }

  Future<void> _edit(BuildContext context) async {
    final name = await CreateSheets.unit(context);
    if (name == null || !context.mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).unitUpdated);
  }

  Future<void> _delete(
    BuildContext context, {
    required String name,
    required int usageCount,
  }) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: name,
      extraWarning: usageCount > 0 ? l10n.unitsInUseWarning(usageCount) : null,
    );

    if (confirmed && context.mounted) {
      AppSnackBar.success(context, l10n.unitDeleted);
    }
  }
}
