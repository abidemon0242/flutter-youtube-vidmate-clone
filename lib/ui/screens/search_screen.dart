import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/paged_feed.dart';
import '../../data/repositories/feed_repository.dart';
import '../../models/video_model.dart';
import '../widgets/video_card.dart';

/// Dedicated full-screen search experience. Search results are loaded only
/// after the user submits a non-empty query.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FeedRepository _repository;
  Future<FeedResult>? _results;
  String _submittedQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _repository = context.read<FeedRepository>();
    if (widget.initialQuery.trim().isNotEmpty) {
      _submittedQuery = widget.initialQuery.trim();
      _results = _repository.load(category: 'All', query: _submittedQuery, refresh: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search({bool refresh = true}) async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a video title or channel name.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submittedQuery = query;
      _results = _repository.load(category: 'All', query: query, refresh: refresh);
    });
  }

  void _goBack() => context.pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: 'Search videos or channels',
            border: InputBorder.none,
            isDense: true,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear search',
            onPressed: () {
              _controller.clear();
              setState(() {
                _submittedQuery = '';
                _results = null;
              });
            },
            icon: const Icon(Icons.close_rounded),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: _search,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: _results == null
          ? _emptyState()
          : FutureBuilder<FeedResult>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _failure(
                    snapshot.error.toString(),
                    onRetry: () => _search(),
                  );
                }
                final result = snapshot.data;
                if (result == null) {
                  return _failure('Search did not return a result.', onRetry: () => _search());
                }
                return _resultsList(result);
              },
            ),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Search Tube Arena', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Find videos by title or channel. Enter a search term above.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );

  Widget _failure(String message, {required VoidCallback onRetry}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: 12),
          const Text('Search is temporarily unavailable', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _resultsList(FeedResult result) => AnimatedBuilder(
    animation: result.feed,
    builder: (context, _) {
      final videos = result.feed.items;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Results for “$_submittedQuery”', style: Theme.of(context).textTheme.titleSmall),
          if (result.isSample)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_rounded),
                title: const Text('YouTube search could not connect'),
                subtitle: Text(result.message ?? 'Showing matching sample videos, if available.'),
                trailing: IconButton(
                  tooltip: 'Retry',
                  onPressed: () => _search(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ),
          if (videos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  result.isSample ? 'No matching sample videos.' : 'No videos found for this search.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (final video in videos)
              VideoCard(
                video: video,
                onTap: () => context.push('/watch', extra: video),
              ),
          if (result.feed.error != null)
            ListTile(
              title: Text(result.feed.error!),
              trailing: TextButton(onPressed: result.feed.loadMore, child: const Text('Retry')),
            )
          else if (result.feed.hasMore)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: result.feed.isLoading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: result.feed.loadMore,
                        child: const Text('Load more'),
                      ),
              ),
            ),
        ],
      );
    },
  );
}
