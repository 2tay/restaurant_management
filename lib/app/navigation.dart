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
/// Marks content shown inside a slide-in drawer, and how to close it.
///
/// A drawer is a dialog on the root navigator; the store's screens are pushed
/// onto the shell's navigator, *underneath* it. A link inside a drawer that
/// simply pushed would open its page behind the drawer, out of sight. So
/// [AppNavigation.goSection] and [AppNavigation.pushScreen] look for this
/// first and close the drawer before they navigate — every drawer gets that
/// for free, and the content inside needs to know nothing about where it is
/// shown.
class DrawerScope extends InheritedWidget {
  const DrawerScope({required this.close, required super.child, super.key});

  /// Dismisses the drawer this content is in.
  final VoidCallback close;

  static DrawerScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DrawerScope>();

  @override
  bool updateShouldNotify(DrawerScope oldWidget) => false;
}

extension AppNavigation on BuildContext {
  /// Switch to a root section. Clears anything pushed on top of it.
  void goSection(String path) {
    // The router first: once the drawer closes, this context is gone.
    final router = GoRouter.of(this);
    DrawerScope.maybeOf(this)?.close();
    router.go(path);
  }

  /// Open a screen the user will come back from.
  void pushScreen(String path) {
    final router = GoRouter.of(this);
    DrawerScope.maybeOf(this)?.close();
    router.push(path);
  }

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
/// The label names the destination — "Retour à Produits" — so a user
/// mid-service knows where back goes without having to remember how they got
/// here.
///
/// Both fields are the *fallback*: the parent in the hierarchy, used when there
/// is nothing to pop. When there is, back pops, and the control is labelled
/// with the screen it pops to instead — see [BackHistory].
@immutable
class BackDestination {
  const BackDestination({required this.label, required this.path});

  /// The parent's name, e.g. "Produits".
  final String label;

  /// Where to go when there is nothing to pop.
  final String path;
}

/// Which screen each route was pushed over, and what that screen is called.
///
/// Back pops, so it returns to wherever the user came from — the dashboard, a
/// search, an alert. A label fixed per page could only name the hierarchy's
/// parent: a product opened from the dashboard said "Retour à Produits" and
/// then went to the dashboard. This records the real predecessor as routes are
/// pushed, so the label and the action agree.
///
/// Attached to the shell's navigator, where every store-scoped screen lives.
/// Titles come from [ShellPage], which registers its own on build.
class BackHistory extends NavigatorObserver {
  static final Expando<Route<dynamic>> _previous = Expando('previous');
  static final Expando<String> _titles = Expando('title');

  /// Records [title] as what [route]'s screen is called.
  static void registerTitle(Route<dynamic> route, String title) {
    _titles[route] = title;
  }

  /// The title of the screen [route] will pop back to, if it has one.
  static String? previousTitle(Route<dynamic> route) {
    final previous = _previous[route];
    // A `go` can clear the stack under a screen it keeps; the screen recorded
    // beneath it is then gone, and back no longer leads there.
    if (previous == null || !previous.isActive) return null;
    return _titles[previous];
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _previous[route] = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    // The replacement pops to wherever the screen it replaced would have.
    if (newRoute != null && oldRoute != null) {
      _previous[newRoute] = _previous[oldRoute];
    }
  }
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
