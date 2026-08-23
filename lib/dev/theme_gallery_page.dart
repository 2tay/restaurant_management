import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/models.dart';
import '../shared/widgets/widgets.dart';

/// A development-only reference page rendering every design-system primitive
/// side by side.
///
/// It exists so contrast, hue separation and type sizing get judged **once**,
/// here, before forty screens bake the mistakes in. It is not part of the
/// product: nothing in `features/` may import from `lib/dev/`, and this folder
/// is removed at handoff (Stage 7).
///
/// Strings are hardcoded French on purpose — this page never ships, so routing
/// them through `AppLocalizations` would only add noise to the `.arb`. Real
/// French copy rather than lorem, though: the point is to catch text that
/// overflows at realistic length.
class ThemeGalleryPage extends StatelessWidget {
  const ThemeGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design system — référence interne'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: Text(
                'lib/dev — non livré',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pageInsets,
        children: const [
          _StatusTriadSection(),
          _PaletteSection(),
          _TypographySection(),
          _ButtonSection(),
          _InputSection(),
          _SurfaceSection(),
          _FeedbackSection(),
          _ComponentsSection(),
          _NavigationSection(),
          SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// =============================================================================
// Status triad — first, because it is the most important thing on this page.
// =============================================================================

class _StatusTriadSection extends StatelessWidget {
  const _StatusTriadSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      title: 'Statuts de stock',
      note:
          'Le composant réel StockStatusBadge. Jamais la couleur seule : '
          'chaque statut porte une icône et un libellé.',
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StockStatusBadge(status: StockStatus.inStock),
          StockStatusBadge(status: StockStatus.lowStock),
          StockStatusBadge(status: StockStatus.outOfStock),
          SizedBox(width: AppSpacing.xl),
          StockStatusBadge(status: StockStatus.inStock, compact: true),
          StockStatusBadge(status: StockStatus.lowStock, compact: true),
          StockStatusBadge(status: StockStatus.outOfStock, compact: true),
        ],
      ),
    );
  }
}

// =============================================================================
// Palette
// =============================================================================

