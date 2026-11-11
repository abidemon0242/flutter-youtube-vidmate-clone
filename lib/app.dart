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
import 'ui/screens/personalization_settings_screen.dart';
import 'ui/screens/playlist_import_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/watch_screen.dart';

class TubeArenaApp extends StatelessWidget {
  const TubeArenaApp({super.key});

  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
      GoRoute(
        path: '/add-downloads',
        builder: (c, s) {
          final extra = s.extra;
          final urls = extra is String
              ? [extra]
              : extra is List
              ? extra.whereType<String>().toList()
              : null;
          return BatchDownloadScreen(initialUrls: urls);
        },
      ),
      GoRoute(
        path: '/playlists',
        builder: (c, s) => const PlaylistImportScreen(),
      ),
      GoRoute(
        path: '/personalization',
        builder: (c, s) => const PersonalizationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (c, s) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/local-player',
        builder: (c, s) => LocalMediaPlayerScreen(filePath: s.extra as String),
      ),
      GoRoute(
        path: '/watch',
        builder: (c, s) {
          final v = s.extra;
          return WatchScreen(video: v is VideoModel ? v : VideoModel.demo);
        },
      ),
      GoRoute(path: '/downloads', builder: (c, s) => const DownloadsScreen()),
      GoRoute(
        path: '/library',
        builder: (c, s) => const LibraryScreen(),
        routes: [
          GoRoute(
            path: ':folder',
            builder: (c, s) =>
                FolderContentsScreen(folderName: s.pathParameters['folder']!),
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
