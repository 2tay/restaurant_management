// Behaviour tests for the shared component library.
//
// Focused on the pieces that carry real logic or a rule from the brief. Purely
// presentational widgets are covered by the route walk, which renders them.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:stock_inventory/app/navigation.dart';
import 'package:stock_inventory/core/theme/app_colors.dart';
import 'package:stock_inventory/core/theme/app_spacing.dart';
import 'package:stock_inventory/core/theme/app_theme.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

/// Wraps a widget in the minimum needed for localized, themed rendering.
Widget _host(Widget child) {
  return MaterialApp(
    locale: const Locale('fr', 'BE'),
    supportedLocales: const [Locale('fr', 'BE')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('StockStatusBadge', () {
    testWidgets('never communicates status by colour alone', (tester) async {
      // The rule from the brief: colour + icon + label, always. This is the
      // difference between usable and unusable for a colour-blind user, and the
      // app's core signal is red/amber/green.
      for (final status in StockStatus.values) {
        await tester.pumpWidget(_host(StockStatusBadge(status: status)));
        await tester.pumpAndSettle();

        expect(find.byType(Icon), findsOneWidget, reason: '$status icon');
        expect(find.byType(Text), findsOneWidget, reason: '$status label');
      }
    });

    testWidgets('shows the right French label per status', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StockStatusBadge(status: StockStatus.inStock),
              StockStatusBadge(status: StockStatus.lowStock),
              StockStatusBadge(status: StockStatus.outOfStock),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('En stock'), findsOneWidget);
      expect(find.text('Stock faible'), findsOneWidget);
      expect(find.text('Rupture de stock'), findsOneWidget);
    });

    testWidgets('each status gets a distinct icon, not just a colour', (
      tester,
    ) async {
      final icons = StockStatus.values.map(StockStatusBadge.iconFor).toSet();

      expect(
        icons.length,
        StockStatus.values.length,
        reason: 'statuses must be distinguishable by shape',
      );
    });

    testWidgets('compact variant keeps the label reachable as a tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const StockStatusBadge(status: StockStatus.lowStock, compact: true),
        ),
      );
      await tester.pumpAndSettle();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Stock faible');
    });
  });

  group('PaymentStatusBadge', () {
    testWidgets('never communicates status by colour alone', (tester) async {
      for (final status in PaymentStatus.values) {
        await tester.pumpWidget(_host(PaymentStatusBadge(status: status)));
        await tester.pumpAndSettle();

        expect(find.byType(Icon), findsOneWidget, reason: '$status icon');
        expect(find.byType(Text), findsOneWidget, reason: '$status label');
      }
    });

    testWidgets('each status gets a distinct icon, not just a colour', (
      tester,
    ) async {
      final icons = PaymentStatus.values
          .map(PaymentStatusBadge.iconFor)
          .toSet();

      expect(
        icons.length,
        PaymentStatus.values.length,
        reason: 'statuses must be distinguishable by shape',
      );
    });

    testWidgets('shows the right French label per status', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PaymentStatusBadge(status: PaymentStatus.paid),
              PaymentStatusBadge(status: PaymentStatus.unpaid),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payé'), findsOneWidget);
      expect(find.text('Non payé'), findsOneWidget);
    });
  });

  group('AttendanceStatusBadge', () {
    testWidgets('en pause is the teal onBreak palette, never amber', (
      tester,
    ) async {
      expect(
        AttendanceStatusBadge.colorsFor(AttendanceStatus.onBreak),
        same(AppColors.onBreak),
      );
      expect(
        AttendanceStatusBadge.colorsFor(AttendanceStatus.onBreak),
        isNot(same(AppColors.lowStock)),
      );
    });
  });

  group('action density', () {
    // A page header cannot reach inside the already-built buttons it is handed,
    // so it publishes how much room it can spare and each button decides what
    // that means for it.

    Widget at(ActionDensity density, Widget button) =>
        _host(ActionDensityScope(density: density, child: button));

    testWidgets('full uses the long label', (tester) async {
      await tester.pumpWidget(
        at(
          ActionDensity.full,
          SecondaryButton(
            label: 'Associer un fournisseur',
            shortLabel: 'Associer',
            icon: LucideIcons.link,
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Associer un fournisseur'), findsOneWidget);
    });

    testWidgets('short swaps in the short label, keeping the icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        at(
          ActionDensity.short,
          SecondaryButton(
            label: 'Associer un fournisseur',
            shortLabel: 'Associer',
            icon: LucideIcons.link,
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Associer'), findsOneWidget);
      expect(find.text('Associer un fournisseur'), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('iconOnly moves the label rather than dropping it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        at(
          ActionDensity.iconOnly,
          SecondaryButton(
            label: 'Associer un fournisseur',
            shortLabel: 'Associer',
            icon: LucideIcons.link,
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Associer'), findsNothing);
      // Still reachable: as a tooltip for the eye, and as a name for a screen
      // reader. A collapsed button must not become an anonymous glyph.
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Associer un fournisseur',
      );
      expect(
        find.bySemanticsLabel('Associer un fournisseur'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('iconOnly still presses', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        at(
          ActionDensity.iconOnly,
          SecondaryButton(
            label: 'Exporter',
            icon: LucideIcons.download,
            onPressed: () => pressed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OutlinedButton));
      expect(pressed, isTrue, reason: 'naming it must not disable it');
    });

    testWidgets('the primary action keeps its words at every density', (
      tester,
    ) async {
      // The teal button answers "what am I supposed to do on this screen?".
      // A header of three anonymous glyphs makes that a guessing game.
      await tester.pumpWidget(
        at(
          ActionDensity.iconOnly,
          PrimaryButton(
            label: 'Ajouter un produit',
            shortLabel: 'Ajouter',
            icon: LucideIcons.plus,
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ajouter'), findsOneWidget);
    });

    testWidgets('a button with no icon falls back to its short label', (
      tester,
    ) async {
      await tester.pumpWidget(
        at(
          ActionDensity.iconOnly,
          SecondaryButton(
            label: 'Tout afficher',
            shortLabel: 'Tout',
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tout'), findsOneWidget);
    });

    testWidgets('a button outside a header is untouched', (tester) async {
      await tester.pumpWidget(
        _host(
          SecondaryButton(
            label: 'Associer un fournisseur',
            shortLabel: 'Associer',
            icon: LucideIcons.link,
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Associer un fournisseur'), findsOneWidget);
    });
  });

  group('StatusPill', () {
    // The primitive the four status badges are now built from. The rules used
    // to be re-stated in each of them; they are enforced once, here.

    testWidgets('carries the icon and the label together', (tester) async {
      await tester.pumpWidget(
        _host(
          const StatusPill(
            colors: AppColors.lowStock,
            icon: LucideIcons.triangleAlert,
            label: 'Stock faible',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Icon), findsOneWidget);
      expect(find.text('Stock faible'), findsOneWidget);
    });

    testWidgets('the icon is not read out as well as the label', (
      tester,
    ) async {
      // Colour is never alone visually, but a screen reader that announced the
      // icon *and* the label would say the status twice.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const StatusPill(
            colors: AppColors.inStock,
            icon: LucideIcons.circleCheck,
            label: 'En stock',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('En stock'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('compact keeps the label reachable as a tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const StatusPill(
            colors: AppColors.outOfStock,
            icon: LucideIcons.circleX,
            label: 'Rupture',
            compact: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'Rupture');
      expect(find.text('Rupture'), findsNothing);
    });

    testWidgets('a long label ellipsizes rather than overflowing its column', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 90,
            child: StatusPill(
              colors: AppColors.lowStock,
              icon: LucideIcons.triangleAlert,
              label: 'Réapprovisionnement urgent requis',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('LabelChip', () {
    testWidgets('names something without needing an icon', (tester) async {
      await tester.pumpWidget(_host(const LabelChip(label: 'Contrat fixe')));
      await tester.pumpAndSettle();

      expect(find.text('Contrat fixe'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('ResponsiveCardGrid', () {
    /// The shell's layout at [screen]: the sidebar (a rail below 1100dp, full
    /// above), then the page padding around the grid.
    Widget shell(double screen, double minCardWidth) {
      final sidebar = screen < AppBreakpoints.sidebarCollapse
          ? AppSizing.sidebarWidthCollapsed
          : AppSizing.sidebarWidthExpanded;
      return _host(
        MediaQuery(
          data: MediaQueryData(size: Size(screen, 900)),
          child: SizedBox(
            width: screen,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: sidebar),
                Expanded(
                  child: Padding(
                    padding: AppSpacing.pageInsets,
                    child: ResponsiveCardGrid(
                      minCardWidth: minCardWidth,
                      children: [
                        for (var i = 0; i < 8; i++) const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    for (final min in [320.0, 300.0, 260.0]) {
      testWidgets('widening from 840 to 1800 (min ${min.toInt()}): columns '
          'only grow, no card under its minimum', (tester) async {
        tester.view.physicalSize = const Size(1800, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        var previous = 0;
        for (var screen = 840.0; screen <= 1800; screen += 10) {
          await tester.pumpWidget(shell(screen, min));
          final wrap = tester.widget<Wrap>(
            find.descendant(
              of: find.byType(ResponsiveCardGrid),
              matching: find.byType(Wrap),
            ),
          );
          final cardWidth = (wrap.children.first as SizedBox).width!;
          final gridWidth = tester.getSize(find.byType(Wrap)).width;
          final columns =
              ((gridWidth + AppSpacing.lg) / (cardWidth + AppSpacing.lg))
                  .round();
          expect(columns, greaterThanOrEqualTo(previous), reason: 'at $screen');
          expect(cardWidth, greaterThanOrEqualTo(min), reason: 'at $screen');
          previous = columns;
        }
      });
    }
  });

  group('StatTileRow', () {
    const tiles = [
      StatTile(label: 'Actifs', value: '12', icon: LucideIcons.users),
      StatTile(label: 'Gérants', value: '3', icon: LucideIcons.shieldCheck),
      StatTile(label: 'Contrats', value: '9 / 3', icon: LucideIcons.briefcase),
    ];

    Widget host(double screenWidth, double rowWidth) => _host(
      MediaQuery(
        data: MediaQueryData(size: Size(screenWidth, 800)),
        child: SizedBox(
          width: rowWidth,
          child: const StatTileRow(tiles: tiles),
        ),
      ),
    );

    testWidgets('two per line on a phone, the odd one full width', (
      tester,
    ) async {
      await tester.pumpWidget(host(390, 358));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final sizes = [
        for (final e in find.byType(StatTile).evaluate())
          tester.getSize(find.byWidget(e.widget)),
      ];
      expect(sizes[0].width, (358 - AppSpacing.lg) / 2);
      expect(sizes[1].width, (358 - AppSpacing.lg) / 2);
      expect(sizes[2].width, 358, reason: 'the lonely last tile stretches');
      expect(
        tester.getTopLeft(find.text('Gérants')).dy,
        tester.getTopLeft(find.text('Actifs')).dy,
        reason: 'the first two share a line',
      );
    });

    testWidgets('a 900dp window less the rail: five tiles go three then two, '
        'no label cut', (tester) async {
      const five = [
        ...tiles,
        StatTile(label: 'Embauchés', value: '5', icon: LucideIcons.userPlus),
        StatTile(label: 'Tarif moyen', value: '12 €', icon: LucideIcons.wallet),
      ];
      await tester.pumpWidget(
        _host(
          const MediaQuery(
            data: MediaQueryData(size: Size(900, 800)),
            child: SizedBox(width: 760, child: StatTileRow(tiles: five)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final rects = [
        for (final e in find.byType(StatTile).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      // Three on the first line, two on the second, each line full width.
      expect(rects[0].top, rects[2].top);
      expect(rects[3].top, greaterThan(rects[0].bottom));
      expect(rects[3].top, rects[4].top);
      expect(rects[0].width, closeTo((760 - 2 * AppSpacing.lg) / 3, 0.01));
      expect(rects[3].width, closeTo((760 - AppSpacing.lg) / 2, 0.01));
      for (final r in rects) {
        expect(r.width, greaterThanOrEqualTo(StatTileRow.minTileWidth));
      }
    });

    testWidgets('a wide content area keeps every tile on one line', (
      tester,
    ) async {
      await tester.pumpWidget(host(1400, 1100));
      await tester.pumpAndSettle();
      final tops = {
        for (final e in find.byType(StatTile).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      };
      expect(tops, hasLength(1));
    });

    testWidgets('keeps every icon, even two per line on a 320dp phone', (
      tester,
    ) async {
      await tester.pumpWidget(host(320, 288));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(LucideIcons.users), findsOneWidget);
      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      expect(find.byIcon(LucideIcons.briefcase), findsOneWidget);
    });

    testWidgets('two per line on a small tablet too', (tester) async {
      await tester.pumpWidget(host(742, 560));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(StatTile).first).width,
        (560 - AppSpacing.lg) / 2,
      );
    });

    testWidgets('a smaller label on a phone only', (tester) async {
      double labelSize() =>
          tester.widget<Text>(find.text('Actifs')).style!.fontSize!;
      await tester.pumpWidget(host(390, 358));
      await tester.pumpAndSettle();
      final phone = labelSize();
      await tester.pumpWidget(host(742, 560));
      await tester.pumpAndSettle();
      expect(phone, 11);
      expect(labelSize(), greaterThan(phone));
    });

    testWidgets('all on one line from a medium screen up', (tester) async {
      await tester.pumpWidget(host(1024, 900));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final tops = {
        for (final e in find.byType(StatTile).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      };
      expect(tops, hasLength(1), reason: 'one line');
    });
  });

  group('AdaptiveRow', () {
    testWidgets('is a row when there is width and a column when there is not', (
      tester,
    ) async {
      Widget host(double width) => _host(
        SizedBox(
          width: width,
          child: const AdaptiveRow(
            breakpoint: 400,
            cells: [
              AdaptiveCell(flex: 1, child: Text('Nom')),
              AdaptiveCell(child: Text('Statut')),
            ],
          ),
        ),
      );

      await tester.pumpWidget(host(600));
      await tester.pumpAndSettle();
      final wide = tester.getTopLeft(find.text('Statut'));

      await tester.pumpWidget(host(320));
      await tester.pumpAndSettle();
      final narrow = tester.getTopLeft(find.text('Statut'));

      expect(narrow.dy, greaterThan(wide.dy), reason: 'stacked below');
      expect(narrow.dx, lessThan(wide.dx), reason: 'and back at the left edge');
    });
  });

  group('QuantityStepper', () {
    testWidgets('+ and - move the value', (tester) async {
      var value = 10.0;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => QuantityStepper(
              value: value,
              unitAbbreviation: 'kg',
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Augmenter'));
      await tester.pumpAndSettle();
      expect(value, 11.0);

      await tester.tap(find.bySemanticsLabel('Diminuer'));
      await tester.pumpAndSettle();
      expect(value, 10.0);
    });

    testWidgets('will not go below its minimum', (tester) async {
      var value = 0.0;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => QuantityStepper(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Disabled at the floor rather than silently clamping, so the control
      // tells the user why nothing happened.
      await tester.tap(find.bySemanticsLabel('Diminuer'));
      await tester.pumpAndSettle();
      expect(value, 0.0);
    });

    testWidgets('accepts a comma decimal separator', (tester) async {
      // Belgian keyboards and Belgian habits both produce "2,5", not "2.5".
      var value = 1.0;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => QuantityStepper(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '2,5');
      await tester.pumpAndSettle();

      expect(value, 2.5);
    });

    testWidgets('steps whole units when decimals are disallowed', (
      tester,
    ) async {
      // Pieces and crates cannot be half.
      var value = 3.0;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => QuantityStepper(
              value: value,
              allowDecimals: false,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Augmenter'));
      await tester.pumpAndSettle();

      expect(value, 4.0, reason: 'should step by 1, not 0.5');
    });
  });

  group('ConfirmDialog', () {
    testWidgets('returns false when cancelled and true when confirmed', (
      tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ConfirmDialog.confirmDelete(
                  context,
                  name: 'Blanc de poulet',
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('names the record being deleted', (tester) async {
      // "Supprimer cet élément ?" is how people delete the wrong record.
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  ConfirmDialog.confirmDelete(context, name: 'Blanc de poulet'),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Blanc de poulet'),
        findsOneWidget,
        reason: 'the dialog must name what it is about to delete',
      );
      expect(find.textContaining('irréversible'), findsOneWidget);
    });
  });

  group('AppDropdown', () {
    testWidgets('offers an inline create row when onCreateNew is given', (
      tester,
    ) async {
      // The brief requires categories and units to be creatable without
      // leaving the form.
      var createTapped = false;

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 400,
            child: AppDropdown<String>(
              label: 'Catégorie',
              value: 'a',
              options: const [
                DropdownOption(value: 'a', label: 'Viandes'),
                DropdownOption(value: 'b', label: 'Boissons'),
              ],
              onChanged: (_) {},
              onCreateNew: () => createTapped = true,
              createNewLabel: '+ Créer une catégorie',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<Object?>));
      await tester.pumpAndSettle();

      expect(find.text('+ Créer une catégorie'), findsOneWidget);

      await tester.tap(find.text('+ Créer une catégorie').last);
      await tester.pumpAndSettle();

      expect(createTapped, isTrue);
    });

    testWidgets('omits the create row when onCreateNew is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 400,
            child: AppDropdown<String>(
              label: 'Fournisseur',
              value: 'a',
              options: const [DropdownOption(value: 'a', label: 'Metro')],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<Object?>));
      await tester.pumpAndSettle();

      expect(find.textContaining('Créer'), findsNothing);
    });
  });

  group('EmptyState', () {
    testWidgets('offers a way out rather than just a blank panel', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        _host(
          EmptyState(
            title: 'Aucun article pour le moment',
            message: 'Ajoutez votre premier article.',
            actionLabel: 'Ajouter un article',
            onAction: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter un article'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('IdentityPromptDialog', () {
    Future<void> open(
      WidgetTester tester,
      Future<bool> Function(String pin) verify,
    ) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => IdentityPromptDialog.show(
                context,
                title: 'Confirmation',
                subtitle: 'Pointer · Karim',
                verify: verify,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester, String pin) async {
      await tester.enterText(find.byType(TextField), pin);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Valider'));
      await tester.pumpAndSettle();
    }

    testWidgets('a wrong PIN keeps the dialog open, ready for another try', (
      tester,
    ) async {
      await open(tester, (_) async => false);
      await submit(tester, '99.99.99-999.99');

      expect(find.byType(IdentityPromptDialog), findsOneWidget);
      expect(find.text('Numéro incorrect. Réessayez.'), findsOneWidget);
      expect(find.textContaining('tentative'), findsNothing);
    });

    testWidgets('attempts are unlimited — Valider never locks', (tester) async {
      var calls = 0;
      await open(tester, (_) async {
        calls++;
        return false;
      });
      for (var i = 0; i < 10; i++) {
        await submit(tester, '99.99.99-999.99');
      }

      expect(calls, 10);
      expect(find.byType(IdentityPromptDialog), findsOneWidget);
      expect(find.textContaining('Réessayez dans'), findsNothing);
    });

    testWidgets('the right PIN closes the dialog', (tester) async {
      await open(tester, (_) async => true);
      await submit(tester, '78.02.14-153.24');

      expect(find.byType(IdentityPromptDialog), findsNothing);
    });
  });

  group('EmployeeSelector', () {
    Employee emp(String first, String last, String pin) => Employee(
      id: pin,
      storeId: 's1',
      firstName: first,
      lastName: last,
      pin: pin,
      phone: '0',
      email: '$first@x.c',
      hireDate: DateTime(2026),
      role: EmployeeRole.staff,
      pay: 2000,
      createdAt: DateTime(2026),
    );

    final roster = [
      emp('Amélie', 'Vandenberghe', '89.07.30-201.44'),
      emp('Karim', 'Haddouch', '01.02.03-004.05'),
    ];

    Future<Employee?> pumpSelector(
      WidgetTester tester, {
      bool showPin = false,
    }) async {
      Employee? picked;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 360,
              child: EmployeeSelector(
                employees: roster,
                value: picked,
                showPin: showPin,
                onChanged: (e) => setState(() => picked = e),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('opens, filters by name, and selects', (tester) async {
      await pumpSelector(tester);
      await tester.tap(find.byType(EmployeeSelector));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'karim');
      await tester.pumpAndSettle();
      expect(find.text('Amélie Vandenberghe'), findsNothing);

      await tester.tap(find.text('Karim Haddouch'));
      await tester.pumpAndSettle();
      // Closed field now shows the pick.
      expect(find.text('Karim Haddouch'), findsOneWidget);
    });

    testWidgets('filters by email, never by PIN', (tester) async {
      await pumpSelector(tester);
      await tester.tap(find.byType(EmployeeSelector));
      await tester.pumpAndSettle();

      // A PIN typed in the search tells nothing about whose it is.
      await tester.enterText(find.byType(TextField).last, '89.07.30');
      await tester.pumpAndSettle();
      expect(find.text('Amélie Vandenberghe'), findsNothing);
      expect(find.text('Karim Haddouch'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'amélie@x');
      await tester.pumpAndSettle();
      expect(find.text('Amélie Vandenberghe'), findsOneWidget);
      expect(find.text('Karim Haddouch'), findsNothing);
    });

    testWidgets('showPin renders the PIN, masked, under each name', (
      tester,
    ) async {
      await pumpSelector(tester, showPin: true);
      await tester.tap(find.byType(EmployeeSelector));
      await tester.pumpAndSettle();
      expect(find.text('89*************'), findsOneWidget);
      expect(find.textContaining('89.07.30-201.44'), findsNothing);
    });

    testWidgets('the clear button resets the selection', (tester) async {
      await pumpSelector(tester);
      await tester.tap(find.byType(EmployeeSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amélie Vandenberghe'));
      await tester.pumpAndSettle();
      expect(find.text('Amélie Vandenberghe'), findsOneWidget);

      await tester.tap(find.byTooltip('Effacer'));
      await tester.pumpAndSettle();
      expect(find.text('Amélie Vandenberghe'), findsNothing);
      expect(
        find.text('Rechercher ou sélectionner un employé…'),
        findsOneWidget,
      );
    });

    group('searchBar', () {
      Future<void> pumpBar(WidgetTester tester) async {
        Employee? picked;
        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 360,
                child: EmployeeSelector(
                  employees: roster,
                  value: picked,
                  showPin: true,
                  searchBar: true,
                  hint: 'Rechercher (nom, PIN)',
                  onChanged: (e) => setState(() => picked = e),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final bar = find.byKey(const ValueKey('employee-selector-search'));

      testWidgets('typing into the bar drops the matches beneath it, with no '
          'second search box', (tester) async {
        await pumpBar(tester);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Amélie Vandenberghe'), findsNothing);

        await tester.tap(bar);
        await tester.pumpAndSettle();
        expect(find.text('Amélie Vandenberghe'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        await tester.enterText(bar, 'karim');
        await tester.pumpAndSettle();
        expect(find.text('Amélie Vandenberghe'), findsNothing);
        expect(find.text('Karim Haddouch'), findsOneWidget);
        // The bare PIN, masked, no "PIN" word before it.
        expect(find.text('01*************'), findsOneWidget);
        expect(find.text('01.02.03-004.05'), findsNothing);
        expect(find.textContaining('PIN 01'), findsNothing);
      });

      testWidgets('picking shows the person in the bar; ✕ gives the empty '
          'search back', (tester) async {
        await pumpBar(tester);
        await tester.tap(bar);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Karim Haddouch'));
        await tester.pumpAndSettle();

        final selected = find.byKey(
          const ValueKey('employee-selector-selected'),
        );
        expect(selected, findsOneWidget);
        expect(
          find.descendant(of: selected, matching: find.text('Karim Haddouch')),
          findsOneWidget,
        );
        expect(bar, findsNothing);

        await tester.tap(find.byTooltip('Effacer'));
        await tester.pumpAndSettle();
        expect(selected, findsNothing);
        expect(bar, findsOneWidget);
        expect(find.text('Rechercher (nom, PIN)'), findsOneWidget);
      });

      testWidgets('a click outside closes the list', (tester) async {
        await pumpBar(tester);
        await tester.tap(bar);
        await tester.pumpAndSettle();
        expect(find.text('Amélie Vandenberghe'), findsOneWidget);

        await tester.tapAt(const Offset(5, 590));
        await tester.pumpAndSettle();
        expect(find.text('Amélie Vandenberghe'), findsNothing);
      });
    });
  });

  group('FilterToolbar', () {
    Future<void> pumpToolbar(WidgetTester tester, double width) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: width,
            child: FilterToolbar(
              search: SearchField(onChanged: (_) {}),
              filters: const [
                FilterPill(
                  key: ValueKey('a'),
                  label: 'Période',
                  selectedLabel: null,
                ),
                FilterPill(
                  key: ValueKey('b'),
                  label: 'Statut',
                  selectedLabel: null,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('wide: one line, the controls flush with the right edge', (
      tester,
    ) async {
      await pumpToolbar(tester, 1200);
      final strip = tester.getRect(find.byType(FilterToolbar));
      final a = tester.getRect(find.byKey(const ValueKey('a')));
      final b = tester.getRect(find.byKey(const ValueKey('b')));
      final search = tester.getRect(find.byType(TextField));
      expect(b.right, closeTo(strip.right, 0.5));
      expect(a.right, lessThan(b.left));
      expect(search.left, closeTo(strip.left, 0.5));
      expect(search.center.dy, closeTo(a.center.dy, 6));
      // The free space sits between the search and the controls.
      expect(a.left - search.right, greaterThan(100));
    });

    testWidgets('phone: the search on its own line, the controls below', (
      tester,
    ) async {
      await pumpToolbar(tester, 360);
      expect(tester.takeException(), isNull);
      final a = tester.getRect(find.byKey(const ValueKey('a')));
      final search = tester.getRect(find.byType(TextField));
      expect(a.top, greaterThan(search.bottom));
    });
  });

  group('DateFilter', () {
    setUpAll(() => initializeDateFormatting(Formatters.locale));

    testWidgets('names its end of the period; tinted only off its default', (
      tester,
    ) async {
      Future<FilterPill> pill({required bool isDefault}) async {
        await tester.pumpWidget(
          _host(
            DateFilter(
              label: 'Début',
              value: DateTime(2026, 9, 1),
              firstDate: DateTime(2000),
              lastDate: DateTime(2026, 12, 31),
              isDefault: isDefault,
              onChanged: (_) {},
            ),
          ),
        );
        return tester.widget<FilterPill>(find.byType(FilterPill));
      }

      final idle = await pill(isDefault: true);
      expect(idle.label, 'Début : 01/09/2026');
      expect(idle.selectedLabel, isNull);
      expect(
        (await pill(isDefault: false)).selectedLabel,
        'Début : 01/09/2026',
      );
    });

    testWidgets('opens a larger picker with smaller type, shrinking to fit', (
      tester,
    ) async {
      Future<(double scale, double dayFont)> open(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(
            DateFilter(
              label: 'Début',
              value: DateTime(2026, 9, 1),
              firstDate: DateTime(2000),
              lastDate: DateTime(2026, 12, 31),
              isDefault: true,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.tap(find.byType(FilterPill));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size');
        expect(find.byType(DatePickerDialog), findsOneWidget);

        final transform = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byType(DatePickerDialog),
                matching: find.byType(Transform),
              )
              .first,
        );
        final scale = transform.transform.getMaxScaleOnAxis();
        final day = tester.widget<Text>(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.text('15'),
          ),
        );
        final font = DefaultTextStyle.of(
          tester.element(find.text('15')),
        ).style.merge(day.style).fontSize!;

        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        return (scale, font);
      }

      // Room to spare on a landscape tablet: 20 % larger, digits at 13 on
      // screen however much the box grew.
      final (tabletScale, tabletFont) = await open(const Size(1280, 800));
      expect(tabletScale, closeTo(1.2, 0.001));
      expect(tabletFont * tabletScale, closeTo(13, 0.01));

      // A phone has no room to grow into: Material's own size.
      final (phoneScale, _) = await open(const Size(360, 640));
      expect(phoneScale, closeTo(1, 0.001));
    });
  });

  group('WeekdayDate', () {
    setUpAll(() => initializeDateFormatting(Formatters.locale));

    testWidgets('reads "Mar 12/10/2024", the weekday a size smaller', (
      tester,
    ) async {
      await tester.pumpWidget(_host(WeekdayDate(DateTime(2024, 10, 12))));
      final text = tester.widget<Text>(find.byType(Text));
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(text.textSpan!.toPlainText(), 'Sam 12/10/2024');
      expect(spans.first.text, 'Sam');
      final base = DefaultTextStyle.of(
        tester.element(find.byType(Text)),
      ).style.fontSize!;
      expect(spans.first.style!.fontSize, lessThan(base));
      expect(spans.last.style, isNull);
    });
  });

  group('AttendanceSessions', () {
    DateTime at(int h, int m) => DateTime(2026, 10, 24, h, m);
    Attendance day(List<AttendanceSession> sessions) => Attendance(
      id: 'a',
      storeId: 's',
      employeeId: 'e',
      date: DateTime(2026, 10, 24),
      status: AttendanceStatus.done,
      sessions: sessions,
      paymentStatus: PaymentStatus.unpaid,
    );

    Future<void> pump(
      WidgetTester tester,
      Attendance entry, {
      Map<String, String> exitAuthors = const {},
    }) async {
      await initializeDateFormatting(Formatters.locale);
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 400,
            child: AttendanceSessions(
              entry: entry,
              maxBreakMinutes: 30,
              exitAuthors: exitAuthors,
            ),
          ),
        ),
      );
    }

    testWidgets("a Départ entered in the employee's place says who", (
      tester,
    ) async {
      await pump(
        tester,
        day([
          AttendanceSession(clockInAt: at(8, 0), clockOutAt: at(12, 0)),
          AttendanceSession(
            clockInAt: at(14, 0),
            clockOutAt: at(18, 0),
            exitSetByEmployeeId: 'marc',
          ),
          AttendanceSession(
            clockInAt: at(19, 0),
            clockOutAt: at(20, 0),
            exitSetByEmployeeId: 'gone',
          ),
        ]),
        exitAuthors: const {'marc': 'Marc Delvaux'},
      );
      expect(find.text('Départ'), findsOneWidget, reason: 'clocked out alone');
      expect(find.text('Départ · saisi par Marc Delvaux'), findsOneWidget);
      expect(find.text('Départ · saisi par un responsable'), findsOneWidget);
    });

    testWidgets('one session: titled Session N° 1, like a split day', (
      tester,
    ) async {
      await pump(
        tester,
        day([
          AttendanceSession(
            clockInAt: at(8, 0),
            clockOutAt: at(16, 0),
            pauses: [AttendancePause(startAt: at(9, 30), endAt: at(10, 0))],
          ),
        ]),
      );
      expect(find.text('Session N° 1'), findsOneWidget);
      expect(find.textContaining('Session N° 2'), findsNothing);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('16:00'), findsOneWidget);
      // A 30-minute break against a 30-minute allowance: no alert.
      expect(find.textContaining('dépassée'), findsNothing);
    });

    testWidgets('two sessions: a centred Session N° each, no rules, no '
        'alert lines under them', (tester) async {
      await pump(
        tester,
        day([
          AttendanceSession(
            clockInAt: at(8, 0),
            clockOutAt: at(16, 0),
            pauses: [
              AttendancePause(startAt: at(9, 30), endAt: at(10, 0)),
              AttendancePause(startAt: at(13, 15), endAt: at(14, 0)),
            ],
          ),
          AttendanceSession(
            clockInAt: at(18, 0),
            clockOutAt: at(23, 0),
            pauses: [AttendancePause(startAt: at(19, 30), endAt: at(20, 0))],
          ),
        ]),
      );

      final first = find.text('Session N° 1');
      final second = find.text('Session N° 2');
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      // Centred in the 400dp column, with no hairline either side.
      expect(tester.getCenter(first).dx, closeTo(tester.getCenter(find.byType(AttendanceSessions)).dx, 1));
      expect(
        find.descendant(
          of: find.byType(AttendanceSessions),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.constraints?.maxHeight == 1,
          ),
        ),
        findsNothing,
      );
      // Dashes either side of each label, out to both edges, and a
      // full-width one closing the list, under the last event.
      final column = tester.getRect(find.byType(AttendanceSessions));
      final heading = find.ancestor(of: first, matching: find.byType(Row)).first;
      final dashes = find.descendant(
        of: heading,
        matching: find.byType(CustomPaint),
      );
      expect(dashes, findsNWidgets(2));
      expect(tester.getRect(dashes.first).left, closeTo(column.left, 0.5));
      expect(tester.getRect(dashes.last).right, closeTo(column.right, 0.5));
      final end = find.byKey(const ValueKey('attendance-sessions-end'));
      expect(end, findsOneWidget);
      expect(tester.getSize(end).width, closeTo(column.width, 0.5));
      expect(
        tester.getTopLeft(end).dy,
        greaterThan(tester.getTopLeft(find.text('23:00')).dy),
      );
      // Room between the sessions.
      expect(
        tester.getTopLeft(second).dy -
            tester.getBottomLeft(find.text('16:00')).dy,
        greaterThanOrEqualTo(32),
      );
      // The overrun is the drawer's Alertes section's business now.
      expect(find.textContaining('dépassée'), findsNothing);
      expect(
        tester.getTopLeft(find.text('18:00')).dy,
        greaterThan(tester.getTopLeft(second).dy),
      );
    });
  });

  group('AttendanceDayDetail', () {
    DateTime at(int h, int m) => DateTime(2026, 10, 24, h, m);
    final amelie = Employee(
      id: 'e',
      storeId: 's',
      firstName: 'Amélie',
      lastName: 'Laurent',
      pin: '4821',
      phone: '0',
      email: 'a@x.c',
      hireDate: DateTime(2026),
      role: EmployeeRole.staff,
      pay: 2000,
      createdAt: DateTime(2026),
    );
    Attendance day({bool overrun = false}) => Attendance(
      id: 'a',
      storeId: 's',
      employeeId: 'e',
      date: DateTime(2026, 10, 24),
      status: AttendanceStatus.done,
      sessions: [
        AttendanceSession(
          clockInAt: at(8, 0),
          clockOutAt: at(12, 0),
          pauses: [
            AttendancePause(
              startAt: at(10, 0),
              endAt: overrun ? at(10, 45) : at(10, 20),
            ),
          ],
        ),
        AttendanceSession(clockInAt: at(14, 0), clockOutAt: at(18, 0)),
      ],
      paymentStatus: PaymentStatus.unpaid,
    );

    Future<void> pump(
      WidgetTester tester,
      Attendance entry, {
      bool showPin = true,
    }) async {
      await initializeDateFormatting(Formatters.locale);
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: AttendanceDayDetail(
                entry: entry,
                employee: amelie,
                maxBreakMinutes: 30,
                showPin: showPin,
                now: DateTime(2026, 10, 30),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('identity, day, sessions, summary, alerts — in that order', (
      tester,
    ) async {
      await pump(tester, day(overrun: true));
      final name = find.text('Amélie Laurent');
      final pin = find.text('48**');
      final date = find.text('Samedi 24/10/2026');
      final session = find.text('Session N° 1');
      final summary = find.textContaining('Résumé de la journée');
      final alerts = find.text('Alertes');
      for (final f in [name, pin, date, session, summary, alerts]) {
        expect(f, findsOneWidget);
      }
      expect(find.text('PIN'), findsNothing);
      expect(find.byType(AttendanceStatusBadge), findsOneWidget);
      double y(Finder f) => tester.getTopLeft(f).dy;
      expect(y(pin), greaterThan(y(name)));
      expect(y(date), greaterThan(y(pin)));
      // A line under the date saying what follows.
      final intro = find.byKey(const ValueKey('attendance-day-intro'));
      expect(intro, findsOneWidget);
      // One short line, not a paragraph.
      expect(
        tester.widget<Text>(intro).data,
        'Pointages, temps travaillé et pauses de la journée.',
      );
      expect(y(intro), greaterThan(y(date)));
      expect(y(session), greaterThan(y(intro)));
      expect(y(summary), greaterThan(y(find.text('18:00'))));
      expect(y(alerts), greaterThan(y(summary)));
      // 4 h + 4 h, minus the 45-min break; one break.
      // A 2 × 2 table: label | value.
      final table = tester.widget<Table>(
        find.descendant(
          of: find.byKey(const ValueKey('attendance-day-summary')),
          matching: find.byType(Table),
        ),
      );
      expect(table.children, hasLength(2));
      expect(table.children.every((r) => r.children.length == 2), isTrue);
      String value(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      expect(find.text('Durée totale travaillée'), findsOneWidget);
      expect(value('attendance-day-worked'), '7 h 15');
      expect(find.text('Pauses (1)'), findsOneWidget);
      expect(value('attendance-day-pauses'), '45 min');
      // The summary line is a paragraph, not a heading.
      expect(
        tester.widget<Text>(summary).style!.fontSize,
        lessThan(Theme.of(tester.element(summary)).textTheme.titleSmall!.fontSize!),
      );
      expect(find.text('Pause dépassée de 15 min'), findsOneWidget);
    });

    testWidgets('no alert: no Alertes section at all', (tester) async {
      await pump(tester, day());
      expect(find.text('Alertes'), findsNothing);
      expect(find.byKey(const ValueKey('attendance-day-alerts')), findsNothing);
      expect(find.textContaining('Résumé de la journée'), findsOneWidget);
    });

    testWidgets('showPin false: the name alone', (tester) async {
      await pump(tester, day(), showPin: false);
      expect(find.text('Amélie Laurent'), findsOneWidget);
      expect(find.text('4821'), findsNothing);
    });
  });

  group('PayrollDayDetail', () {
    DateTime at(int h, int m) => DateTime(2026, 10, 24, h, m);
    final karim = Employee(
      id: 'e',
      storeId: 's',
      firstName: 'Karim',
      lastName: 'Haddouch',
      pin: '4821',
      phone: '0',
      email: 'k@x.c',
      hireDate: DateTime(2026),
      role: EmployeeRole.staff,
      pay: 12,
      createdAt: DateTime(2026),
    );
    // 09:00–12:00, then 18:00–22:30 with a 15-min break: 7 h 15 worked.
    Attendance day({PaymentStatus status = PaymentStatus.unpaid}) =>
        Attendance(
          id: 'a',
          storeId: 's',
          employeeId: 'e',
          date: DateTime(2026, 10, 24),
          status: AttendanceStatus.done,
          sessions: [
            AttendanceSession(clockInAt: at(9, 0), clockOutAt: at(12, 0)),
            AttendanceSession(
              clockInAt: at(18, 0),
              clockOutAt: at(22, 30),
              pauses: [
                AttendancePause(startAt: at(20, 0), endAt: at(20, 15)),
              ],
            ),
          ],
          paymentStatus: status,
        );

    Future<void> pump(
      WidgetTester tester,
      Attendance entry, {
      double rate = 12,
      DateTime? paidAt,
      Future<bool> Function()? onPay,
      VoidCallback? onClose,
    }) async {
      await initializeDateFormatting(Formatters.locale);
      await tester.pumpWidget(
        _host(
          DrawerScope(
            close: onClose ?? () {},
            child: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: PayrollDayDetail(
                  entry: entry,
                  employee: karim,
                  rate: rate,
                  amount: rate * 7.25,
                  paidAt: paidAt,
                  maxBreakMinutes: 30,
                  onPay: onPay,
                ),
              ),
            ),
          ),
        ),
      );
    }

    String value(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;

    testWidgets('reads like the pointage drawer: identity, day, every '
        'session titled, then the summary with the rate and the amount', (
      tester,
    ) async {
      await pump(tester, day());
      double y(Finder f) => tester.getTopLeft(f).dy;

      final name = find.text('Karim Haddouch');
      final date = find.text('Samedi 24/10/2026');
      final intro = find.byKey(const ValueKey('payroll-day-intro'));
      final first = find.text('Session N° 1');
      final second = find.text('Session N° 2');
      final summary = find.byKey(const ValueKey('payroll-day-summary'));
      for (final f in [name, date, intro, first, second, summary]) {
        expect(f, findsOneWidget);
      }
      expect(y(date), greaterThan(y(name)));
      expect(y(intro), greaterThan(y(date)));
      expect(y(first), greaterThan(y(intro)));
      expect(y(second), greaterThan(y(first)));
      expect(y(summary), greaterThan(y(second)));

      expect(
        tester.widget<Text>(intro).data,
        'Pointages et montant de la journée.',
      );
      // The payment status, not the pointage one; no titled header.
      expect(find.byType(PaymentStatusBadge), findsOneWidget);
      expect(find.byType(AttendanceStatusBadge), findsNothing);
      expect(find.text('Détail du paiement'), findsNothing);

      expect(value(tester, 'payroll-day-worked'), '7 h 15');
      expect(value(tester, 'payroll-day-pauses'), '15 min');
      expect(
        value(tester, 'payroll-day-rate'),
        '${Formatters.price(12)}/h',
      );
      // Rate × time worked over both sessions — no overtime anywhere.
      expect(value(tester, 'payroll-day-amount'), Formatters.price(87));
      expect(
        find.text('Montant (${Formatters.price(12)} × 7 h 15)'),
        findsOneWidget,
      );
      expect(find.textContaining('supplémentaires'), findsNothing);
      expect(find.byKey(const ValueKey('payroll-day-paid-at')), findsNothing);
    });

    testWidgets('a paid day: its payment date, its frozen rate, no button', (
      tester,
    ) async {
      await pump(
        tester,
        day(status: PaymentStatus.paid),
        rate: 10,
        paidAt: DateTime(2026, 10, 26),
        onPay: () async => true,
      );
      expect(value(tester, 'payroll-day-paid-at'), '26/10/2026');
      expect(
        value(tester, 'payroll-day-rate'),
        '${Formatters.price(10)}/h',
      );
      expect(value(tester, 'payroll-day-amount'), Formatters.price(72.5));
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('an unpaid day: « Payer ce jour » pays, then closes the '
        'drawer', (tester) async {
      var paid = 0;
      var closed = 0;
      await pump(
        tester,
        day(),
        onPay: () async {
          paid++;
          return true;
        },
        onClose: () => closed++,
      );
      final button = find.widgetWithText(PrimaryButton, 'Payer ce jour');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(paid, 1);
      expect(closed, 1);
    });

    testWidgets('a cancelled payment leaves the drawer open', (tester) async {
      var closed = 0;
      await pump(
        tester,
        day(),
        onPay: () async => false,
        onClose: () => closed++,
      );
      final button = find.widgetWithText(PrimaryButton, 'Payer ce jour');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(closed, 0);
    });

    testWidgets('no onPay: no button', (tester) async {
      await pump(tester, day());
      expect(find.byType(PrimaryButton), findsNothing);
    });
  });

  group('Paginator', () {
    Widget paginator({
      int page = 0,
      int pageCount = 1,
      int total = 3,
      int pageSize = 10,
      ValueChanged<int>? onChanged,
      ValueChanged<int>? onPageSize,
    }) => _host(
      SizedBox(
        width: 800,
        child: Paginator(
          page: page,
          pageCount: pageCount,
          totalCount: total,
          pageSize: pageSize,
          onChanged: onChanged ?? (_) {},
          onPageSizeChanged: onPageSize,
        ),
      ),
    );

    testWidgets('hidden while everything fits the smallest page', (
      tester,
    ) async {
      await tester.pumpWidget(paginator());
      expect(find.textContaining('sur'), findsNothing);
      await tester.pumpWidget(paginator(total: 10, onPageSize: (_) {}));
      expect(find.textContaining('sur'), findsNothing);
      expect(find.byKey(const ValueKey('paginator-page-size')), findsNothing);
    });

    testWidgets('shown past the smallest page, even on one page of 25', (
      tester,
    ) async {
      await tester.pumpWidget(
        paginator(total: 15, pageSize: 25, onPageSize: (_) {}),
      );
      expect(find.text('1–15 sur 15'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('paginator-page-size')), findsOneWidget);
      for (final tooltip in ['Page précédente', 'Page suivante']) {
        final button = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          ),
        );
        expect(button.onPressed, isNull);
      }
    });

    testWidgets('nothing at all without a row', (tester) async {
      await tester.pumpWidget(paginator(total: 0));
      expect(find.textContaining('sur'), findsNothing);
    });

    testWidgets('no rows-per-page menu without a handler', (tester) async {
      await tester.pumpWidget(paginator(total: 40, pageCount: 4));
      expect(find.byKey(const ValueKey('paginator-page-size')), findsNothing);
    });

    testWidgets('the rows-per-page menu offers 10 / 25 / 50', (tester) async {
      int? picked;
      await tester.pumpWidget(
        paginator(total: 40, pageCount: 4, onPageSize: (s) => picked = s),
      );
      final menu = find.byKey(const ValueKey('paginator-page-size'));
      expect(
        find.descendant(of: menu, matching: find.text('Lignes par page :')),
        findsOneWidget,
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<int>), findsNWidgets(3));
      await tester.tap(find.widgetWithText(PopupMenuItem<int>, '25'));
      await tester.pumpAndSettle();
      expect(picked, 25);
    });

    testWidgets('range left; rows-per-page and arrows on the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        paginator(total: 40, pageCount: 4, onPageSize: (_) {}),
      );
      final frame = tester.getRect(find.byType(Paginator));
      final menu = tester.getRect(
        find.byKey(const ValueKey('paginator-page-size')),
      );
      final next = tester.getRect(find.byTooltip('Page suivante'));
      expect(tester.getRect(find.text('1–10 sur 40')).left, frame.left);
      expect(next.right, closeTo(frame.right, 0.5));
      expect(menu.right, lessThan(next.left));
      expect(menu.center.dy, closeTo(next.center.dy, 2));
      final chip = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const ValueKey('paginator-page-size')),
          matching: find.byType(Container),
        ).first,
      );
      expect((chip.decoration! as BoxDecoration).color, AppColors.white);
    });

    testWidgets('white arrows with a green chevron; the page number green', (
      tester,
    ) async {
      await tester.pumpWidget(paginator(page: 1, total: 40, pageCount: 4));
      final style = tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Page suivante'),
              matching: find.byType(IconButton),
            ),
          )
          .style!;
      expect(style.backgroundColor!.resolve({}), AppColors.white);
      expect(style.foregroundColor!.resolve({}), AppColors.primary600);
      expect(style.side?.resolve({}), isNull);
      expect(
        tester.getSize(find.byTooltip('Page suivante')),
        const Size.square(32),
      );
      expect(find.text('2 / 4'), findsOneWidget);
      final span = tester
          .widget<RichText>(
            find.descendant(
              of: find.byType(Paginator),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is RichText && w.text.toPlainText() == '2 / 4',
              ),
            ),
          )
          .text as TextSpan;
      final current = (span.children!.single as TextSpan).children!.first;
      expect(current.toPlainText(), '2');
      expect(current.style!.color, AppColors.primary600);
    });

    testWidgets('Suivant moves one page on', (tester) async {
      int? page;
      await tester.pumpWidget(
        paginator(total: 40, pageCount: 4, onChanged: (p) => page = p),
      );
      expect(find.text('1–10 sur 40'), findsOneWidget);
      await tester.tap(find.byTooltip('Page suivante'));
      expect(page, 1);
    });
  });

  testWidgets('tooltips: white, brand-green text, no dark box', (tester) async {
    await tester.pumpWidget(
      _host(
        const Tooltip(message: 'Aide', child: Text('?')),
      ),
    );
    final theme = TooltipTheme.of(tester.element(find.text('?')));
    final box = theme.decoration! as BoxDecoration;
    expect(box.color, AppColors.white);
    expect(box.boxShadow, isNotEmpty);
    expect(theme.textStyle!.color, AppColors.primary600);
  });

  testWidgets('sidebar row: the active page a white pill with green text; '
      'the others softened white on the green ground', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SidebarNavTile(
                icon: LucideIcons.store,
                label: 'Actif',
                active: true,
                collapsed: false,
                onTap: _noop,
              ),
              SidebarNavTile(
                icon: LucideIcons.store,
                label: 'Autre',
                active: false,
                collapsed: false,
                onTap: _noop,
              ),
            ],
          ),
        ),
      ),
    );
    Material fill(String label) => tester.widget<Material>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first,
    );
    Color? ink(String label) => tester.widget<Text>(find.text(label)).style?.color;
    expect(fill('Actif').color, AppColors.white);
    expect(ink('Actif'), AppColors.primary600);
    expect(fill('Autre').color, Colors.transparent);
    expect(ink('Autre'), AppColors.white.withValues(alpha: 0.78));
  });
}

void _noop() {}
