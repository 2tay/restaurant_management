// Behaviour tests for the shared component library.
//
// Focused on the pieces that carry real logic or a rule from the brief. Purely
// presentational widgets are covered by the route walk, which renders them.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:stock_inventory/core/theme/app_colors.dart';
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

  group('StatTileRow', () {
    testWidgets('drops to one column when four will not fit', (tester) async {
      const tiles = [
        StatTile(label: 'Actifs', value: '12', icon: LucideIcons.users),
        StatTile(label: 'Gérants', value: '3', icon: LucideIcons.shieldCheck),
        StatTile(
          label: 'Contrats',
          value: '9 / 3',
          icon: LucideIcons.briefcase,
        ),
        StatTile(label: 'Embauches', value: '1', icon: LucideIcons.userPlus),
      ];

      // A phone's content width. Four tiles across would give each one 63dp,
      // which is the icon medallion and nothing else.
      await tester.pumpWidget(
        _host(const SizedBox(width: 296, child: StatTileRow(tiles: tiles))),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(StatTile).first).width,
        296,
        reason: 'one tile per line at 296dp',
      );

      // The design baseline: all four share the line.
      await tester.pumpWidget(
        _host(const SizedBox(width: 1000, child: StatTileRow(tiles: tiles))),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(StatTile).first).width,
        lessThan(280),
        reason: 'four across at 1000dp',
      );
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

    testWidgets('filters by PIN even when the PIN is not shown', (
      tester,
    ) async {
      await pumpSelector(tester);
      await tester.tap(find.byType(EmployeeSelector));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '89.07.30');
      await tester.pumpAndSettle();
      expect(find.text('Amélie Vandenberghe'), findsOneWidget);
      expect(find.text('Karim Haddouch'), findsNothing);
      // showPin is false → the number itself is not rendered in the row.
      expect(find.textContaining('PIN 89.07.30-201.44'), findsNothing);
    });

    testWidgets('showPin renders the PIN under each name', (tester) async {
      await pumpSelector(tester, showPin: true);
      await tester.tap(find.byType(EmployeeSelector));
      await tester.pumpAndSettle();
      expect(find.textContaining('89.07.30-201.44'), findsOneWidget);
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
        // The bare PIN, no "PIN" word before it.
        expect(find.text('01.02.03-004.05'), findsOneWidget);
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
}
