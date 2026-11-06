import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/youtube_repository.dart';
import 'services/youtube_data_api_service.dart';
import 'providers/downloads_provider.dart';
import 'services/ad_blocker_service.dart';
import 'services/background_download_service.dart';
import 'services/local_file_manager_service.dart';
import 'services/media_session_service.dart';
import 'services/personalization_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeServices();

  final profile = PersonalizationService();
  await profile.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadsProvider()..initialize()),
        ChangeNotifierProvider<PersonalizationService>.value(value: profile),
        Provider(create: (_) => YouTubeRepository(api: YouTubeDataApiService())),
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
  // A failure in one optional service must not prevent the other services
  // from initializing. Each service owns its own recovery and error logging.
  try {
    await BackgroundDownloadService().initialize();
  } catch (error, stackTrace) {
    debugPrint('Background download initialization failed: $error\n$stackTrace');
  }

  try {
    await MediaSessionService().initialize();
  } catch (error, stackTrace) {
    debugPrint('Media session initialization failed: $error\n$stackTrace');
  }

  try {
    await LocalFileManagerService().initialize();
  } catch (error, stackTrace) {
    debugPrint('Local file manager initialization failed: $error\n$stackTrace');
  }
}
