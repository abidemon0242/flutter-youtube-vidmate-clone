import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class LocalMediaPlayerScreen extends StatefulWidget {
  const LocalMediaPlayerScreen({super.key, required this.filePath});

  final String filePath;

  @override
  State<LocalMediaPlayerScreen> createState() => _LocalMediaPlayerScreenState();
}

class _LocalMediaPlayerScreenState extends State<LocalMediaPlayerScreen> {
  static const _audioExtensions = {
    '.mp3', '.m4a', '.aac', '.wav', '.ogg', '.flac',
  };

  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  late final Future<void> _initialization;
  late final bool _isAudio;

  @override
  void initState() {
    super.initState();
    final extension = widget.filePath.contains('.')
        ? widget.filePath.substring(widget.filePath.lastIndexOf('.')).toLowerCase()
        : '';
    _isAudio = _audioExtensions.contains(extension);

    if (_isAudio) {
      _audioPlayer = AudioPlayer();
      _initialization = _audioPlayer!.setFilePath(widget.filePath).then((_) {});
    } else {
      _videoController = VideoPlayerController.file(File(widget.filePath));
      _videoController!.addListener(_refresh);
      _initialization = _videoController!.initialize();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.removeListener(_refresh);
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_fileName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('This media file could not be opened.'));
          }
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
    final value = position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              children: [
                IconButton(
                  onPressed: () => controller.value.isPlaying
                      ? controller.pause()
                      : controller.play(),
                  icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                Expanded(
                  child: Slider(
                    value: max <= 0 ? 0 : value,
                    max: max <= 0 ? 1 : max,
                    onChanged: (next) => controller.seekTo(
                      Duration(milliseconds: next.round()),
                    ),
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
                final value = position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
                return Column(
                  children: [
                    Slider(
                      value: max <= 0 ? 0 : value,
                      max: max <= 0 ? 1 : max,
                      onChanged: (next) => player.seek(
                        Duration(milliseconds: next.round()),
                      ),
                    ),
                    Text('${_formatDuration(position)} / ${_formatDuration(duration)}'),
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
