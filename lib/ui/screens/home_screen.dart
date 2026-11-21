import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/feed_repository.dart';
import '../../models/video_model.dart';
import '../../providers/downloads_provider.dart';
import '../../services/batch_download.dart';
import '../../services/youtube_extraction_service.dart';
import '../widgets/download_options_sheet.dart';
import '../widgets/theme_mode_button.dart';
import '../widgets/video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FeedRepository _feed = context.read<FeedRepository>();
  int _category = 0;
  String _query = '';
  late Future<FeedResult> _future = _load();
  final Map<String, VideoModel> _selected = {};
  bool _batchRunning = false;
  String _batchLabel = '';

  bool get _selecting => _selected.isNotEmpty;
  String get _categoryName => FeedRepository.categories[_category];

  Future<FeedResult> _load({bool refresh = false}) =>
      _feed.load(category: _categoryName, query: _query, refresh: refresh);

  void _reload({bool refresh = false}) => setState(() => _future = _load(refresh: refresh));

  void _toggle(VideoModel video) => setState(() {
    if (_selected.remove(video.id) == null) _selected[video.id] = video;
  });

  Future<void> _search() async {
    final controller = TextEditingController(text: _query);
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search videos'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Title or channel'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Search')),
        ],
      ),
    );
    controller.dispose();
    if (query == null || !mounted) return;
    _query = query.trim();
    _reload();
  }

  void _clearSearch() {
    _query = '';
    _reload();
  }

  /// Paste a YouTube link to open or download it directly.
  Future<void> _openLink() async {
    final controller = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open YouTube link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://youtu.be/...'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Open')),
        ],
      ),
    );
    controller.dispose();
    if (link == null || link.trim().isEmpty || !mounted) return;
    if (YoutubeExtractionService.extractVideoId(link) == null) {
      _snack('That is not a valid YouTube link.');
      return;
    }
    final youtube = context.read<YoutubeExtractionService>();
    final navigator = Navigator.of(context, rootNavigator: true);
    // Looking a video up can take a few seconds; block repeat taps meanwhile.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    );
    try {
      final video = await youtube.getVideo(link);
      navigator.pop();
      if (mounted) context.push('/watch', extra: video);
    } catch (error) {
      navigator.pop();
      _snack(error is YoutubeServiceException ? error.message : 'Could not open this video.');
    }
  }

  Future<void> _downloadSelected() async {
    final videos = _selected.values.toList();
    final downloadable = videos.where((v) => v.isYoutube).toList();
    if (downloadable.isEmpty) {
      _snack('Sample videos cannot be downloaded.');
      return;
    }
    setState(() {
      _batchRunning = true;
      _batchLabel = batchProgressLabel(0, downloadable.length);
    });
    final youtube = context.read<YoutubeExtractionService>();
    final downloads = context.read<DownloadsProvider>();
    // Fetch manifests a few at a time instead of one by one.
    final result = await runBatch<VideoModel>(
      downloadable,
      (video) async {
        final option = (await youtube.getDownloadOptions(video.youtubeId!)).recommended;
        if (option == null) throw const YoutubeServiceException('No downloadable formats');
        await downloads.start(
          videoId: video.youtubeId!,
          title: video.title,
          channelName: video.channelName,
          thumbnailUrl: video.thumbnailUrl,
          option: option,
        );
      },
      onProgress: (done, total) {
        if (mounted) setState(() => _batchLabel = batchProgressLabel(done, total));
      },
    );
    if (!mounted) return;
    setState(() {
      _batchRunning = false;
      _selected.clear();
    });
    _snack(batchSummary<VideoModel>(result, (v) => v.title, skipped: videos.length - downloadable.length));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting ? _selectionBar() : _normalBar(),
        body: Column(
          children: [
            SizedBox(
              height: 54,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: FeedRepository.categories.length,
                itemBuilder: (context, index) => ChoiceChip(
                  label: Text(FeedRepository.categories[index]),
                  selected: index == _category,
                  onSelected: (_) {
                    if (index == _category) return;
                    _category = index;
                    _reload();
                  },
                ),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
              ),
            ),
            if (_query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text('Search: $_query'),
                    onDeleted: _clearSearch,
                    deleteButtonTooltipMessage: 'Clear search',
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<FeedResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final result = snapshot.data ?? FeedResult.empty();
                  return RefreshIndicator(
                    onRefresh: () async {
                      _reload(refresh: true);
                      await _future;
                    },
                    child: ListenableBuilder(
                      listenable: result.feed,
                      builder: (context, _) {
                        final videos = result.feed.items;
                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: videos.length + 2,
                          itemBuilder: (context, index) {
                            if (index == 0) return _statusBanner(result);
                            if (index == videos.length + 1) return _footer(result);
                            final video = videos[index - 1];
                            return VideoCard(
                              video: video,
                              multiSelectMode: _selecting,
                              isSelected: _selected.containsKey(video.id),
                              onLongPress: () => _toggle(video),
                              onCheckboxTap: () => _toggle(video),
                              onMore: () => showDownloadOptionsSheet(context, video),
                              onTap: () => _selecting ? _toggle(video) : context.push('/watch', extra: video),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _selecting
            ? FloatingActionButton.extended(
                onPressed: _batchRunning ? null : _downloadSelected,
                label: Text(_batchRunning ? _batchLabel : 'Download selected (${_selected.length})'),
                icon: _batchRunning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded),
              )
            : null,
      ),
    );
  }

  /// Built only when the list is scrolled near its end (ListView builds
  /// lazily), which is what triggers loading the next page.
  Widget _footer(FeedResult result) {
    final feed = result.feed;
    if (feed.canAutoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) feed.loadMore();
      });
    }
    if (feed.isLoading || feed.canAutoLoad) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (feed.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              feed.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary),
            ),
            TextButton(onPressed: feed.loadMore, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (result.isSample || feed.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('No more results', style: TextStyle(color: context.textSecondary)),
      ),
    );
  }

  Widget _statusBanner(FeedResult result) {
    if (result.isSample) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
          title: const Text('Showing sample videos'),
          subtitle: Text(result.message ?? 'YouTube could not be reached.'),
          trailing: TextButton(onPressed: () => _reload(refresh: true), child: const Text('Retry')),
        ),
      );
    }
    if (result.videos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: Text('No matching videos')),
      );
    }
    return const SizedBox.shrink();
  }

  PreferredSizeWidget _normalBar() => AppBar(
    automaticallyImplyLeading: false,
    title: const Text('Tube Arena'),
    actions: [
      IconButton(onPressed: _openLink, tooltip: 'Open YouTube link', icon: const Icon(Icons.add_link_rounded)),
      IconButton(onPressed: _search, tooltip: 'Search', icon: const Icon(Icons.search_rounded)),
      const ThemeModeButton(),
    ],
  );

  PreferredSizeWidget _selectionBar() => AppBar(
    leading: IconButton(
      tooltip: 'Cancel selection',
      icon: const Icon(Icons.close_rounded),
      onPressed: () => setState(_selected.clear),
    ),
    title: Text('${_selected.length} selected'),
    actions: [
      FutureBuilder<FeedResult>(
        future: _future,
        builder: (context, snapshot) => TextButton(
          onPressed: snapshot.data == null
              ? null
              : () => setState(() {
                  for (final v in snapshot.data!.videos) {
                    _selected[v.id] = v;
                  }
                }),
          child: const Text('Select all'),
        ),
      ),
    ],
  );
}
