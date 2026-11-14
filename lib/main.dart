import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/youtube_repository.dart';
import 'providers/downloads_provider.dart';
import 'providers/theme_provider.dart';
import 'services/background_download_service.dart';
import 'services/local_file_manager_service.dart';
import 'services/media_session_service.dart';
import 'services/google_auth_service.dart';
import 'services/personalization_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeServices();

  final profile = PersonalizationService();
  await profile.initialize();
  final googleAuth = GoogleAuthService();
  await googleAuth.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => DownloadsProvider()..initialize(),
        ),
        ChangeNotifierProvider<PersonalizationService>.value(value: profile),
        ChangeNotifierProvider<GoogleAuthService>.value(value: googleAuth),
        Provider(create: (_) => YouTubeRepository()),
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
    await BackgroundDownloadService().initialize();
  } catch (error, stackTrace) {
    debugPrint(
      'Background download initialization failed: $error\n$stackTrace',
    );
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