class _PaletteSection extends StatelessWidget {
  const _PaletteSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      title: 'Palette',
      note:
          "L'action principale (sarcelle) et le statut « en stock » (vert) "
          'sont volontairement de teintes différentes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SwatchRow(
            label: 'Action — sarcelle',
            swatches: [
              _Swatch('primary700', AppColors.primary700),
              _Swatch('primary600', AppColors.primary600, isKey: true),
              _Swatch('primary500', AppColors.primary500),
              _Swatch('container', AppColors.primaryContainer, isDark: false),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _SwatchRow(
            label: 'Chrome — acier',
            swatches: [
              _Swatch('steel800', AppColors.steel800),
              _Swatch('steel700', AppColors.steel700),
              _Swatch('steel600', AppColors.steel600),
              _Swatch('steel500', AppColors.steel500),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _SwatchRow(
            label: 'Neutres — ardoise',
            swatches: [
              _Swatch('950', AppColors.neutral950),
              _Swatch('800', AppColors.neutral800),
              _Swatch('600', AppColors.neutral600),
              _Swatch('400', AppColors.neutral400, isDark: false),
              _Swatch('200', AppColors.neutral200, isDark: false),
              _Swatch('50', AppColors.neutral50, isDark: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({required this.label, required this.swatches});

  final String label;
  final List<_Swatch> swatches;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: swatches,
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(
    this.name,
    this.color, {
    this.isDark = true,
    this.isKey = false,
  });

  final String name;
  final Color color;

  /// Whether the swatch needs light text to stay legible.
  final bool isDark;

  /// Marks the canonical step of a ramp.
  final bool isKey;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.white : AppColors.textPrimary;
    return Container(
      width: 128,
      height: 76,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: isKey ? AppColors.neutral900 : AppColors.border,
          width: isKey ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: textColor),
          ),
          Text(
            '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Typography
// =============================================================================

class _TypographySection extends StatelessWidget {
  const _TypographySection();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _Section(
      title: 'Typographie',
      note:
          'Police Inter (repli automatique tant que les .ttf ne sont pas '
          'dans fonts/). Rien en dessous de 13pt.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeRow(
            'displaySmall / 36',
            'Sélectionnez un établissement',
            t.displaySmall,
          ),
          _TypeRow('headlineLarge / 32', 'Inventaire', t.headlineLarge),
          _TypeRow(
            'headlineMedium / 28',
            'Mouvements de stock',
            t.headlineMedium,
          ),
          _TypeRow(
            'titleLarge / 22',
            'Fournisseurs de cet article',
            t.titleLarge,
          ),
          _TypeRow('titleMedium / 18', 'Blanc de poulet', t.titleMedium),
          _TypeRow(
            'bodyLarge / 17',
            'Quantité en stock mise à jour hier à 14h32.',
            t.bodyLarge,
          ),
          _TypeRow(
            'bodyMedium / 15',
            'Dernière livraison reçue il y a trois jours.',
            t.bodyMedium,
          ),
          _TypeRow(
            'bodySmall / 13',
            'Modifié par Amélie Vandenberghe',
            t.bodySmall,
          ),
          _TypeRow(
            'labelLarge / 16',
            'ENREGISTRER UNE LIVRAISON',
            t.labelLarge,
          ),
          const Divider(height: AppSpacing.xxl),
          const _TypeRow(
            'numericLarge / 34',
            '1 248,50 €',
            AppTypography.numericLarge,
          ),
          const _TypeRow(
            'numeric / 17',
            '12,50 € · 48 kg · 3 bacs',
            AppTypography.numeric,
          ),
          const _TypeRow(
            'numericSmall / 15',
            '22/08/2026',
            AppTypography.numericSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Les chiffres utilisent des figures tabulaires : les colonnes de '
            'prix restent alignées entre les lignes.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow(this.spec, this.sample, this.style);

  final String spec;
  final String sample;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 180,
            child: Text(spec, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(sample, style: style)),
        ],
      ),
    );
  }
}

// =============================================================================
// Buttons
// =============================================================================

class _ButtonSection extends StatelessWidget {
  const _ButtonSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Boutons',
      note:
          'Hauteur minimale 56dp. Une seule action principale par écran. '
          'Les libellés français sont longs : jamais de largeur fixe.',
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(LucideIcons.truck),
            label: const Text('Enregistrer une livraison'),
          ),
          FilledButton(onPressed: () {}, child: const Text('Enregistrer')),
          const FilledButton(onPressed: null, child: Text('Désactivé')),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(LucideIcons.plus),
            label: const Text('Ajouter un article'),
          ),
          TextButton(onPressed: () {}, child: const Text('Annuler')),
          FilledButton.icon(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            icon: const Icon(LucideIcons.trash2),
            label: const Text('Supprimer'),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.search),
            tooltip: 'Rechercher',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Inputs
// =============================================================================

class _InputSection extends StatelessWidget {
  const _InputSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      title: 'Champs de saisie',
      note: 'Privilégier les sélecteurs et les pas-à-pas à la saisie libre.',
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              decoration: InputDecoration(
                labelText: "Nom de l'article",
                hintText: 'Ex. : Blanc de poulet',
              ),
            ),
          ),
          SizedBox(
            width: 320,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Seuil de stock faible',
                errorText: 'Veuillez saisir un nombre',
              ),
            ),
          ),
          SizedBox(
            width: 320,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Rechercher',
                prefixIcon: Icon(LucideIcons.search),
                hintText: 'Article, fournisseur, catégorie…',
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Surfaces
// =============================================================================

class _SurfaceSection extends StatelessWidget {
  const _SurfaceSection();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _Section(
      title: 'Surfaces',
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          SizedBox(
            width: 300,
            child: Card(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valeur du stock', style: t.labelMedium),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '12 480,75 €',
                      style: AppTypography.numericLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('42 articles · 5 catégories', style: t.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 300,
            child: Card(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filtres', style: t.labelMedium),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        Chip(
                          label: const Text('Fruits & Légumes'),
                          avatar: const Icon(LucideIcons.tags, size: 16),
                          onDeleted: () {},
                        ),
                        const Chip(label: Text('Viandes')),
                        const Chip(label: Text('Boissons')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Feedback
// =============================================================================

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Retours utilisateur',
      note:
          "Chaque action produit une confirmation visible. L'utilisateur ne "
          'doit jamais se demander « est-ce que ça a été enregistré ? »',
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Livraison enregistrée'),
                  action: SnackBarAction(label: 'Annuler', onPressed: () {}),
                ),
              );
            },
            child: const Text('Afficher une confirmation'),
          ),
          OutlinedButton(
            onPressed: () => _showConfirmDialog(context),
            child: const Text('Afficher un dialogue destructif'),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.offlineContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.wifiOff,
                  size: AppSizing.iconMd,
                  color: AppColors.offline,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Mode hors ligne · 3 modifications en attente',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.offline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet article ?'),
        content: const Text(
          '« Blanc de poulet » et son historique de mouvements seront '
          'définitivement supprimés. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Navigation chrome
// =============================================================================

class _NavigationSection extends StatelessWidget {
  const _NavigationSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Navigation',
      note:
          'Largeur du rail vérifiée contre « Mouvements de stock » et '
          '« Catégories et unités » — les libellés les plus longs.',
      child: SizedBox(
        height: 460,
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: NavigationRail(
            extended: true,
            selectedIndex: 1,
            onDestinationSelected: (_) {},
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Icon(
                LucideIcons.store,
                color: AppColors.white,
                size: AppSizing.iconLg,
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(LucideIcons.layoutDashboard),
                label: Text('Tableau de bord'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.boxes),
                label: Text('Inventaire'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.arrowRightLeft),
                label: Text('Mouvements de stock'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.truck),
                label: Text('Fournisseurs'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.tags),
                label: Text('Catégories et unités'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.chartColumn),
                label: Text('Rapports'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.users),
                label: Text('Équipe'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.settings),
                label: Text('Paramètres'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Shared component library
// =============================================================================

class _ComponentsSection extends StatefulWidget {
  const _ComponentsSection();

  @override
  State<_ComponentsSection> createState() => _ComponentsSectionState();
}

class _ComponentsSectionState extends State<_ComponentsSection> {
  double _quantity = 12;
  String? _category = 'cat-viandes';

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Composants partagés',
      note:
          'Les composants réels de shared/widgets, interactifs. '
          'Le pas-à-pas accepte le maintien pour répéter.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QuantityStepper',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          QuantityStepper(
            value: _quantity,
            unitAbbreviation: 'kg',
            onChanged: (value) => setState(() => _quantity = value),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text(
            'AppDropdown — avec « + Créer » intégré',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: 380,
            child: AppDropdown<String>(
              label: 'Catégorie',
              value: _category,
              options: const [
                DropdownOption(value: 'cat-legumes', label: 'Fruits & Légumes'),
                DropdownOption(value: 'cat-viandes', label: 'Viandes'),
                DropdownOption(value: 'cat-boissons', label: 'Boissons'),
              ],
              onChanged: (value) => setState(() => _category = value),
              onCreateNew: () => AppSnackBar.success(
                context,
                'Ouvrirait le formulaire de création',
              ),
              createNewLabel: '+ Créer une catégorie',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text('Boutons', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PrimaryButton(
                label: 'Enregistrer une livraison',
                icon: LucideIcons.truck,
                onPressed: () =>
                    AppSnackBar.success(context, 'Livraison enregistrée'),
              ),
              SecondaryButton(label: 'Annuler', onPressed: () {}),
              DestructiveButton(
                label: 'Supprimer',
                icon: LucideIcons.trash2,
                onPressed: () async {
                  final confirmed = await ConfirmDialog.confirmDelete(
                    context,
                    name: 'Blanc de poulet',
                    extraWarning:
                        "L'historique des mouvements de cet article sera "
                        'également supprimé.',
                  );
                  if (confirmed && context.mounted) {
                    AppSnackBar.success(context, 'Article supprimé');
                  }
                },
              ),
              const PrimaryButton(label: 'Désactivé', onPressed: null),
              const PrimaryButton(
                label: 'En cours',
                onPressed: null,
                isBusy: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          Text('États', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 320,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppCard(
                    child: EmptyState(
                      icon: LucideIcons.packageOpen,
                      title: 'Aucun article pour le moment',
                      message:
                          'Ajoutez votre premier article pour commencer à '
                          'suivre votre stock.',
                      actionLabel: 'Ajouter un article',
                      actionIcon: LucideIcons.plus,
                      onAction: () {},
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Expanded(child: AppCard(child: LoadingState())),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: AppCard(child: ErrorState(onRetry: () {})),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Layout helper
// =============================================================================

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.note});

  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.headlineSmall),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(width: 720, child: Text(note!, style: t.bodySmall)),
          ],
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}
