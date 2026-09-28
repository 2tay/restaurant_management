// The shared wizard components: WizardStepIndicator and WizardDialog, driven
// standalone rather than through a real form.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

/// A three-step wizard whose validity, dirtiness and submit the test controls.
class _Wizard extends StatefulWidget {
  const _Wizard({
    required this.valid,
    required this.onSubmit,
    this.freeNavigation = false,
    this.isDirty = false,
    this.stepChild,
    this.onReset,
  });

  final List<bool> valid;
  final VoidCallback onSubmit;
  final bool freeNavigation;
  final bool isDirty;
  final Widget? stepChild;
  final VoidCallback? onReset;

  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return WizardDialog(
      title: 'Ajouter',
      description: 'Trois étapes.',
      currentStep: _step,
      onStepChanged: (i) => setState(() => _step = i),
      freeNavigation: widget.freeNavigation,
      isDirty: widget.isDirty,
      onReset: widget.onReset == null
          ? null
          : () {
              widget.onReset!();
              setState(() => _step = 0);
            },
      submitLabel: 'Enregistrer',
      onSubmit: widget.onSubmit,
      steps: [
        for (final (i, label) in ['Infos', 'Paie', 'Rôle'].indexed)
          WizardStep(
            label: label,
            isValid: widget.valid[i],
            child: i == 0 && widget.stepChild != null
                ? widget.stepChild!
                : Text('page $i'),
          ),
      ],
    );
  }
}

