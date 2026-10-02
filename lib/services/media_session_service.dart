import 'package:audio_service/audio_service.dart';
import 'package:logger/logger.dart';

class TubeArenaAudioHandler extends BaseAudioHandler with SeekHandler {
  final logger = Logger();

  TubeArenaAudioHandler() {
    _loadEmptyPlaylist();
  }

  void _loadEmptyPlaylist() {
    queue.add([]);
  }

  @override
  Future<void> play() async {
    logger.i('Audio playback started');
    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
        updatePosition: Duration.zero,
      ),
    );
  }

  @override
  Future<void> pause() async {
    logger.i('Audio playback paused');
    playbackState.add(
      playbackState.value.copyWith(playing: false),
    );
  }

  @override
  Future<void> stop() async {
    logger.i('Audio playback stopped');
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    logger.i('Seek to position: $position');
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: position,
      ),
    );
  }

  /// Update media metadata for lock screen display
  void updateMediaMetadata({
    required String title,
    required String artist,
    required String? artUri,
    required Duration duration,
  }) {
    mediaItem.add(
      MediaItem(
        id: title,
        album: artist,
        title: title,
        artist: artist,
        duration: duration,
        artUri: artUri != null ? Uri.parse(artUri) : null,
      ),
    );
  }
}

class MediaSessionService {
  static final MediaSessionService _instance = MediaSessionService._internal();
  final logger = Logger();
  TubeArenaAudioHandler? _audioHandler;

  factory MediaSessionService() {
    return _instance;
  }

  MediaSessionService._internal();

  /// Initialize media session for lock-screen controls
  /// Must be called during app initialization
  Future<void> initialize() async {
    try {
      logger.i('Initializing MediaSessionService...');

      _audioHandler = await AudioService.init(
        builder: () => TubeArenaAudioHandler(),
        config: const AudioServiceConfig(
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

  /// Get the audio handler
  TubeArenaAudioHandler? get audioHandler => _audioHandler;

  /// Update lock-screen media info
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

  /// Play/resume from lock screen
  Future<void> playFromLockScreen() async {
    await _audioHandler?.play();
  }

  /// Pause from lock screen
  Future<void> pauseFromLockScreen() async {
    await _audioHandler?.pause();
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    await _audioHandler?.stop();
  }
}
