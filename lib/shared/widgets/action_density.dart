import 'package:flutter/widgets.dart';

/// How much room a header's action buttons are allowed to take.
///
/// A page header hands [ShellPage] a `List<Widget>` of already-built buttons,
/// so the header cannot reach inside them to make them smaller. The size
/// decision travels the other way instead: the header publishes the density it
/// can afford, and each button decides what that means for it.
///
/// Anything outside a header sees [ActionDensity.full], so a button in a form,
/// a card or a dialog is unaffected.
enum ActionDensity {
  /// Icon and full label. The design baseline.
  full,

  /// Icon and the button's short label where it has one — "Associer" rather
  /// than "Associer un fournisseur". For a header on a portrait tablet, or in
  /// a detail pane beside a list.
  short,

  /// Icon only, with the label moved to a tooltip and a semantics label.
  ///
  /// Supporting actions only. `PrimaryButton` deliberately ignores this and
  /// falls back to [short]: the teal button is the answer to "what am I
  /// supposed to do on this screen?", and a header of three anonymous glyphs
  /// makes that a guessing game. A button with no icon falls back to [short]
  /// too — there would be nothing left to show.
  iconOnly,
}

/// Publishes an [ActionDensity] to the buttons beneath it.
class ActionDensityScope extends InheritedWidget {
  const ActionDensityScope({
    required this.density,
    required super.child,
    super.key,
  });

  final ActionDensity density;

  /// The density in force here. [ActionDensity.full] when nothing has set one.
  static ActionDensity of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ActionDensityScope>()
          ?.density ??
      ActionDensity.full;

  @override
  bool updateShouldNotify(ActionDensityScope oldWidget) =>
      oldWidget.density != density;
}
