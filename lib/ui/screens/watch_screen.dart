import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../models/video_model.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key, required this.video});

  final VideoModel video;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  late final VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _playerReady = false;
  bool _playerFailed = false;
  bool _saved = false;

  Future<void> _share() async {
    await Share.share('${widget.video.title} — ${widget.video.channelName}');
  }

  void _openDownloads() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This feed uses demonstration videos. Paste a media link you own or are authorized to save.')),
    );
    context.push('/add-downloads');
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.playbackUrl));
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _controller.initialize();
      if (mounted) setState(() => _playerReady = true);
    } catch (_) {
      if (mounted) setState(() => _playerFailed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
              aspectRatio: _playerReady && _controller.value.aspectRatio > 0
                  ? _controller.value.aspectRatio
                  : 16 / 9,
              child: Container(
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: _playerFailed
                    ? const Center(child: Text('Could not load this demo video', style: TextStyle(color: Colors.white)))
                    : !_playerReady
                        ? const Center(child: CircularProgressIndicator())
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_controller),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: VideoProgressIndicator(
                                  _controller,
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
                                  if (_controller.value.isPlaying) {
                                    await _controller.pause();
                                  } else {
                                    await _controller.play();
                                  }
                                  if (mounted) setState(() => _isPlaying = _controller.value.isPlaying);
                                },
                                iconSize: 42,
                                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),
            Text(video.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${video.channelName} • ${video.views}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ActionChip(label: const Text('Like'), avatar: const Icon(Icons.thumb_up_outlined, size: 18), onPressed: () => _notice('Likes are not connected to an account in this demo.')),
                ActionChip(label: const Text('Share'), avatar: const Icon(Icons.share_outlined, size: 18), onPressed: _share),
                ActionChip(label: const Text('Add download'), avatar: const Icon(Icons.download_rounded, size: 18), onPressed: _openDownloads),
                ActionChip(label: Text(_saved ? 'Saved' : 'Save'), avatar: Icon(_saved ? Icons.bookmark : Icons.bookmark_border, size: 18), onPressed: () => setState(() => _saved = !_saved)),
              ],
            ),
            const SizedBox(height: 24),
            Row(children: [
              CircleAvatar(backgroundImage: NetworkImage(video.channelAvatar)),
              const SizedBox(width: 12),
              Expanded(child: Text(video.channelName, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 20),
            const Text('This prototype uses mock feed data and a sample video stream.'),
          ],
        ),
      ),
    );
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
