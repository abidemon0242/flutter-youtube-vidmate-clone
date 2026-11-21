import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/feed_repository.dart';
import 'providers/downloads_provider.dart';
import 'providers/playback_settings.dart';
import 'providers/theme_controller.dart';
import 'services/device_storage_service.dart';
import 'services/download_notification_service.dart';
import 'services/local_file_manager_service.dart';
import 'services/media_session_service.dart';
import 'services/network_monitor.dart';
import 'services/youtube_extraction_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read the saved theme first (at most 1 second) so the app doesn't flash the wrong theme.
  final theme = await ThemeController.load();
  final playbackSettings = await PlaybackSettings.load();

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

  // Show the UI immediately; services finish setting up in the background and
  // each one is awaited lazily by the code that needs it.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ChangeNotifierProvider<PlaybackSettings>.value(value: playbackSettings),
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
