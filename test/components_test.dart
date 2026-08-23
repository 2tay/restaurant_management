// Behaviour tests for the shared component library.
//
// Focused on the pieces that carry real logic or a rule from the brief. Purely
// presentational widgets are covered by the route walk, which renders them.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/theme/app_theme.dart';
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
}
