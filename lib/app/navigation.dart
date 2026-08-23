import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The app's navigation convention, in one place.
///
/// Phase 1 shipped with every navigation as `context.go()`, which *replaces*
/// the current location rather than stacking onto it. That is correct for
/// switching sections and wrong for everything else: it left the user on a
/// detail screen with nothing to go back to, because there was no stack.
///
/// The rule:
///
/// - [goSection] — the sidebar's nine destinations, and anything that means
///   "leave here entirely". Replaces the stack.
/// - [pushScreen] — anything the user is expected to come back from: detail
///   pages, forms, sub-reports. Stacks, so back works.
/// - [backTo] — pops when there is something to pop, and otherwise lands on a
///   sensible parent. The fallback matters: a deep link opens a screen with an
///   empty stack, and back still has to do something reasonable.
extension AppNavigation on BuildContext {
  /// Switch to a root section. Clears anything pushed on top of it.
  void goSection(String path) => go(path);

  /// Open a screen the user will come back from.
  void pushScreen(String path) => push(path);

  /// Go back one level.
  ///
  /// [fallback] is where to land when there is nothing on the stack — reached
  /// by deep link, or after a hot restart mid-navigation.
  void backTo(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }

  /// Replace the current screen rather than stacking on it.
  ///
  /// For a form that has finished: after saving an item, back should return to
  /// the list the user came from, not to the form they just completed.
  void replaceScreen(String path) {
    if (canPop()) pop();
    push(path);
  }
}

/// Where a screen's back control leads, and what it is called.
///
/// The label names the destination — "Retour à Inventaire" rather than a bare
/// arrow — so a user mid-service knows where back goes without having to
/// remember how they got here.
@immutable
class BackDestination {
  const BackDestination({required this.label, required this.path});

  /// The destination's name, e.g. "Inventaire".
  final String label;

  /// Where to go when there is nothing to pop.
  final String path;
}

/// One segment of a breadcrumb trail.
///
/// A null [path] marks the current screen, which is rendered as plain text
/// rather than a link.
@immutable
class Crumb {
  const Crumb(this.label, [this.path]);

  final String label;
  final String? path;

  bool get isCurrent => path == null;
}
