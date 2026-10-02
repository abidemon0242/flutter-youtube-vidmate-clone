import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/watch_screen.dart';
import 'ui/screens/downloads_screen.dart';
import 'ui/screens/library_screen.dart';

class TubeArenaApp extends StatelessWidget {
  const TubeArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/watch',
          builder: (context, state) => const WatchScreen(),
        ),
        GoRoute(
          path: '/downloads',
          builder: (context, state) => const DownloadsScreen(),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) => const LibraryScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Tube Arena',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
