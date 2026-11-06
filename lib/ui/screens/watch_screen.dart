import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          privacyEnhancedMode: true,
          strictRelatedVideos: true,
          interfaceLanguage: 'en',
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

    // YouTube URLs are rendered by the official iframe player above. The
    // native Flutter player handles direct media URLs and local files.
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

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return Scaffold(
      appBar: AppBar(title: const Text('Watch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: youtubeController != null
                  ? 16 / 9
                  : ready && controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: youtubeController != null
                  ? YoutubePlayer(
                      controller: youtubeController!,
                      aspectRatio: 16 / 9,
                    )
                  : Container(
                      color: Colors.black,
                      child: failed
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'This video is hosted on YouTube or cannot be played here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final uri = Uri.tryParse(
                                        video.playbackUrl,
                                      );
                                      if (uri != null &&
                                          (uri.scheme == 'http' ||
                                              uri.scheme == 'https')) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open externally'),
                                  ),
                                ],
                              ),
                            )
                          : !ready
                          ? const Center(child: CircularProgressIndicator())
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Back 10 seconds',
                                      onPressed: () => _seekBy(-10),
                                      icon: const Icon(
                                        Icons.replay_10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    IconButton.filled(
                                      onPressed: () async {
                                        if (controller.value.isPlaying) {
                                          await controller.pause();
                                        } else {
                                          await controller.play();
                                        }
                                        if (mounted) {
                                          setState(
                                            () => playing =
                                                controller.value.isPlaying,
                                          );
                                        }
                                      },
                                      icon: Icon(
                                        playing
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Forward 10 seconds',
                                      onPressed: () => _seekBy(10),
                                      icon: const Icon(
                                        Icons.forward_10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    IconButton.filled(
                                      tooltip: 'Fullscreen',
                                      onPressed: _openFullscreen,
                                      icon: const Icon(Icons.fullscreen),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
            ),
            if (ready && youtubeController == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_formatTime(controller.value.position)} / ${_formatTime(controller.value.duration)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              video.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text('${video.channelName} • ${video.views}'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text(liked ? 'Liked' : 'Like'),
                  onPressed: () async {
                    final next = !liked;
                    setState(() => liked = next);
                    await record(next ? 'like' : 'unlike');
                  },
                ),
                ActionChip(
                  label: const Text('Share'),
                  onPressed: () =>
                      Share.share('${video.title} — ${video.channelName}'),
                ),
                ActionChip(
                  label: const Text('Add download'),
                  onPressed: _openDownloadFlow,
                ),
                ActionChip(
                  label: Text(saved ? 'Saved' : 'Save'),
                  onPressed: () async {
                    setState(() => saved = !saved);
                    await record(saved ? 'save' : 'unsave');
                  },
                ),
                ActionChip(
                  label: const Text('Not interested'),
                  onPressed: () => record('skip'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              youtubeController != null
                  ? 'Playing through YouTube’s official embedded player. YouTube manages playback quality; the app cannot force a specific YouTube stream.'
                  : 'Direct media playback is handled by Tube Arena. Watch duration is tracked locally when personalization is enabled.',
            ),
          ],
        ),
      ),
    );
  }
}
