import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:logger/logger.dart';
import 'package:video_player/video_player.dart';

/// Bridges a [VideoPlayerController] to the Android media session, so the
/// notification, lock screen and headset buttons control the real player.
class TubeArenaAudioHandler extends BaseAudioHandler with SeekHandler {
  VideoPlayerController? _controller;
  void Function()? _listener;
  ({bool playing, AudioProcessingState state, Duration position, DateTime at})? _last;

  void attach(VideoPlayerController controller, MediaItem item) {
    detach();
    _controller = controller;
    mediaItem.add(item);
    _listener = _broadcast;
    controller.addListener(_listener!);
    _broadcast();
  }

  void detach() {
    final controller = _controller;
    if (controller != null && _listener != null) controller.removeListener(_listener!);
    _controller = null;
    _listener = null;
    _last = null;
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle));
  }

  bool isAttachedTo(VideoPlayerController controller) => identical(_controller, controller);

  void _broadcast() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    final duration = value.duration;
    if (duration > Duration.zero && mediaItem.value?.duration != duration) {
      mediaItem.add(mediaItem.value?.copyWith(duration: duration));
    }
    final ended = value.isInitialized && duration > Duration.zero && value.position >= duration;
    final state = !value.isInitialized
        ? AudioProcessingState.loading
        : value.isBuffering
        ? AudioProcessingState.buffering
        : ended
        ? AudioProcessingState.completed
        : AudioProcessingState.ready;
    // The player notifies many times per second. Android extrapolates the
    // position while playing, so only publish when something changes:
    // play/pause, buffering/ended, or a seek (position off by > 1.5 s).
    final now = DateTime.now();
    final last = _last;
    if (last != null && last.playing == value.isPlaying && last.state == state) {
      final expected = last.position + (last.playing ? now.difference(last.at) : Duration.zero);
      if ((value.position - expected).abs() < const Duration(milliseconds: 1500)) return;
    }
    _last = (playing: value.isPlaying, state: state, position: value.position, at: now);
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.rewind,
          value.isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: state,
        playing: value.isPlaying,
        updatePosition: value.position,
        bufferedPosition: value.buffered.isEmpty ? Duration.zero : value.buffered.last.end,
      ),
    );
  }

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> seek(Duration position) async => _controller?.seekTo(position);

  @override
  Future<void> rewind() async {
    final c = _controller;
    if (c != null) await c.seekTo(c.value.position - const Duration(seconds: 10));
  }

  @override
  Future<void> fastForward() async {
    final c = _controller;
    if (c != null) await c.seekTo(c.value.position + const Duration(seconds: 10));
  }

  @override
  Future<void> stop() async {
    await _controller?.pause();
    detach();
    await super.stop();
  }
}

class MediaSessionService {
  MediaSessionService._internal();
  static final MediaSessionService _instance = MediaSessionService._internal();
  factory MediaSessionService() => _instance;

  final _logger = Logger();
  TubeArenaAudioHandler? _handler;
  Future<void>? _init;

  /// Safe to call many times; never throws. Times out instead of blocking.
  Future<void> initialize() => _init ??= _initialize();

  Future<void> _initialize() async {
    try {
      _handler = await AudioService.init(
        builder: TubeArenaAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.tubearena.audio',
          androidNotificationChannelName: 'Tube Arena Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      ).timeout(const Duration(seconds: 10));
      _logger.i('Media session ready');
    } catch (error) {
      _logger.w('Media session unavailable: $error');
    }
  }

  TubeArenaAudioHandler? get handler => _handler;

  Future<void> attach(
    VideoPlayerController controller, {
    required String id,
    required String title,
    required String artist,
    String? artUri,
  }) async {
    await initialize();
    _handler?.attach(
      controller,
      MediaItem(
        id: id,
        title: title,
        artist: artist,
        artUri: artUri == null || artUri.isEmpty ? null : Uri.tryParse(artUri),
      ),
    );
  }

  void detach(VideoPlayerController controller) {
    final handler = _handler;
    if (handler != null && handler.isAttachedTo(controller)) handler.detach();
  }
}
