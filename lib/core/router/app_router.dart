import 'package:flutter/material.dart';

class AppRouter {
  static const home = '/';
  static const watch = '/watch';
  static const downloads = '/downloads';
  static const library = '/library';

  static Route<void> fadePage(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}
