import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

class TubeArenaAudioHandler extends BaseAudioHandler with SeekHandler {
  TubeArenaAudioHandler() {
    _player.playbackEventStream.listen(
      (_) => _broadcastPlaybackState(),
      onError: (Object error, StackTrace stackTrace) {
        _logger.e('Audio playback stream error', error: error, stackTrace: stackTrace);
      },
    );
    _player.playerStateStream.listen((_) => _broadcastPlaybackState());
    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final Logger _logger = Logger();
  Future<void> Function()? _externalPlay;
  Future<void> Function()? _externalPause;
  Future<void> Function(Duration)? _externalSeek;
  bool _externalMode = false;
  bool _externalPlaying = false;
  Duration _externalPosition = Duration.zero;
  Duration? _externalDuration;

  Future<void> setExternalVideoSession({
    required String title,
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function(Duration) onSeek,
    required bool playing,
    required Duration position,
    required Duration duration,
  }) async {
    _externalMode = true;
    _externalPlay = onPlay;
    _externalPause = onPause;
    _externalSeek = onSeek;
    _externalPlaying = playing;
    _externalPosition = position;
    _externalDuration = duration;
    mediaItem.add(MediaItem(
      id: 'tube-arena-video:$title',
      title: title,
      artist: 'Tube Arena',
      duration: duration,
    ));
    _broadcastPlaybackState();
  }

  void updateExternalVideoState({
    required bool playing,
    required Duration position,
    required Duration duration,
  }) {
    if (!_externalMode) return;
    _externalPlaying = playing;
    _externalPosition = position;
    _externalDuration = duration;
    _broadcastPlaybackState();
  }

  void clearExternalVideoSession() {
    _externalMode = false;
    _externalPlay = null;
    _externalPause = null;
    _externalSeek = null;
    _externalPlaying = false;
    _externalPosition = Duration.zero;
    _externalDuration = null;
    mediaItem.add(null);
    _broadcastPlaybackState();
  }

  AudioPlayer get player => _player;

  Future<void> setFilePath(String path, {String? title, String? artist}) async {
    final fileTitle = title ?? path.split('/').last;
    final duration = await _player.setFilePath(path);
    mediaItem.add(MediaItem(
      id: path,
      title: fileTitle,
      artist: artist ?? 'Tube Arena Library',
      duration: duration,
    ));
    _broadcastPlaybackState();
  }

  void _broadcastPlaybackState() {
    final state = _player.playerState;
    final processingState = _externalMode
        ? AudioProcessingState.ready
        : switch (state.processingState) {
            ProcessingState.idle => AudioProcessingState.idle,
            ProcessingState.loading => AudioProcessingState.loading,
            ProcessingState.buffering => AudioProcessingState.buffering,
            ProcessingState.ready => AudioProcessingState.ready,
            ProcessingState.completed => AudioProcessingState.completed,
          };
    final playing = _externalMode ? _externalPlaying : state.playing;
    playbackState.add(PlaybackState(
      controls: [
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1],
      processingState: processingState,
      playing: playing,
      updatePosition: _externalMode ? _externalPosition : _player.position,
      bufferedPosition: _externalMode ? _externalPosition : _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
    ));
  }

  @override
  Future<void> play() => _externalMode
      ? (_externalPlay?.call() ?? Future<void>.value())
      : _player.play();

  @override
  Future<void> pause() => _externalMode
      ? (_externalPause?.call() ?? Future<void>.value())
      : _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
    _broadcastPlaybackState();
  }

  @override
  Future<void> seek(Duration position) => _externalMode
      ? (_externalSeek?.call(position) ?? Future<void>.value())
      : _player.seek(position);

  @override
  Future<void> skipToNext() async {
    // A single local file is loaded at a time; there is no next queue item.
  }

  @override
  Future<void> skipToPrevious() async {
    await _player.seek(Duration.zero);
  }
}

class MediaSessionService {
  static final MediaSessionService _instance = MediaSessionService._internal();
  final Logger logger = Logger();
  TubeArenaAudioHandler? _audioHandler;
  Future<void>? _initialization;

  factory MediaSessionService() => _instance;
  MediaSessionService._internal();

  Future<void> initialize() {
    if (_audioHandler != null) return Future<void>.value();
    final existing = _initialization;
    if (existing != null) return existing;

    late final Future<void> attempt;
    attempt = _initialize().catchError((Object error, StackTrace stackTrace) {
      if (identical(_initialization, attempt)) {
        _initialization = null;
      }
      _audioHandler = null;
      logger.e('Error initializing media session', error: error, stackTrace: stackTrace);
    });
    _initialization = attempt;
    return attempt;
  }

  Future<void> _initialize() async {
    logger.i('Initializing MediaSessionService...');
    _audioHandler = await AudioService.init(
      builder: () => TubeArenaAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tubearena.audio',
        androidNotificationChannelName: 'Tube Arena Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );
    logger.i('MediaSessionService initialized successfully');
  }

  TubeArenaAudioHandler? get audioHandler => _audioHandler;

  Future<void> setLocalAudioFile(String path, {String? title}) async {
    final handler = _audioHandler;
    if (handler == null) throw StateError('Media session is not initialized.');
    await handler.setFilePath(path, title: title);
  }

  Future<void> playFromLockScreen() async => _audioHandler?.play();
  Future<void> pauseFromLockScreen() async => _audioHandler?.pause();
  Future<void> stopPlayback() async => _audioHandler?.stop();

  Future<void> setExternalVideoSession({
    required String title,
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function(Duration) onSeek,
    required bool playing,
    required Duration position,
    required Duration duration,
  }) async {
    await initialize();
    final handler = _audioHandler;
    if (handler == null) throw StateError('Media session is unavailable.');
    await handler.setExternalVideoSession(
      title: title,
      onPlay: onPlay,
      onPause: onPause,
      onSeek: onSeek,
      playing: playing,
      position: position,
      duration: duration,
    );
  }

  void updateExternalVideoState({
    required bool playing,
    required Duration position,
    required Duration duration,
  }) {
    _audioHandler?.updateExternalVideoState(
      playing: playing,
      position: position,
      duration: duration,
    );
  }

  void clearExternalVideoSession() => _audioHandler?.clearExternalVideoSession();
}
