import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';

/// Page transitions for the shell routes.
///
/// A short fade with a small upward slide. It exists to say "this screen came
/// from that one" and nothing else — the user is mid-service, and anything
/// slower than about a fifth of a second reads as the app being sluggish
/// rather than as polish.
///
/// Collapses to an instant cut when the platform asks for reduced motion.
CustomTransitionPage<void> appPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;

      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.standard,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          // 12dp rather than a full screen width: the content area is a pane
          // inside a persistent shell, not a whole page replacing another, and
          // a large slide would fight the rail and top bar staying still.
          position: Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
