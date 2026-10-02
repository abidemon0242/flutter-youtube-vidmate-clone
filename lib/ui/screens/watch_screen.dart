import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';
import '../modals/download_quality_modal.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  late final VideoPlayerController _controller;
  bool isAudioOnly = false;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
      ),
    )..initialize().then((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showDownloadPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DownloadQualityModal(
        videoTitle: 'Sample Video Title',
        onDownloadAudio: (format, bitrate) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloading audio: $format $bitrate')),
          );
        },
        onDownloadVideo: (quality, format) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloading video: $quality $format')),
          );
        },
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
                      const Text(
                        'Build a YouTube-like media app with beautiful UI',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tube Arena • 2.4M views • 4 days ago',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => isAudioOnly = !isAudioOnly),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isAudioOnly ? AppColors.primaryStart : AppColors.card,
                    ),
                    child: Icon(
                      isAudioOnly ? Icons.volume_up : Icons.videocam,
                      color: isAudioOnly ? Colors.white : AppColors.textSecondary,
                    ),
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
                  _actionPill('Like', Icons.thumb_up_outlined, () {}),
                  _actionPill('Dislike', Icons.thumb_down_outlined, () {}),
                  _actionPill('Share', Icons.share_outlined, () {}),
                  _actionPill('Download', Icons.download_rounded, _showDownloadPicker),
                  _actionPill('Save', Icons.bookmark_border_rounded, () {}),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Channel Info
            const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(
                    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tube Arena Official',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '1.2M subscribers',
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
              children: const [
                Text(
                  'Tube Arena is a cross-platform media app built with Flutter, featuring YouTube-inspired UI, advanced download capabilities with multiple quality options, local library management, and a native ad-blocker.',
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
