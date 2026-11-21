import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/feed_repository.dart';
import 'providers/downloads_provider.dart';
import 'services/local_file_manager_service.dart';
import 'services/media_session_service.dart';
import 'services/youtube_extraction_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final youtube = YoutubeExtractionService();
  final fileManager = LocalFileManagerService();
  final mediaSession = MediaSessionService();
  final downloads = DownloadsProvider(source: YoutubeDownloadSource(youtube));

  // Show the UI immediately; services finish setting up in the background and
  // each one is awaited lazily by the code that needs it.
  runApp(
    MultiProvider(
      providers: [
        Provider<YoutubeExtractionService>.value(value: youtube),
        Provider<FeedRepository>(create: (_) => FeedRepository(youtube)),
        ChangeNotifierProvider<DownloadsProvider>.value(value: downloads),
        Provider<LocalFileManagerService>.value(value: fileManager),
        Provider<MediaSessionService>.value(value: mediaSession),
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
