import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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

class _WatchScreenState extends State<WatchScreen>
    with WidgetsBindingObserver {
  late final VideoPlayerController controller;
  late final PersonalizationService profile;

  bool playing = false;
  bool ready = false;
  bool failed = false;
  bool saved = false;
  bool liked = false;
  Duration last = Duration.zero;
  int watched = 0;

  Future<void> record(String type, {int seconds = 0}) =>
      profile.record(type: type, video: widget.video, seconds: seconds);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    profile = context.read<PersonalizationService>();
    record('open');

    final uri = Uri.tryParse(widget.video.playbackUrl);
    controller = VideoPlayerController.networkUrl(
      uri != null && uri.hasScheme && uri.host.isNotEmpty
          ? uri
          : Uri.parse(VideoModel.demoPlaybackUrl),
    );
    controller.addListener(track);
    initialize();
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
    final uri = Uri.tryParse(widget.video.playbackUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (mounted) setState(() => failed = true);
      return;
    }

    // YouTube results are handed to the official app/browser. The in-app
    // player is reserved for direct media URLs such as the bundled demo.
    if (_downloadUrlFor(widget.video) != null) {
      if (mounted) setState(() => failed = true);
      return;
    }

    try {
      await controller.initialize();
      if (mounted) {
        setState(() => ready = true);
        try {
          await context.read<MediaSessionService>().setExternalVideoSession(
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
    context.read<MediaSessionService>().clearExternalVideoSession();
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
              aspectRatio: ready && controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: Container(
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
                                final uri = Uri.tryParse(video.playbackUrl);
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
                              IconButton.filled(
                                onPressed: () async {
                                  if (controller.value.isPlaying) {
                                    await controller.pause();
                                  } else {
                                    await controller.play();
                                  }
                                  if (mounted) {
                                    setState(() {
                                      playing = controller.value.isPlaying;
                                    });
                                  }
                                },
                                icon: Icon(
                                  playing ? Icons.pause : Icons.play_arrow,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              video.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
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
                  onPressed: () => Share.share(
                    '${video.title} — ${video.channelName}',
                  ),
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
            const Text(
              'YouTube videos open in the official YouTube app or browser. '
              'Watch duration is tracked only for videos played inside Tube Arena.',
            ),
          ],
        ),
      ),
    );
  }
}
