import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/feed_repository.dart';
import 'providers/downloads_provider.dart';
import 'providers/playback_settings.dart';
import 'providers/recommendation_settings.dart';
import 'providers/theme_controller.dart';
import 'services/device_storage_service.dart';
import 'services/download_notification_service.dart';
import 'services/google_auth_service.dart';
import 'services/local_file_manager_service.dart';
import 'services/media_session_service.dart';
import 'services/network_monitor.dart';
import 'services/youtube_extraction_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize authentication before the first frame so a restored Firebase
  // session can enter the app directly; otherwise the mandatory login is shown.
  final googleAuth = GoogleAuthService();
  await googleAuth.initialize();

  // Receive Firebase email sign-in links whether the app is already running or cold-started.
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    unawaited(
      googleAuth.completeEmailSignInLink(uri.toString()).catchError((Object error) {
        debugPrint('Email-link sign-in failed: $error');
      }),
    );
  });
  final initialLink = await appLinks.getInitialLink();
  if (initialLink != null) {
    unawaited(
      googleAuth.completeEmailSignInLink(initialLink.toString()).catchError((Object error) {
        debugPrint('Initial email-link sign-in failed: $error');
      }),
    );
  }

  // Read the saved theme first (at most 1 second) so the app doesn't flash the wrong theme.
  final theme = await ThemeController.load();
  final playbackSettings = await PlaybackSettings.load();
  final recommendationSettings = await RecommendationSettings.load();

  final youtube = YoutubeExtractionService();
  final fileManager = LocalFileManagerService();
  final mediaSession = MediaSessionService();
  final storage = DeviceStorageService();
  final downloads = DownloadsProvider(
    source: YoutubeDownloadSource(youtube),
    freeSpace: storage.freeBytes,
    network: ConnectivityNetworkMonitor(),
  );
  // Mirrors download progress into a notification + foreground service.
  DownloadNotificationController(downloads, MethodChannelDownloadNotifier());

  // Show the UI immediately; remaining services finish setting up in the background.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ChangeNotifierProvider<PlaybackSettings>.value(value: playbackSettings),
        ChangeNotifierProvider<RecommendationSettings>.value(value: recommendationSettings),
        ChangeNotifierProvider<GoogleAuthService>.value(value: googleAuth),
        Provider<YoutubeExtractionService>.value(value: youtube),
        Provider<FeedRepository>(create: (_) => FeedRepository(youtube)),
        ChangeNotifierProvider<DownloadsProvider>.value(value: downloads),
        Provider<LocalFileManagerService>.value(value: fileManager),
        Provider<MediaSessionService>.value(value: mediaSession),
        Provider<DeviceStorageService>.value(value: storage),
      ],
      child: const TubeArenaApp(),
    ),
  );

  unawaited(_initializeInBackground(fileManager, downloads, mediaSession));
}

Future<void> _initializeInBackground(
  LocalFileManagerService fileManager,
  DownloadsProvider downloads,
  MediaSessionService mediaSession,
) async {
  try {
    await fileManager.initialize();
  } catch (error) {
    debugPrint('Storage setup failed: $error');
  }
  await downloads.load();
  await mediaSession.initialize();
}
