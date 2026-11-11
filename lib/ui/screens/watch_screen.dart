import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/constants/app_colors.dart';
import '../../models/video_model.dart';
import '../../services/personalization_service.dart';
import '../../services/media_session_service.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key, required this.video});

  final VideoModel video;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver {
  late final VideoPlayerController controller;
  YoutubePlayerController? youtubeController;
  StreamSubscription<YoutubePlayerValue>? _youtubeValueSubscription;
  StreamSubscription<YoutubeVideoState>? _youtubePositionSubscription;
  bool _youtubeMediaSessionReady = false;
  bool _youtubeMediaSessionStarting = false;
  late final PersonalizationService profile;
  late final MediaSessionService mediaSession;

  bool playing = false;
  bool ready = false;
  bool failed = false;
  bool saved = false;
  bool liked = false;
  Duration last = Duration.zero;
  int watched = 0;
  int _lastUiSecond = -1;

  Future<void> record(String type, {int seconds = 0}) =>
      profile.record(type: type, video: widget.video, seconds: seconds);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    profile = context.read<PersonalizationService>();
    mediaSession = context.read<MediaSessionService>();
    record('open');

    final videoId = _extractYouTubeVideoId(widget.video.playbackUrl);
    if (videoId != null) {
      youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          privacyEnhancedMode: true,
          strictRelatedVideos: true,
          interfaceLanguage: 'en',
          origin: 'https://www.youtube-nocookie.com',
        ),
      );
      _attachYoutubeMediaSession();
      controller = VideoPlayerController.networkUrl(
        Uri.parse(VideoModel.demoPlaybackUrl),
      );
    } else {
      final uri = Uri.tryParse(widget.video.playbackUrl);
      controller = VideoPlayerController.networkUrl(
        uri != null && uri.hasScheme && uri.host.isNotEmpty
            ? uri
            : Uri.parse(VideoModel.demoPlaybackUrl),
      );
    }
    controller.addListener(track);
    initialize();
  }

  void _attachYoutubeMediaSession() {
    final youtube = youtubeController;
    if (youtube == null) return;

    _youtubeValueSubscription = youtube.listen((value) {
      unawaited(_syncYoutubeMediaSession(value));
    });
    _youtubePositionSubscription = youtube.videoStateStream.listen((state) {
      unawaited(_syncYoutubePosition(state.position));
    });
  }

  Future<void> _syncYoutubeMediaSession(YoutubePlayerValue value) async {
    final youtube = youtubeController;
    if (!mounted || youtube == null) return;

    final durationSeconds = await youtube.duration;
    final currentSeconds = await youtube.currentTime;
    final duration = Duration(milliseconds: (durationSeconds * 1000).round());
    final position = Duration(milliseconds: (currentSeconds * 1000).round());
    final isPlaying = value.playerState == PlayerState.playing;

    if (!_youtubeMediaSessionReady && !_youtubeMediaSessionStarting) {
      _youtubeMediaSessionStarting = true;
      try {
        await mediaSession.setExternalVideoSession(
          title: widget.video.title,
          onPlay: () => youtube.playVideo(),
          onPause: () => youtube.pauseVideo(),
          onSeek: (target) => youtube.seekTo(
            seconds: target.inMilliseconds / 1000,
            allowSeekAhead: true,
          ),
          playing: isPlaying,
          position: position,
          duration: duration,
        );
        _youtubeMediaSessionReady = true;
      } catch (error) {
        debugPrint('YouTube media session connection failed: $error');
      } finally {
        _youtubeMediaSessionStarting = false;
      }
    } else if (_youtubeMediaSessionReady) {
      mediaSession.updateExternalVideoState(
        playing: isPlaying,
        position: position,
        duration: duration,
      );
    }

    if (mounted && playing != isPlaying) {
      setState(() => playing = isPlaying);
    }
  }

  Future<void> _syncYoutubePosition(Duration position) async {
    final youtube = youtubeController;
    if (!mounted || youtube == null || !_youtubeMediaSessionReady) return;

    final durationSeconds = await youtube.duration;
    final state = await youtube.playerState;
    mediaSession.updateExternalVideoState(
      playing: state == PlayerState.playing,
      position: position,
      duration: Duration(milliseconds: (durationSeconds * 1000).round()),
    );
  }

  void track() {
    if (!controller.value.isInitialized) return;
    final position = controller.value.position;
    final delta = position - last;
    if (controller.value.isPlaying &&
        delta.inSeconds > 0 &&
        delta.inSeconds <= 5) {
      watched += delta.inSeconds;
    }
    last = position;
    final positionSecond = position.inSeconds;
    if (mounted &&
        (playing != controller.value.isPlaying ||
            _lastUiSecond != positionSecond)) {
      _lastUiSecond = positionSecond;
      setState(() => playing = controller.value.isPlaying);
    }
    if (mounted && controller.value.isInitialized) {
      mediaSession.updateExternalVideoState(
        playing: controller.value.isPlaying,
        position: position,
        duration: controller.value.duration,
      );
    }
  }

  Future<void> _seekBy(int seconds) async {
    if (!controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final requested = controller.value.position + Duration(seconds: seconds);
    final target = requested < Duration.zero
        ? Duration.zero
        : requested > duration
        ? duration
        : requested;
    await controller.seekTo(target);
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  Future<void> _openFullscreen() async {
    if (!mounted || !controller.value.isInitialized) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    try {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (pageContext) => Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(controller),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    color: Colors.white,
                    onPressed: () => Navigator.of(pageContext).pop(),
                    icon: const Icon(Icons.close_fullscreen),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                  ),
                ),
                Center(
                  child: IconButton.filled(
                    onPressed: () async {
                      if (controller.value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                      if (mounted) {
                        setState(() => playing = controller.value.isPlaying);
                      }
                    },
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void flushWatchTime() {
    final seconds = watched;
    watched = 0;
    if (seconds > 0) record('watch', seconds: seconds);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      track();
      flushWatchTime();
    }
  }

  String? _extractYouTubeVideoId(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return null;
    final host = uri.host.toLowerCase();
    const hosts = {
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtu.be',
      'www.youtu.be',
    };
    if (!hosts.contains(host)) return null;
    String? id;
    if (host == 'youtu.be' || host == 'www.youtu.be') {
      id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else {
      id = uri.queryParameters['v'];
      if (id == null || id.isEmpty) {
        final segments = uri.pathSegments;
        if (segments.length >= 2 &&
            {'shorts', 'embed', 'live'}.contains(segments.first)) {
          id = segments[1];
        }
      }
    }
    return id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)
        ? id
        : null;
  }

  String? _downloadUrlFor(VideoModel video) {
    final uri = Uri.tryParse(video.playbackUrl);
    const youtubeHosts = {
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtu.be',
      'www.youtu.be',
    };

    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        youtubeHosts.contains(uri.host.toLowerCase())) {
      return uri.toString();
    }

    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(video.id)) {
      return 'https://www.youtube.com/watch?v=${video.id}';
    }
    return null;
  }

  Future<void> _openInYouTube() async {
    final url = widget.video.playbackUrl;
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> initialize() async {
    if (youtubeController != null) {
      if (mounted) setState(() => ready = true);
      return;
    }
    final uri = Uri.tryParse(widget.video.playbackUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (mounted) setState(() => failed = true);
      return;
    }

    if (_downloadUrlFor(widget.video) != null) {
      if (mounted) setState(() => failed = true);
      return;
    }

    try {
      await controller.initialize();
      if (mounted) {
        setState(() => ready = true);
        try {
          await mediaSession.setExternalVideoSession(
            title: widget.video.title,
            onPlay: () => controller.play(),
            onPause: () => controller.pause(),
            onSeek: (position) => controller.seekTo(position),
            playing: controller.value.isPlaying,
            position: controller.value.position,
            duration: controller.value.duration,
          );
        } catch (error) {
          debugPrint('Media session connection failed: $error');
        }
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> _openDownloadFlow() async {
    final url = _downloadUrlFor(widget.video);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This sample has no YouTube URL. Add an authorized media link on the next screen.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only download media you own or are authorized to save.',
          ),
        ),
      );
    }
    await context.push('/add-downloads', extra: url);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    track();
    flushWatchTime();
    controller.removeListener(track);
    mediaSession.clearExternalVideoSession();
    unawaited(_youtubeValueSubscription?.cancel() ?? Future<void>.value());
    unawaited(_youtubePositionSubscription?.cancel() ?? Future<void>.value());
    youtubeController?.close();
    controller.dispose();
    super.dispose();
  }

  Widget _buildPlayer() {
    if (youtubeController != null) {
      return Container(
        color: Colors.black,
        child: YoutubePlayer(
          controller: youtubeController!,
          aspectRatio: 16 / 9,
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'This video cannot be played inside the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _openInYouTube,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in YouTube'),
                  ),
                ],
              ),
            )
          : !ready
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.primaryStart,
                      bufferedColor: Colors.white54,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    tooltip: 'Open fullscreen',
                    onPressed: _openFullscreen,
                    color: Colors.white,
                    icon: const Icon(Icons.fullscreen),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        '${_formatTime(controller.value.position)} / ${_formatTime(controller.value.duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Back 10 seconds',
                      onPressed: () => _seekBy(-10),
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                    ),
                    IconButton.filled(
                      onPressed: () async {
                        if (controller.value.isPlaying) {
                          await controller.pause();
                        } else {
                          await controller.play();
                        }
                        if (mounted) {
                          setState(() => playing = controller.value.isPlaying);
                        }
                      },
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton(
                      tooltip: 'Forward 10 seconds',
                      onPressed: () => _seekBy(10),
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final isYouTube = youtubeController != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch'),
        actions: [
          if (isYouTube)
            IconButton(
              tooltip: 'Open in YouTube',
              onPressed: _openInYouTube,
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: _buildPlayer()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (video.channelAvatar.isNotEmpty)
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(video.channelAvatar),
                        )
                      else
                        const CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.person, size: 18),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          video.channelName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    video.views,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (isYouTube)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Playing with the official YouTube player. Ads and quality are controlled by YouTube.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openDownloadFlow,
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
