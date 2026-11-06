import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../services/ffmpeg_merge_service.dart';
import '../../services/media_session_service.dart';

class LocalMediaPlayerScreen extends StatefulWidget {
  const LocalMediaPlayerScreen({super.key, required this.filePath});
  final String filePath;
  @override
  State<LocalMediaPlayerScreen> createState() => _LocalMediaPlayerScreenState();
}

class _LocalMediaPlayerScreenState extends State<LocalMediaPlayerScreen> {
  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
    '.flac',
    '.webm',
  };
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _ownsAudioPlayer = false;
  bool _isConverting = false;
  late final Future<void> _initialization;
  bool _isAudio = false;
  bool _isFullscreen = false;
  int _lastPositionSecond = -1;
  bool? _lastPlaying;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeMedia();
  }

  Future<void> _initializeMedia() async {
    final dot = widget.filePath.lastIndexOf('.');
    final extension = dot < 0
        ? ''
        : widget.filePath.substring(dot).toLowerCase();

    // WebM is a container, not an audio-only format. Probe its streams so
    // downloaded WebM videos are not incorrectly sent to the audio player.
    _isAudio = _audioExtensions.contains(extension) && extension != '.webm';
    if (extension == '.webm') {
      try {
        final probeSession = await FFprobeKit.getMediaInformation(
          widget.filePath,
        );
        final information = await probeSession.getMediaInformation();
        final streams = information?.getStreams() ?? const [];
        final hasVideo = streams.any((stream) => stream.getType() == 'video');
        final hasAudio = streams.any((stream) => stream.getType() == 'audio');
        _isAudio = hasAudio && !hasVideo;
      } catch (_) {
        // If probing fails, prefer the video player for ambiguous WebM files.
        _isAudio = false;
      }
    }

    if (_isAudio) {
      final handler = MediaSessionService().audioHandler;
      if (handler != null) {
        _audioPlayer = handler.player;
        await handler.setFilePath(widget.filePath, title: _fileName);
      } else {
        _audioPlayer = AudioPlayer();
        _ownsAudioPlayer = true;
        await _audioPlayer!.setFilePath(widget.filePath);
      }
    } else {
      _videoController = VideoPlayerController.file(File(widget.filePath));
      _videoController!.addListener(_refresh);
      await _videoController!.initialize();
      try {
        await MediaSessionService().setExternalVideoSession(
          title: _fileName,
          onPlay: () => _videoController!.play(),
          onPause: () => _videoController!.pause(),
          onSeek: (position) => _videoController!.seekTo(position),
          playing: _videoController!.value.isPlaying,
          position: _videoController!.value.position,
          duration: _videoController!.value.duration,
        );
      } catch (error) {
        debugPrint('Local video media-session connection failed: $error');
      }
    }
  }

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  Future<void> _seekBy(int seconds) async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final requested = controller.value.position + Duration(seconds: seconds);
    final milliseconds = requested.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toInt();
    await controller.seekTo(Duration(milliseconds: milliseconds));
  }

  Future<void> _toggleFullscreen() async {
    final entering = !_isFullscreen;
    if (mounted) setState(() => _isFullscreen = entering);
    try {
      if (entering) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]);
      }
    } catch (error) {
      if (mounted) setState(() => _isFullscreen = !entering);
      debugPrint('Could not change fullscreen mode: $error');
    }
  }

  void _refresh() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position;
    final playing = controller.value.isPlaying;
    final second = position.inSeconds;
    if (second == _lastPositionSecond && playing == _lastPlaying) return;
    _lastPositionSecond = second;
    _lastPlaying = playing;
    MediaSessionService().updateExternalVideoState(
      playing: playing,
      position: position,
      duration: controller.value.duration,
    );
    if (mounted) setState(() {});
  }

  Future<void> _convertToMp3() async {
    if (!_isAudio ||
        _isConverting ||
        widget.filePath.toLowerCase().endsWith('.mp3'))
      return;
    if (!await File(widget.filePath).exists()) return;
    final dot = widget.filePath.lastIndexOf('.');
    final base = dot < 0 ? widget.filePath : widget.filePath.substring(0, dot);
    final outputPath = '$base.mp3';
    if (await File(outputPath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An MP3 file with this name already exists.'),
        ),
      );
      return;
    }
    setState(() => _isConverting = true);
    final success = await FFmpegMergeService().extractAudio(
      videoPath: widget.filePath,
      audioOutputPath: outputPath,
      format: 'mp3',
    );
    if (!mounted) return;
    setState(() => _isConverting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'MP3 created: ${outputPath.split(Platform.pathSeparator).last}'
              : 'Could not convert this file to MP3.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.removeListener(_refresh);
    if (_videoController != null)
      MediaSessionService().clearExternalVideoSession();
    _videoController?.dispose();
    if (_ownsAudioPlayer) _audioPlayer?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFullscreen ? Colors.black : null,
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: Text(
                _fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (!_isAudio)
                  IconButton(
                    tooltip: 'Fullscreen',
                    onPressed: _toggleFullscreen,
                    icon: const Icon(Icons.fullscreen),
                  ),
                if (_isAudio && !widget.filePath.toLowerCase().endsWith('.mp3'))
                  IconButton(
                    tooltip: 'Convert to MP3',
                    onPressed: _isConverting ? null : _convertToMp3,
                    icon: _isConverting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.audio_file),
                  ),
              ],
            ),
      body: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return const Center(
              child: Text('This media file could not be opened.'),
            );
          return _isAudio ? _buildAudioPlayer() : _buildVideoPlayer();
        },
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final controller = _videoController!;
    final duration = controller.value.duration;
    final position = controller.value.position;
    final max = duration.inMilliseconds.toDouble();
    final value = position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_isFullscreen ? 4 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Back 10 seconds',
                  onPressed: () => _seekBy(-10),
                  icon: const Icon(Icons.replay_10),
                ),
                IconButton(
                  onPressed: () => controller.value.isPlaying
                      ? controller.pause()
                      : controller.play(),
                  icon: Icon(
                    controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                IconButton(
                  tooltip: 'Forward 10 seconds',
                  onPressed: () => _seekBy(10),
                  icon: const Icon(Icons.forward_10),
                ),
                IconButton(
                  tooltip: _isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                  onPressed: _toggleFullscreen,
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(_formatDuration(position)),
                Expanded(
                  child: Slider(
                    value: max <= 0 ? 0 : value,
                    max: max <= 0 ? 1 : max,
                    onChanged: (next) =>
                        controller.seekTo(Duration(milliseconds: next.round())),
                  ),
                ),
                Text(_formatDuration(duration)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    final player = _audioPlayer!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.audio_file_outlined, size: 88),
            const SizedBox(height: 16),
            Text(_fileName, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = player.duration ?? Duration.zero;
                final max = duration.inMilliseconds.toDouble();
                final value = position.inMilliseconds
                    .clamp(0, duration.inMilliseconds)
                    .toDouble();
                return Column(
                  children: [
                    Slider(
                      value: max <= 0 ? 0 : value,
                      max: max <= 0 ? 1 : max,
                      onChanged: (next) =>
                          player.seek(Duration(milliseconds: next.round())),
                    ),
                    Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    ),
                  ],
                );
              },
            ),
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return IconButton.filled(
                  iconSize: 36,
                  onPressed: () => playing ? player.pause() : player.play(),
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}
