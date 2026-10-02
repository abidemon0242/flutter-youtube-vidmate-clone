import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  late final VideoPlayerController _controller;
  bool isAudioOnly = false;

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
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final options = [
          'MP3 · 128kbps',
          'MP3 · 320kbps',
          'M4A · 128kbps',
          'M4A · 320kbps',
          '360p · 5.3 MB',
          '480p · 9.4 MB',
          '720p · 18 MB',
          '1080p · 34 MB',
          '2K · 58 MB',
          '4K · 92 MB',
        ];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Download Quality',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ...options.map(
                (option) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option, style: const TextStyle(color: AppColors.white)),
                  leading: const Icon(Icons.download_rounded, color: AppColors.primaryStart),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected: $option')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tube Arena'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black,
                ),
                child: _controller.value.isInitialized
                    ? VideoPlayer(_controller)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Build a YouTube-like media app with beautiful UI and smart downloads',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: isAudioOnly,
                  onChanged: (value) => setState(() => isAudioOnly = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pillButton('Like', Icons.thumb_up_outlined),
                  _pillButton('Dislike', Icons.thumb_down_outlined),
                  _pillButton('Share', Icons.share_outlined),
                  _pillButton('Download', Icons.download_rounded, onTap: _showDownloadPicker),
                  _pillButton('Save', Icons.bookmark_border_rounded),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tube Arena is designed to blend YouTube-inspired UX with media downloads, offline library, folder organization, and batch actions.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, IconData icon, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap ?? () {},
        backgroundColor: AppColors.card,
        side: BorderSide.none,
      ),
    );
  }
}
