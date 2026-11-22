import 'package:material_ui/material_ui.dart';

import '../../models/video_model.dart';
import '../widgets/download_options_sheet.dart';
import 'watch_screen.dart';

/// Full-screen vertical feed for the Shorts section.
///
/// The underlying player is reused so quality selection, playback speed,
/// hold-to-2x and media controls remain consistent with the regular player.
class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key, required this.videos});

  final List<VideoModel> videos;

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Shorts'),
        ),
        body: const Center(
          child: Text('No Shorts found.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          final video = widget.videos[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              WatchScreen(
                key: ValueKey('short-${video.id}'),
                video: video,
                immersive: true,
                autoplay: index == _index,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close Shorts',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const Text(
                        'Shorts',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '${index + 1} / ${widget.videos.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 76,
                bottom: 28,
                child: SafeArea(
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          video.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          video.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        if (video.metaLine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(video.metaLine, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (video.isYoutube)
                Positioned(
                  right: 12,
                  bottom: 42,
                  child: SafeArea(
                    child: IconButton.filledTonal(
                      tooltip: 'Download Short',
                      onPressed: () => showDownloadOptionsSheet(context, video),
                      icon: const Icon(Icons.download_rounded),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
