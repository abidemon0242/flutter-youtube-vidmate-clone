import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/paged_feed.dart';
import '../../models/video_model.dart';
import '../../providers/recommendation_settings.dart';
import '../widgets/download_options_sheet.dart';
import 'watch_screen.dart';

/// Full-screen vertical feed for the Shorts section.
///
/// Uses the same paged search feed as Home so swiping near the end loads more
/// results. Inactive pages defer player initialization to avoid extra data use.
class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key, required this.feed});

  final PagedFeed feed;

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

  int? _durationSeconds(String value) {
    final parts = value.split(':');
    if (parts.isEmpty || parts.any((part) => int.tryParse(part) == null)) return null;
    return parts.map(int.parse).reduce((total, part) => total * 60 + part);
  }

  List<VideoModel> _visibleVideos(RecommendationSettings preferences) {
    final videos = widget.feed.items.where((video) {
      final seconds = _durationSeconds(video.duration);
      return seconds != null && seconds <= 180 && !preferences.isHidden(video.channelName);
    }).toList();
    videos.sort((a, b) {
      int score(VideoModel video) =>
          preferences.prefersMore(video.id) ? 2 : (preferences.prefersLess(video.id) ? -1 : 0);
      return score(b).compareTo(score(a));
    });
    return videos;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.feed,
      builder: (context, _) {
        final preferences = context.watch<RecommendationSettings>();
        final videos = _visibleVideos(preferences);
        if (videos.length < 3 && widget.feed.canAutoLoad) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.feed.canAutoLoad) unawaited(widget.feed.loadMore());
          });
        }
        if (videos.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text('Shorts'),
            ),
            body: Center(
              child: widget.feed.isLoading
                  ? const CircularProgressIndicator()
                  : widget.feed.hasMore
                  ? TextButton(
                      onPressed: widget.feed.loadMore,
                      child: const Text('Load Shorts', style: TextStyle(color: Colors.white)),
                    )
                  : const Text('No Shorts found.', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        if (_index >= videos.length) _index = videos.length - 1;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                scrollDirection: Axis.vertical,
                itemCount: videos.length,
                onPageChanged: (index) {
                  setState(() => _index = index);
                  if (index >= videos.length - 3 && widget.feed.canAutoLoad) {
                    unawaited(widget.feed.loadMore());
                  }
                },
                itemBuilder: (context, index) {
                  final video = videos[index];
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
                                '${index + 1} / ${videos.length}',
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
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
                      Positioned(
                        right: 12,
                        bottom: video.isYoutube ? 92 : 42,
                        child: SafeArea(
                          child: PopupMenuButton<String>(
                            tooltip: 'Short options',
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                            color: const Color(0xFF242424),
                            onSelected: (action) async {
                              switch (action) {
                                case 'more':
                                  await preferences.recordMore(video.id);
                                  break;
                                case 'less':
                                  await preferences.recordLess(video.id);
                                  break;
                                case 'subscribe':
                                  await preferences.toggleSubscription(
                                    video.channelName,
                                    channelId: video.channelId,
                                  );
                                  break;
                                case 'hide':
                                  await preferences.hideChannel(video.channelName);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'more', child: Text('Show more like this')),
                              const PopupMenuItem(value: 'less', child: Text('Show less like this')),
                              PopupMenuItem(
                                value: 'subscribe',
                                child: Text(
                                  preferences.isSubscribed(video.channelName, channelId: video.channelId)
                                      ? 'Unsubscribe'
                                      : 'Subscribe',
                                ),
                              ),
                              const PopupMenuItem(value: 'hide', child: Text('Don’t recommend this channel')),
                            ],
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
              if (widget.feed.isLoading)
                const Positioned(
                  top: 54,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (widget.feed.error != null)
                Positioned(
                  bottom: 8,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: TextButton(
                      onPressed: widget.feed.loadMore,
                      child: Text(
                        '${widget.feed.error}  Retry',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
