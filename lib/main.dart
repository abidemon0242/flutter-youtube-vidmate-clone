import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/mock_youtube_repository.dart';
import 'providers/downloads_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        Provider(create: (_) => MockYouTubeRepository()),
      ],
      child: const TubeArenaApp(),
    ),
  );
}
