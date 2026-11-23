import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/theme_controller.dart';
import 'services/google_auth_service.dart';
import 'models/video_model.dart';
import 'data/paged_feed.dart';
import 'ui/screens/downloads_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/watch_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/shorts_screen.dart';
import 'ui/screens/downloaded_shorts_screen.dart';
import 'ui/screens/onboarding_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (context, state) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/downloads', builder: (context, state) => const DownloadsScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
              routes: [
                GoRoute(
                  path: ':folder',
                  builder: (context, state) => LibraryFolderScreen(folderName: state.pathParameters['folder']!),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
      path: '/downloaded-shorts',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DownloadedShortsScreen(),
    ),
    GoRoute(
      path: '/shorts',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        final feed = extra is PagedFeed ? extra : PagedFeed.fixed(const []);
        return ShortsScreen(feed: feed);
      },
    ),
    GoRoute(
      path: '/watch',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        final video = extra is VideoModel ? extra : VideoModel.demo;
        return WatchScreen(key: ValueKey(video.id), video: video);
      },
    ),
  ],
);

class TubeArenaApp extends StatefulWidget {
  const TubeArenaApp({super.key});

  @override
  State<TubeArenaApp> createState() => _TubeArenaAppState();
}

class _TubeArenaAppState extends State<TubeArenaApp> {
  late final GoRouter _router = buildRouter();
  String? _lastAuthenticatedUid;

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeController>().mode;
    final googleAuth = context.watch<GoogleAuthService>();
    final user = googleAuth.currentUser;

    // Keep every app route inaccessible until Firebase confirms an account.
    // Signing out rebuilds this widget and replaces the router with login.
    if (user == null) {
      _lastAuthenticatedUid = null;
      return MaterialApp(
        title: 'Tube Arena',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const AppEntryScreen(),
      );
    }

    if (_lastAuthenticatedUid != user.uid) {
      _lastAuthenticatedUid = user.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && googleAuth.currentUser?.uid == user.uid) {
          _router.go('/');
        }
      });
    }

    return MaterialApp.router(
      title: 'Tube Arena',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: shell.currentIndex,
          onTap: _go,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.download_rounded), label: 'Downloads'),
            BottomNavigationBarItem(icon: Icon(Icons.video_library_rounded), label: 'Library'),
          ],
        ),
      ),
    );
  }
}
