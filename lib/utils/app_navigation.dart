import 'package:flutter/material.dart';
import 'package:luci_mobile/screens/main_screen.dart';

/// Replaces the current route with [MainScreen] with no page transition.
void goToMainWithoutTransition(BuildContext context) {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const MainScreen(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ),
  );
}
