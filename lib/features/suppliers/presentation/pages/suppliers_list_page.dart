import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// The supplier list.
class SuppliersListPage extends StatefulWidget {
  const SuppliersListPage({required this.storeId, super.key});

  final String storeId;

  @override
  State<SuppliersListPage> createState() => _SuppliersListPageState();
}

class _SuppliersListPageState extends State<SuppliersListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = MockQueries.suppliersForStore(widget.storeId);

    final query = _query.trim().toLowerCase();
    final suppliers = query.isEmpty
        ? all
        : all
              .where(
                (supplier) =>
                    supplier.name.toLowerCase().contains(query) ||
                    supplier.city.toLowerCase().contains(query) ||
                    supplier.contactName.toLowerCase().contains(query),
              )
              .toList();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SearchField(
              hint: l10n.suppliersSearchHint,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: suppliers.isEmpty
                ? (all.isEmpty
                      ? EmptyState(
                          icon: LucideIcons.truck,
                          title: l10n.suppliersEmpty,
                          message: l10n.suppliersEmptyBody,
                          actionLabel: l10n.suppliersAdd,
                          actionIcon: LucideIcons.plus,
                          onAction: () => context.pushScreen(
                            Routes.toAddSupplier(widget.storeId),
                          ),
                        )
                      : EmptyState.noResults(l10n))
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: context.gridColumns(max: 3),
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                      mainAxisExtent: 220,
                    ),
                    itemCount: suppliers.length,
                    itemBuilder: (context, index) => _SupplierCard(
                      supplier: suppliers[index],
                      storeId: widget.storeId,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier, required this.storeId});

  final Supplier supplier;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final productCount = MockQueries.itemCountForSupplier(supplier.id);

    return AppCard(
      onTap: () => context.pushScreen(Routes.toSupplier(storeId, supplier.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Text(
                  supplier.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Line(icon: LucideIcons.user, text: supplier.contactName),
          const SizedBox(height: AppSpacing.xs),
          _Line(icon: LucideIcons.phone, text: supplier.phone),
          const SizedBox(height: AppSpacing.xs),
          _Line(
            icon: LucideIcons.mapPin,
            text: '${supplier.postalCode} ${supplier.city}',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppRadius.pillAll,
            ),
            child: Text(
              l10n.suppliersProductCount(productCount),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppSizing.iconSm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
