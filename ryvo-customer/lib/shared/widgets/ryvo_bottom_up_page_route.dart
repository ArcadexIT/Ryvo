import 'package:flutter/material.dart';

/// Full-screen route that rises from the bottom and drops back down on close,
/// matching the Profile sub-screens (`_fullscreenPage` in the app router).
///
/// Use it for imperative pushes such as the payment options page, so the
/// transition is identical to the go_router based screens.
class RyvoBottomUpPageRoute<T> extends PageRouteBuilder<T> {
  RyvoBottomUpPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          fullscreenDialog: true,
          opaque: true,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        );
}
