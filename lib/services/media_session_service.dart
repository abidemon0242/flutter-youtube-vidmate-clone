import 'package:audio_service/audio_service.dart';
import 'package:logger/logger.dart';

class TubeArenaAudioHandler extends BaseAudioHandler with SeekHandler {
  final logger = Logger();

  TubeArenaAudioHandler() {
    queue.add([]);
  }

  @override
  Future<void> play() async {
    logger.i('Audio playback started');
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.ready,
      updatePosition: Duration.zero,
    ));
  }

  @override
  Future<void> pause() async {
    logger.i('Audio playback paused');
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> stop() async {
    logger.i('Audio playback stopped');
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    logger.i('Seek to position: $position');
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  void updateMediaMetadata({
    required String title,
    required String artist,
    required String? artUri,
    required Duration duration,
  }) {
    mediaItem.add(MediaItem(
      id: title,
      album: artist,
      title: title,
      artist: artist,
      duration: duration,
      artUri: artUri != null ? Uri.parse(artUri) : null,
    ));
  }
}

class MediaSessionService {
  static final MediaSessionService _instance = MediaSessionService._internal();
  final logger = Logger();
  TubeArenaAudioHandler? _audioHandler;

  factory MediaSessionService() => _instance;
  MediaSessionService._internal();

  Future<void> initialize() async {
    try {
      logger.i('Initializing MediaSessionService...');
      _audioHandler = await AudioService.init(
        builder: () => TubeArenaAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.tubearena.audio',
          androidNotificationChannelName: 'Tube Arena Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
        ),
      );
      logger.i('MediaSessionService initialized successfully');
    } catch (e) {
      logger.e('Error initializing media session: $e');
    }
  }

  TubeArenaAudioHandler? get audioHandler => _audioHandler;

  void updateLockScreenInfo({
    required String title,
    required String channelName,
    required String? thumbnailUrl,
    required Duration duration,
  }) {
    _audioHandler?.updateMediaMetadata(
      title: title,
      artist: channelName,
      artUri: thumbnailUrl,
      duration: duration,
    );
  }

  Future<void> playFromLockScreen() async => _audioHandler?.play();
  Future<void> pauseFromLockScreen() async => _audioHandler?.pause();
  Future<void> stopPlayback() async => _audioHandler?.stop();
}