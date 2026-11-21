import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';
import '../../models/video_model.dart';
import '../../services/media_session_service.dart';
import '../../services/youtube_extraction_service.dart';
import '../widgets/download_options_sheet.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key, required this.video});

  final VideoModel video;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _saved = false;
  bool _fullscreen = false;
  bool _showControls = true;
  Timer? _hideTimer;
  late final MediaSessionService _mediaSession = context.read<MediaSessionService>();

  static bool _askedForNotifications = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final video = widget.video;
      final VideoPlayerController controller;
      if (video.isLocal) {
        final file = File(video.localPath!);
        if (!await file.exists()) throw const YoutubeServiceException('This file is no longer on the device.');
        controller = VideoPlayerController.file(file);
      } else if (video.isYoutube) {
        final url = await context.read<YoutubeExtractionService>().playbackUrl(video.youtubeId!);
        if (url == null) {
          throw const YoutubeServiceException(
            'Streaming is not available for this video, but you can still download it.',
          );
        }
        controller = VideoPlayerController.networkUrl(url);
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(video.playbackUrl ?? VideoModel.samplePlaybackUrl));
      }
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onPlayerChanged);
      setState(() => _controller = controller);
      unawaited(_attachMediaSession(controller));
      await controller.play();
      _scheduleHide();
    } on YoutubeServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not play this video.');
    }
  }

  Future<void> _attachMediaSession(VideoPlayerController controller) async {
    if (!_askedForNotifications && Platform.isAndroid) {
      _askedForNotifications = true;
      try {
        await Permission.notification.request();
      } catch (_) {}
    }
    await _mediaSession.attach(
      controller,
      id: widget.video.id,
      title: widget.video.title,
      artist: widget.video.channelName,
      artUri: widget.video.thumbnailUrl,
    );
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  bool get _ended {
    final value = _controller?.value;
    if (value == null || !value.isInitialized || value.duration == Duration.zero) return false;
    return !value.isPlaying && value.position >= value.duration - const Duration(milliseconds: 300);
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (_ended) {
      await controller.seekTo(Duration.zero);
      await controller.play();
    } else if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    _scheduleHide();
  }

  Future<void> _seekBy(int seconds) async {
    final controller = _controller;
    if (controller == null) return;
    final target = controller.value.position + Duration(seconds: seconds);
    await controller.seekTo(target < Duration.zero ? Duration.zero : target);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    setState(() => _showControls = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) setState(() => _showControls = false);
    });
  }

  Future<void> _toggleFullscreen() async {
    final enter = !_fullscreen;
    setState(() => _fullscreen = enter);
    if (enter) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await _restoreSystemUi();
    }
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onPlayerChanged);
      _mediaSession.detach(controller);
      controller.dispose();
    }
    if (_fullscreen) _restoreSystemUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player();
    if (_fullscreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _toggleFullscreen();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: player),
        ),
      );
    }
    final video = widget.video;
    return Scaffold(
      appBar: AppBar(title: Text(video.isLocal ? 'Offline' : 'Watch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(20), child: player),
            const SizedBox(height: 16),
            Text(video.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              [video.channelName, video.metaLine].where((s) => s.isNotEmpty).join(' • '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (!video.isLocal)
                  ActionChip(
                    label: const Text('Download'),
                    avatar: const Icon(Icons.download_rounded, size: 18),
                    onPressed: () => showDownloadOptionsSheet(context, video),
                  ),
                ActionChip(
                  label: Text(_saved ? 'Saved' : 'Save'),
                  avatar: Icon(_saved ? Icons.bookmark : Icons.bookmark_border, size: 18),
                  onPressed: () => setState(() => _saved = !_saved),
                ),
              ],
            ),
            if (!video.isYoutube && !video.isLocal) ...[
              const SizedBox(height: 20),
              const Text(
                'This is a sample video. Open a YouTube video to stream or download it.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _player() {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final aspect = ready && controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9;
    return AspectRatio(
      aspectRatio: aspect,
      child: ColoredBox(
        color: Colors.black,
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _open, child: const Text('Try again')),
                    ],
                  ),
                ),
              )
            : !ready
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showControls ? setState(() => _showControls = false) : _scheduleHide(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller),
                    if (controller.value.isBuffering) const Center(child: CircularProgressIndicator()),
                    AnimatedOpacity(
                      opacity: _showControls || !controller.value.isPlaying ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: _controls(controller),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _controls(VideoPlayerController controller) {
    final value = controller.value;
    return Container(
      color: Colors.black38,
      child: Column(
        children: [
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Back 10 seconds',
                iconSize: 34,
                color: Colors.white,
                onPressed: () => _seekBy(-10),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                tooltip: _ended ? 'Replay' : (value.isPlaying ? 'Pause' : 'Play'),
                iconSize: 42,
                onPressed: _togglePlay,
                icon: Icon(_ended ? Icons.replay_rounded : (value.isPlaying ? Icons.pause : Icons.play_arrow)),
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: 'Forward 10 seconds',
                iconSize: 34,
                color: Colors.white,
                onPressed: () => _seekBy(10),
                icon: const Icon(Icons.forward_10_rounded),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  '${_fmt(value.position)} / ${_fmt(value.duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                  color: Colors.white,
                  onPressed: _toggleFullscreen,
                  icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                ),
              ],
            ),
          ),
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            colors: const VideoProgressColors(playedColor: AppColors.primaryStart, bufferedColor: Colors.white38),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) => YoutubeExtractionService.formatDuration(d);
}
