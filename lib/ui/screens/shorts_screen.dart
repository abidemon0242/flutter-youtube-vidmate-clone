import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/paged_feed.dart';
import '../../models/video_model.dart';
import '../../providers/recommendation_settings.dart';
import '../../providers/downloads_provider.dart';
import '../../services/batch_download.dart';
import '../../services/youtube_extraction_service.dart';
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
  bool _selecting = false;
  bool _batchDownloading = false;
  int _batchDone = 0;
  final Set<String> _selectedVideoIds = {};

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

  Future<void> _chooseCount(List<VideoModel> videos) async {
    final controller = TextEditingController(text: '10');
    final count = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Shorts'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Number of Shorts to select'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0) Navigator.pop(dialogContext, value);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (count == null || !mounted) return;

    final preferences = context.read<RecommendationSettings>();
    while (_visibleVideos(preferences).where((video) => video.isYoutube).length < count && widget.feed.canAutoLoad) {
      try {
        await widget.feed.loadMore();
      } catch (_) {
        break;
      }
    }
    if (!mounted) return;
    final available = _visibleVideos(preferences).where((video) => video.isYoutube).toList();
    setState(() {
      _selecting = true;
      _selectedVideoIds
        ..clear()
        ..addAll(available.take(count).map((video) => video.id));
    });
    if (count > available.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only ${available.length} Shorts are currently available to select.')),
      );
    }
  }

  Future<int?> _chooseBatchQuality() => showDialog<int>(
    context: context,
    builder: (dialogContext) {
      var quality = 0;
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Batch download quality'),
          content: DropdownButtonFormField<int>(
            initialValue: quality,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Auto — recommended for each Short')),
              DropdownMenuItem(value: -1, child: Text('Highest available')),
              DropdownMenuItem(value: 144, child: Text('144p or closest available')),
              DropdownMenuItem(value: 240, child: Text('240p or closest available')),
              DropdownMenuItem(value: 360, child: Text('360p or closest available')),
              DropdownMenuItem(value: 480, child: Text('480p or closest available')),
              DropdownMenuItem(value: 720, child: Text('720p or closest available')),
              DropdownMenuItem(value: 1080, child: Text('1080p or closest available')),
            ],
            onChanged: (value) => setDialogState(() => quality = value ?? 0),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, quality), child: const Text('Continue')),
          ],
        ),
      );
    },
  );

  int _heightOf(DownloadOption option) =>
      int.tryParse(RegExp(r'^(\d+)').firstMatch(option.label)?.group(1) ?? '') ?? 0;

  DownloadOption? _batchOption(DownloadOptions options, int quality) {
    final available = options.video.where((option) => option.kind == DownloadKind.video).toList();
    if (available.isEmpty) return null;
    if (quality == 0) return options.recommended;
    available.sort((a, b) => _heightOf(b).compareTo(_heightOf(a)));
    if (quality == -1) return available.first;
    final atOrBelow = available.where((option) => _heightOf(option) <= quality).toList();
    return atOrBelow.isNotEmpty ? atOrBelow.first : available.last;
  }

  Future<void> _downloadSelected(List<VideoModel> videos) async {
    final selected = videos.where((video) => _selectedVideoIds.contains(video.id) && video.isYoutube).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one downloadable YouTube Short.')),
      );
      return;
    }
    final quality = await _chooseBatchQuality();
    if (quality == null || !mounted) return;
    final extraction = context.read<YoutubeExtractionService>();
    final downloads = context.read<DownloadsProvider>();
    setState(() {
      _batchDownloading = true;
      _batchDone = 0;
    });
    final result = await runBatch<VideoModel>(
      selected,
      (video) async {
        final options = await extraction.getDownloadOptions(video.youtubeId!);
        final option = _batchOption(options, quality);
        if (option == null) throw const DownloadException('No video resolution is available.');
        await downloads.start(
          videoId: video.youtubeId!,
          title: video.title,
          channelName: video.channelName,
          thumbnailUrl: video.thumbnailUrl,
          option: option,
          isShort: true,
        );
      },
      concurrency: 3,
      onProgress: (done, total) {
        if (mounted) setState(() => _batchDone = done);
      },
    );
    if (!mounted) return;
    setState(() {
      _batchDownloading = false;
      _batchDone = 0;
      _selectedVideoIds.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(batchSummary(result, (video) => video.title)),
        action: SnackBarAction(
          label: 'Downloads',
          onPressed: () => context.go('/downloads'),
        ),
      ),
    );
  }

  void _toggleSelected(VideoModel video) {
    if (!video.isYoutube) return;
    setState(() {
      if (!_selectedVideoIds.add(video.id)) _selectedVideoIds.remove(video.id);
    });
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
            appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Shorts')),
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
                                onPressed: () {
                                  if (_selecting) {
                                    setState(() {
                                      _selecting = false;
                                      _selectedVideoIds.clear();
                                    });
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                                icon: Icon(_selecting ? Icons.close_rounded : Icons.arrow_back_rounded, color: Colors.white),
                              ),
                              Text(
                                _selecting ? '${_selectedVideoIds.length} selected' : 'Shorts',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              if (_selecting)
                                TextButton(
                                  onPressed: () => _chooseCount(videos),
                                  child: const Text('Choose count', style: TextStyle(color: Colors.white)),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Downloaded Shorts',
                                      onPressed: () => context.push('/downloaded-shorts'),
                                      icon: const Icon(Icons.video_library_outlined, color: Colors.white),
                                    ),
                                    IconButton(
                                      tooltip: 'Select Shorts for batch download',
                                      onPressed: () => setState(() => _selecting = true),
                                      icon: const Icon(Icons.checklist_rounded, color: Colors.white),
                                    ),
                                  ],
                                ),
                              Text(
                                '${index + 1} / ${videos.length}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                      if (_selecting)
                        Positioned(
                          top: 64,
                          right: 16,
                          child: SafeArea(
                            child: Checkbox(
                              value: _selectedVideoIds.contains(video.id),
                              onChanged: (_) => _toggleSelected(video),
                              fillColor: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.selected) ? Colors.blue : Colors.black54,
                              ),
                              side: const BorderSide(color: Colors.white, width: 2),
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
                                  await preferences.toggleSubscription(video.channelName, channelId: video.channelId);
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
                              onPressed: () => showDownloadOptionsSheet(context, video, isShort: true),
                              icon: const Icon(Icons.download_rounded),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (_batchDownloading)
                Positioned(
                  top: 54,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _selectedVideoIds.isEmpty ? null : _batchDone / _selectedVideoIds.length,
                    minHeight: 2,
                  ),
                ),
              if (_selecting)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    child: FilledButton.icon(
                      onPressed: _selectedVideoIds.isEmpty || _batchDownloading
                          ? null
                          : () => _downloadSelected(videos),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        _batchDownloading
                            ? 'Preparing $_batchDone of ${_selectedVideoIds.length}'
                            : 'Download ${_selectedVideoIds.length} selected',
                      ),
                    ),
                  ),
                ),
              if (widget.feed.isLoading)
                const Positioned(top: 54, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
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
