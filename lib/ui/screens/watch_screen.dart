import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../models/video_model.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key, this.video});

  final VideoModel? video;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  late final VideoPlayerController _controller;
  bool isPlaying = false;
  bool isLiked = false;
  bool isDisliked = false;
  bool isSaved = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
      ),
    )..initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object error) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _shareVideo() async {
    final title = widget.video?.title ?? 'Tube Arena sample video';
    final channel = widget.video?.channelName ?? 'Tube Arena Demo';
    await Share.share('$title — $channel');
  }

  void _showDownloadPicker() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The home feed contains demo videos only. Use Add video links to download videos you own or are authorized to save.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Player
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_controller.value.isInitialized)
                      VideoPlayer(_controller)
                    else
                      const Center(child: CircularProgressIndicator()),
                    if (!isPlaying)
                      FloatingActionButton(
                        onPressed: () {
                          _controller.play();
                          setState(() => isPlaying = true);
                        },
                        backgroundColor: AppColors.primaryStart,
                        child: const Icon(Icons.play_arrow),
                      )
                    else
                      FloatingActionButton(
                        onPressed: () {
                          _controller.pause();
                          setState(() => isPlaying = false);
                        },
                        backgroundColor: AppColors.primaryStart,
                        child: const Icon(Icons.pause),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title and Audio-Only Toggle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video?.title ?? 'Sample video preview',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.video == null
                            ? 'Tube Arena • Demo playback'
                            : '${widget.video!.channelName} • ${widget.video!.views}',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Audio-only playback is not implemented yet',
                  child: IconButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Audio-only playback is not available yet.')),
                    ),
                    icon: const Icon(Icons.headphones_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _actionPill(isLiked ? 'Liked' : 'Like', isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, () => setState(() { isLiked = !isLiked; if (isLiked) isDisliked = false; })),
                  _actionPill(isDisliked ? 'Disliked' : 'Dislike', isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined, () => setState(() { isDisliked = !isDisliked; if (isDisliked) isLiked = false; })),
                  _actionPill('Share', Icons.share_outlined, _shareVideo),
                  _actionPill('Download', Icons.download_rounded, _showDownloadPicker),
                  _actionPill(isSaved ? 'Saved' : 'Save', isSaved ? Icons.bookmark : Icons.bookmark_border_rounded, () => setState(() => isSaved = !isSaved)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Channel Info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(
                    widget.video?.channelAvatar ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video?.channelName ?? 'Tube Arena Demo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Demo channel',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: null,
                  child: Text('Subscribe'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            ExpansionTile(
              title: const Text('Description'),
              children: [
                Text(
                  widget.video == null
                      ? 'This is a sample playback preview. The home feed currently contains demonstration content, not a live video catalogue.'
                      : 'This is demonstration metadata for ${widget.video!.title}. The current player uses a sample video stream; it is not the original media for this card.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionPill(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.card,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
