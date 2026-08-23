import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/store_card.dart';

/// The store grid, shown after login.
///
/// Outside the shell: there is no store context yet, so there is nothing for a
/// navigation rail to navigate within.
class StoreSelectorPage extends StatelessWidget {
  const StoreSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.storesTitle,
                              style: theme.textTheme.displaySmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.storesSubtitle,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      PrimaryButton(
                        label: l10n.storesAdd,
                        icon: LucideIcons.plus,
                        onPressed: () => context.go(Routes.addStore),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: context.gridColumns(max: 3),
                      crossAxisSpacing: AppSpacing.xl,
                      mainAxisSpacing: AppSpacing.xl,
                      // Tall enough for the address to wrap without the
                      // card clipping.
                      mainAxisExtent: 320,
                    ),
                    itemCount: mockStores.length,
                    itemBuilder: (context, index) {
                      final store = mockStores[index];
                      return StoreCard(
                        store: store,
                        onTap: () => context.go(Routes.toDashboard(store.id)),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.go(Routes.login),
                      icon: const Icon(LucideIcons.logOut),
                      label: Text(l10n.actionLogout),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
