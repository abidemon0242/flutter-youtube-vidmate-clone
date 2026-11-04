import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/repositories/mock_youtube_repository.dart';
import 'providers/downloads_provider.dart';
import 'services/ad_blocker_service.dart';
import 'services/background_download_service.dart';
import 'services/local_file_manager_service.dart';
import 'services/media_session_service.dart';
import 'services/personalization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeServices();
  final profile=PersonalizationService();
  await profile.initialize();
  runApp(MultiProvider(providers:[
    ChangeNotifierProvider(create:(_)=>DownloadsProvider()..initialize()),
    ChangeNotifierProvider<PersonalizationService>.value(value:profile),
    Provider(create:(_)=>MockYouTubeRepository(),dispose:(_,r)=>r.dispose()),
    Provider(create:(_)=>AdBlockerService()),
    Provider(create:(_)=>BackgroundDownloadService()),
    Provider(create:(_)=>LocalFileManagerService()),
    Provider(create:(_)=>MediaSessionService()),
  ],child:const TubeArenaApp()));
}
Future<void> _initializeServices() async {
  try{await BackgroundDownloadService().initialize();await MediaSessionService().initialize();await LocalFileManagerService().initialize();}
  catch(e){debugPrint('Service initialization warning: $e');}
}