/// Pumps a page with an "open" button and opens the wizard over it.
Future<void> _open(
  WidgetTester tester, {
  List<bool> valid = const [true, true, true],
  VoidCallback? onSubmit,
  bool freeNavigation = false,
  bool isDirty = false,
  Widget? stepChild,
  VoidCallback? onReset,
  Size size = const Size(1440, 900),
}) async {
  _size(tester, size);
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => WizardDialog.show<void>(
            context,
            builder: (_) => _Wizard(
              valid: valid,
              onSubmit: onSubmit ?? () {},
              freeNavigation: freeNavigation,
              isDirty: isDirty,
              stepChild: stepChild,
              onReset: onReset,
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(_button(label).first).onPressed != null;

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(_button(label).first);
  await tester.pumpAndSettle();
}

const _none = <WidgetState>{};

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

    testWidgets('collapses to "Étape n sur N" in segments on a phone', (
      tester,
    ) async {
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

  group('WizardDialog', () {
    testWidgets('opens as a pop-up over the page: title, paragraph, close', (
      tester,
    ) async {
      await _open(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('open'), findsOneWidget); // the page is still there
      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.text('Trois étapes.'), findsOneWidget);
      expect(find.byKey(const ValueKey('wizard-close')), findsOneWidget);
    });

    testWidgets('Suivant is gated by the step', (
      tester,
    ) async {
      await _open(tester, valid: const [false, true, true]);
      expect(find.text('page 0'), findsOneWidget);
      expect(_enabled(tester, 'Suivant'), isFalse);
      expect(find.text('Précédent'), findsNothing);
    });

    testWidgets('walks forward and back', (tester) async {
      await _open(tester);
      await _tap(tester, 'Suivant');
      expect(find.text('page 1'), findsOneWidget);
      await _tap(tester, 'Précédent');
      expect(find.text('page 0'), findsOneWidget);
    });

    testWidgets('the last step submits, only once every step is valid', (
      tester,
    ) async {
      var submitted = 0;
      await _open(tester, onSubmit: () => submitted++);
      // Create mode: no Enregistrer before the last step.
      expect(find.text('Enregistrer'), findsNothing);

      await _tap(tester, 'Suivant');
      await _tap(tester, 'Suivant');
      expect(find.text('page 2'), findsOneWidget);
      expect(find.text('Suivant'), findsNothing);
      await tester.tap(_button('Enregistrer').first);
      expect(submitted, 1);
    });

    testWidgets('an invalid step keeps the final submit disabled', (
      tester,
    ) async {
      await _open(
        tester,
        valid: const [true, true, false],
        freeNavigation: true,
      );
      expect(_enabled(tester, 'Enregistrer'), isFalse);
    });

    testWidgets('free navigation: submit on every step, jump from the '
        'indicator', (tester) async {
      var submitted = 0;
      await _open(
        tester,
        onSubmit: () => submitted++,
        freeNavigation: true,
      );

      expect(_enabled(tester, 'Enregistrer'), isTrue);
      expect(find.text('Suivant'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('wizard-step-2')));
      await tester.pumpAndSettle();
      expect(find.text('page 2'), findsOneWidget);

      await tester.tap(_button('Enregistrer').first);
      expect(submitted, 1);
    });

    testWidgets('closes straight away when nothing was typed', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('wizard-close')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('asks before discarding typed input on close', (
      tester,
    ) async {
      await _open(tester, isDirty: true);

      await tester.tap(find.byKey(const ValueKey('wizard-close')));
      await tester.pumpAndSettle();
      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
      // Keep editing.
      await tester.tap(find.text('Continuer la saisie'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wizard-close')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('wizard-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abandonner'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wizard-close')), findsNothing);
    });

    testWidgets('no Annuler: Réinitialiser, offered once something was typed, '
        'asks, then returns to step 1', (tester) async {
      var resets = 0;
      await _open(tester, isDirty: true, onReset: () => resets++);
      expect(find.text('Annuler'), findsNothing);

      await _tap(tester, 'Suivant');
      expect(find.text('page 1'), findsOneWidget);

      await _tap(tester, 'Réinitialiser');
      expect(find.text('Réinitialiser le formulaire ?'), findsOneWidget);
      await tester.tap(find.text('Réinitialiser').last);
      await tester.pumpAndSettle();

      expect(resets, 1);
      expect(find.text('page 0'), findsOneWidget);
    });

    testWidgets('Réinitialiser is disabled until something was typed', (
      tester,
    ) async {
      await _open(tester, onReset: () {});
      expect(_enabled(tester, 'Réinitialiser'), isFalse);
    });

    testWidgets('fields inside a step are white, borderless, green on focus', (
      tester,
    ) async {
      await _open(
        tester,
        stepChild: const AppTextField(label: 'Prénom', hint: 'Ex. Nora'),
      );

      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.fillColor, Colors.white);
      expect(
        (decoration.enabledBorder! as OutlineInputBorder).borderSide,
        BorderSide.none,
      );
      expect(
        (decoration.focusedBorder! as OutlineInputBorder).borderSide.width,
        2,
      );
      expect(decoration.hintStyle?.color, const Color(0xFF777777));
    });

    testWidgets('outside a wizard the standard field is untouched', (
      tester,
    ) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(_host(const AppTextField(label: 'Prénom')));
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.fillColor,
        isNull,
      );
    });

    testWidgets('button tones: quiet Réinitialiser, white Précédent, tonal '
        'Suivant, solid Enregistrer', (tester) async {
      await _open(tester, isDirty: true, onReset: () {});
      ButtonStyle? styleOf(String label) =>
          tester.widget<ButtonStyleButton>(_button(label).first).style;

      expect(styleOf('Suivant')!.backgroundColor!.resolve(_none)!.a,
          lessThan(0.5));

      await _tap(tester, 'Suivant');
      final cancel = styleOf('Réinitialiser')!;
      expect(cancel.foregroundColor?.resolve(_none), const Color(0xFF777777));
      expect(cancel.side?.resolve(_none), BorderSide.none);
      // White from the start — at rest, on hover, and while disabled.
      expect(cancel.backgroundColor?.resolve(_none), Colors.white);
      expect(
        cancel.backgroundColor?.resolve(const {WidgetState.hovered}),
        Colors.white,
      );
      expect(
        cancel.backgroundColor?.resolve(const {WidgetState.disabled}),
        Colors.white,
      );
      final previous = styleOf('Précédent')!;
      expect(previous.backgroundColor?.resolve(_none), Colors.white);
      expect(previous.side?.resolve(_none), BorderSide.none);

      await _tap(tester, 'Suivant');
      // Enregistrer takes the theme's solid teal (no override).
      expect(styleOf('Enregistrer'), isNull);
    });

    testWidgets('full screen on a phone, without the paragraph', (
      tester,
    ) async {
      await _open(tester, size: const Size(390, 844));

      expect(tester.takeException(), isNull);
      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.text('Trois étapes.'), findsNothing);
      expect(find.text('Étape 1 sur 3 · Infos'), findsOneWidget);
      final dialog = tester.getRect(find.byType(Dialog));
      expect(dialog.width, 390);
    });

    testWidgets('on a phone every action stays on one line', (tester) async {
      await _open(
        tester,
        size: const Size(390, 844),
        isDirty: true,
        freeNavigation: true,
        onReset: () {},
      );
      // Step 2, so Précédent is there too (the compact indicator on a phone
      // has no steps to tap).
      await tester.tap(find.byKey(const ValueKey('wizard-next')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Réinitialiser, Précédent, Suivant, Enregistrer — one row.
      final ys = [
        for (final key in ['wizard-reset', 'wizard-previous', 'wizard-next'])
          tester.getCenter(find.byKey(ValueKey(key))).dy,
        tester.getCenter(_button('Enregistrer').first).dy,
      ];
      expect(ys.every((y) => (y - ys.first).abs() < 1), isTrue);
    });
  });
}
