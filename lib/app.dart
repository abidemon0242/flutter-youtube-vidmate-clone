import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'models/video_model.dart';
import 'ui/screens/downloads_screen.dart';
import 'ui/screens/batch_download_screen.dart';
import 'ui/screens/folder_contents_screen.dart';
import 'ui/screens/local_media_player_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/watch_screen.dart';

class TubeArenaApp extends StatelessWidget {
  const TubeArenaApp({super.key});

  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/add-downloads', builder: (context, state) => const BatchDownloadScreen()),
      GoRoute(path: '/local-player', builder: (context, state) => LocalMediaPlayerScreen(filePath: state.extra as String)),
      GoRoute(
        path: '/watch',
        builder: (context, state) {
          final video = state.extra;
          return WatchScreen(video: video is VideoModel ? video : VideoModel.demo);
        },
      ),
      GoRoute(path: '/downloads', builder: (context, state) => const DownloadsScreen()),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
        routes: [
          GoRoute(
            path: ':folder',
            builder: (context, state) => FolderContentsScreen(
              folderName: state.pathParameters['folder']!,
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Tube Arena',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      );
}