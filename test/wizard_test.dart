// The shared wizard components (design step 1.1): WizardStepIndicator and
// WizardScaffold, driven standalone rather than through a real form.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:stock_inventory/app/navigation.dart';
import 'package:stock_inventory/core/theme/app_theme.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('fr', 'BE'),
  supportedLocales: const [Locale('fr', 'BE')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A three-step wizard whose validity and submit the test controls.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.valid,
    required this.onSubmit,
    this.freeNavigation = false,
  });

  final List<bool> valid;
  final VoidCallback onSubmit;
  final bool freeNavigation;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      title: 'Ajouter',
      description: 'Trois étapes.',
      back: const BackDestination(label: 'Personnel', path: '/'),
      backLinkLabel: "Retour à l'accueil",
      currentStep: _step,
      onStepChanged: (i) => setState(() => _step = i),
      freeNavigation: widget.freeNavigation,
      submitLabel: 'Enregistrer',
      onSubmit: widget.onSubmit,
      steps: [
        for (final (i, label) in ['Infos', 'Paie', 'Rôle'].indexed)
          WizardStep(
            label: label,
            isValid: widget.valid[i],
            child: Text('page $i'),
          ),
      ],
    );
  }
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(_button(label).first).onPressed != null;

void main() {
  group('WizardStepIndicator', () {
    testWidgets('marks done, current and upcoming steps', (tester) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _host(
          const WizardStepIndicator(labels: ['A', 'B', 'C'], current: 1),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      // Step 1 is done → a check instead of its number.
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('only a passed step is tappable by default', (tester) async {
      _size(tester, const Size(1280, 800));
      final tapped = <int>[];
      await tester.pumpWidget(
        _host(
          WizardStepIndicator(
            labels: const ['A', 'B', 'C'],
            current: 1,
            onStepTapped: tapped.add,
          ),
        ),
      );

      await tester.tap(find.text('C'));
      await tester.tap(find.text('B'));
      await tester.tap(find.text('A'));
      expect(tapped, [0]);
    });

    testWidgets('collapses to "Étape n sur N" on a phone', (tester) async {
      _size(tester, const Size(390, 800));
      await tester.pumpWidget(
        _host(
          const WizardStepIndicator(labels: ['A', 'B', 'C'], current: 1),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Étape 2 sur 3 · B'), findsOneWidget);
      // One segment per step, the first two filled.
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('wizard-segment-$i')), findsOneWidget);
      }
      Color colorOf(int i) =>
          (tester.widget<Container>(find.byKey(ValueKey('wizard-segment-$i')))
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(colorOf(0), colorOf(1));
      expect(colorOf(2), isNot(colorOf(1)));
    });
  });

  group('WizardScaffold', () {
    testWidgets('header: title, paragraph and the back link on the right', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );

      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.text('Trois étapes.'), findsOneWidget);
      expect(find.text("Retour à l'accueil"), findsOneWidget);
      // The link replaces the back control above the title.
      expect(find.byType(BackControl), findsNothing);
    });

    testWidgets('Suivant is gated by the step, and walks forward and back', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _host(_Harness(valid: const [false, true, true], onSubmit: () {})),
      );
      expect(find.text('page 0'), findsOneWidget);
      expect(_enabled(tester, 'Suivant'), isFalse);
      expect(find.text('Précédent'), findsNothing);

      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );
      await tester.tap(_button('Suivant').first);
      await tester.pumpAndSettle();
      expect(find.text('page 1'), findsOneWidget);

      await tester.tap(_button('Précédent').first);
      await tester.pumpAndSettle();
      expect(find.text('page 0'), findsOneWidget);
    });

    testWidgets('the last step submits, only once every step is valid', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      var submitted = 0;
      await tester.pumpWidget(
        _host(
          _Harness(valid: const [true, true, true], onSubmit: () => submitted++),
        ),
      );
      // Create mode: no Enregistrer before the last step.
      expect(find.text('Enregistrer'), findsNothing);

      await tester.tap(_button('Suivant').first);
      await tester.pumpAndSettle();
      await tester.tap(_button('Suivant').first);
      await tester.pumpAndSettle();

      expect(find.text('page 2'), findsOneWidget);
      expect(find.text('Suivant'), findsNothing);
      await tester.tap(_button('Enregistrer').first);
      expect(submitted, 1);
    });

    testWidgets('an invalid step keeps the final submit disabled', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _host(
          _Harness(
            valid: const [true, true, false],
            onSubmit: () {},
            freeNavigation: true,
          ),
        ),
      );
      expect(_enabled(tester, 'Enregistrer'), isFalse);
    });

    testWidgets('free navigation: submit on every step, jump from the '
        'indicator', (tester) async {
      _size(tester, const Size(1280, 800));
      var submitted = 0;
      await tester.pumpWidget(
        _host(
          _Harness(
            valid: const [true, true, true],
            onSubmit: () => submitted++,
            freeNavigation: true,
          ),
        ),
      );

      expect(find.text('page 0'), findsOneWidget);
      expect(_enabled(tester, 'Enregistrer'), isTrue);
      expect(find.text('Suivant'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('wizard-step-2')));
      await tester.pumpAndSettle();
      expect(find.text('page 2'), findsOneWidget);

      await tester.tap(_button('Enregistrer').first);
      expect(submitted, 1);
    });

    testWidgets('fields inside a step are white, borderless, green on focus', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _host(
          WizardScaffold(
            title: 'Ajouter',
            description: '…',
            back: const BackDestination(label: 'Personnel', path: '/'),
            backLinkLabel: 'Retour',
            currentStep: 0,
            onStepChanged: (_) {},
            submitLabel: 'Enregistrer',
            onSubmit: () {},
            steps: const [
              WizardStep(label: 'A', child: AppTextField(label: 'Prénom')),
              WizardStep(label: 'B', child: SizedBox()),
            ],
          ),
        ),
      );

      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.fillColor, Colors.white);
      expect(
        (decoration.enabledBorder! as OutlineInputBorder).borderSide,
        BorderSide.none,
      );
      final focused = decoration.focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.width, 2);
      expect(focused.borderSide.style, BorderStyle.solid);

      // Outside a wizard the theme's standard field is untouched.
      await tester.pumpWidget(_host(const AppTextField(label: 'Prénom')));
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.fillColor,
        isNull,
      );
    });

    testWidgets('header at full width like a root page; the steps centred',
        (tester) async {
      _size(tester, const Size(1800, 900));
      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );

      // Header: title at the page's left, the link at its right edge.
      expect(tester.getTopLeft(find.text('Ajouter')).dx, lessThan(100));
      expect(
        tester.getTopRight(find.text("Retour à l'accueil")).dx,
        greaterThan(1800 - 100),
      );
      // Body: the step content is a centred column, not pinned left.
      final page = tester.getRect(find.byKey(const ValueKey('wizard-page-0')));
      // (1800 − 2×24 padding − 1280) / 2 + 24 = 260.
      expect(page.left, greaterThan(200));
      expect((page.center.dx - 900).abs(), lessThan(40));
    });

    testWidgets('the actions follow the step, not a bar pinned to the bottom',
        (tester) async {
      _size(tester, const Size(1800, 1000));
      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );

      final pageBottom = tester
          .getRect(find.byKey(const ValueKey('wizard-page-0')))
          .bottom;
      final next = tester.getRect(_button('Suivant').first);
      final cancel = tester.getRect(_button('Annuler').first);
      // Right under the content, well above the window's bottom edge…
      expect(next.top, greaterThan(pageBottom));
      expect(next.top - pageBottom, lessThan(80));
      expect(next.bottom, lessThan(1000 - 200));
      // …and inside the wizard's column, Annuler left, Suivant right.
      expect(cancel.left, greaterThan(200));
      expect(next.right, lessThan(1800 - 200));
    });

    testWidgets('the steps sit a little above the middle under the header', (
      tester,
    ) async {
      _size(tester, const Size(1800, 1000));
      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );

      final headerBottom = tester.getRect(find.text('Trois étapes.')).bottom;
      final top = tester.getRect(find.byType(WizardStepIndicator)).top;
      final bottom = tester.getRect(_button('Suivant').first).bottom;
      final above = top - headerBottom;
      final below = 1000 - bottom;
      // Centred, tipped upward: some room above, more below.
      expect(above, greaterThan(40));
      expect(below, greaterThan(above));
    });

    testWidgets('Annuler is quiet (#777, no border); Précédent is white, '
        'no border', (tester) async {
      _size(tester, const Size(1800, 1000));
      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );
      await tester.tap(_button('Suivant').first);
      await tester.pumpAndSettle();

      ButtonStyle styleOf(String label) =>
          tester.widget<ButtonStyleButton>(_button(label).first).style!;
      const none = <WidgetState>{};

      final cancel = styleOf('Annuler');
      expect(cancel.foregroundColor?.resolve(none), const Color(0xFF777777));
      expect(cancel.side?.resolve(none), BorderSide.none);

      final previous = styleOf('Précédent');
      expect(previous.backgroundColor?.resolve(none), Colors.white);
      expect(previous.side?.resolve(none), BorderSide.none);
    });

    testWidgets('Suivant is translucent green; the final save is solid', (
      tester,
    ) async {
      _size(tester, const Size(1800, 1000));
      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );
      const none = <WidgetState>{};
      Color? backgroundOf(String label) => tester
          .widget<ButtonStyleButton>(_button(label).first)
          .style
          ?.backgroundColor
          ?.resolve(none);

      final next = backgroundOf('Suivant')!;
      expect(next.a, lessThan(0.5));

      await tester.tap(_button('Suivant').first);
      await tester.pumpAndSettle();
      await tester.tap(_button('Suivant').first);
      await tester.pumpAndSettle();
      // Enregistrer takes the theme's solid teal (no override).
      expect(backgroundOf('Enregistrer'), isNull);
    });

    testWidgets('Annuler turns white on hover', (tester) async {
      _size(tester, const Size(1800, 1000));
      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );
      final style = tester
          .widget<ButtonStyleButton>(_button('Annuler').first)
          .style!;
      expect(
        style.backgroundColor?.resolve(const {WidgetState.hovered}),
        Colors.white,
      );
      expect(
        style.backgroundColor?.resolve(const <WidgetState>{}),
        Colors.transparent,
      );
    });

    testWidgets('no paragraph under the title on a phone', (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );
      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.text('Trois étapes.'), findsNothing);
    });

    testWidgets('plain fields show their placeholder in #777', (tester) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _host(
          const AppTextFieldVariantScope(
            variant: AppTextFieldVariant.plain,
            child: AppTextField(label: 'Prénom', hint: 'Ex. Nora'),
          ),
        ),
      );
      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.hintStyle?.color, const Color(0xFF777777));
      expect(find.text('Ex. Nora'), findsOneWidget);
    });

    testWidgets('fits a phone', (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(
        _host(_Harness(valid: const [true, true, true], onSubmit: () {})),
      );
      await tester.tap(_button('Suivant').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Étape 2 sur 3 · Paie'), findsOneWidget);
      expect(find.text('Précédent'), findsOneWidget);
    });
  });
}
