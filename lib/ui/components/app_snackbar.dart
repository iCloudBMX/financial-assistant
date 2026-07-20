import 'dart:async';

import 'package:flutter/material.dart';

/// Shows a [SnackBar] that is guaranteed to dismiss itself.
///
/// The Material framework auto-hides a SnackBar with a `Timer` that it only
/// arms from `ScaffoldMessengerState.build` once the reveal animation reports
/// `completed`. In this app's shell (a root `ScaffoldMessenger` above a
/// `StatefulShellRoute` with nested navigators, snackbars shown right after a
/// modal bottom sheet pops) that timer was observed to never arm, leaving the
/// snackbar on screen indefinitely — plain `Timer`/`Future.delayed` still fire
/// fine, so we drive the dismissal ourselves as a reliable backstop.
///
/// The backstop timer is cancelled as soon as the snackbar closes by any other
/// means (the framework's own timer, the user tapping its action, or a newer
/// snackbar replacing it), so it never hides an unrelated later snackbar and
/// never leaks a pending timer.
extension AppSnackBarMessenger on ScaffoldMessengerState {
  void showAutoDismissSnackBar(SnackBar snackBar) {
    final controller = showSnackBar(snackBar);
    // A small margin over the display duration so the framework's own timer
    // wins when it does work, and we only step in when it silently doesn't.
    final timer = Timer(
      snackBar.duration + const Duration(milliseconds: 400),
      () {
        if (mounted) hideCurrentSnackBar();
      },
    );
    controller.closed.then((_) => timer.cancel());
  }
}
