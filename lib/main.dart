import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/mock_youtube_repository.dart';
import 'providers/downloads_provider.dart';
import 'services/ad_blocker_service.dart';
import 'services/background_download_service.dart';
import 'services/local_file_manager_service.dart';
import 'services/media_session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await _initializeServices();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        Provider(create: (_) => MockYouTubeRepository()),
        Provider(create: (_) => AdBlockerService()),
        Provider(create: (_) => BackgroundDownloadService()),
        Provider(create: (_) => LocalFileManagerService()),
        Provider(create: (_) => MediaSessionService()),
      ],
      child: const TubeArenaApp(),
    ),
  );
}

Future<void> _initializeServices() async {
  try {
    // Initialize background download service
    await BackgroundDownloadService().initialize();

    // Initialize media session for lock-screen controls
    await MediaSessionService().initialize();

    // Initialize local file manager
    await LocalFileManagerService().initialize();
  } catch (e) {
    debugPrint('Service initialization warning: $e');
  }
}
