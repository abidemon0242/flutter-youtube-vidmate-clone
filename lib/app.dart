import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'models/video_model.dart';
import 'ui/screens/downloads_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/watch_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Tabs keep their own navigation stack and state (search, category,
    // scroll position) while switching between them.
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
    GoRoute(
      path: '/watch',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final video = state.extra;
        return WatchScreen(video: video is VideoModel ? video : VideoModel.demo);
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

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Tube Arena',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.dark,
    routerConfig: _router,
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    // Back on Downloads or Library returns to Home instead of closing the app.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.primaryStart,
          unselectedItemColor: AppColors.textSecondary,
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
