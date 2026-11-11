import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/repositories/youtube_repository.dart';
import '../../models/video_model.dart';
import '../../services/invidious_catalog_service.dart';
import '../../services/personalization_service.dart';
import '../widgets/video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final YouTubeRepository repository;
  final TextEditingController _searchController = TextEditingController();
  int selectedCategory = 0;
  String searchQuery = '';
  List<VideoModel> searchResults = [];
  List<VideoModel> feedVideos = [];
  bool feedLoading = true;
  String? feedError;
  bool searching = false;
  String? searchError;
  int _feedRequest = 0;
  int _searchRequest = 0;
  String _playlistSignature = '';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<PersonalizationService>().removeListener(
      _onPersonalizationChanged,
    );
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repository = context.read<YouTubeRepository>();
    final profile = context.read<PersonalizationService>();
    _playlistSignature = _currentPlaylistSignature(profile);
    profile.addListener(_onPersonalizationChanged);
    _loadFeed();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = context.read<PersonalizationService>();
      if (!mounted || profile.consentDecided) return;
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => AlertDialog(
          title: const Text('Personalized recommendations'),
          content: const Text(
            'Tube Arena can use your in-app searches, likes, saves and watch activity to improve recommendations. This activity is stored locally on this device. You can turn personalization off or clear the data at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Agree and continue'),
            ),
          ],
        ),
      );
      if (mounted) await profile.setConsent(accepted == true);
    });
  }

  String _currentPlaylistSignature(PersonalizationService profile) => profile
      .playlists
      .map((playlist) => '${playlist.id}:${playlist.videos.length}')
      .join('|');

  void _onPersonalizationChanged() {
    if (!mounted) return;
    final profile = context.read<PersonalizationService>();
    final signature = _currentPlaylistSignature(profile);
    if (signature == _playlistSignature) return;
    _playlistSignature = signature;
    if (searchQuery.isEmpty && !feedLoading) _loadFeed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && searchQuery.isEmpty) {
      _loadFeed();
    }
  }

  String _cleanError(Object error) {
    final text = error.toString();
    if (error is InvidiousCatalogException) return error.message;
    return text
        .replaceFirst('InvidiousCatalogException: ', '')
        .replaceFirst('YouTubeRssException: ', '')
        .trim();
  }

  Future<void> _loadFeed() async {
    final request = ++_feedRequest;
    final categories = repository.getCategories();
    final category = selectedCategory < categories.length
        ? categories[selectedCategory]
        : 'Trending';
    if (mounted) {
      setState(() {
        feedLoading = true;
        feedError = null;
      });
    }
    try {
      final profile = context.read<PersonalizationService>();
      final subscribed = await profile.refreshChannelFeeds();
      final results = await repository.getFeedVideos(
        category: category,
        subscribedVideos: subscribed,
        recommendationQuery: profile.recommendationQuery,
      );
      if (!mounted || request != _feedRequest) return;
      setState(() {
        feedVideos = results;
        feedLoading = false;
        feedError = results.isEmpty
            ? (category == 'Subscriptions'
                  ? 'No channel videos yet. Add a YouTube channel from the RSS button above.'
                  : 'No videos available right now. Pull to refresh or try again later.')
            : null;
      });
    } catch (error) {
      if (!mounted || request != _feedRequest) return;
      setState(() {
        feedLoading = false;
        feedError = _cleanError(error);
      });
    }
  }

  List<VideoModel> videos(PersonalizationService profile) {
    if (searchQuery.isNotEmpty) return searchResults;
    final unique = <String, VideoModel>{};
    final imported = profile.playlists.expand((playlist) => playlist.videos);
    for (final video in imported) {
      unique.putIfAbsent(video.id, () => video);
    }
    for (final video in profile.rankVideos(feedVideos)) {
      unique.putIfAbsent(video.id, () => video);
    }
    return List.unmodifiable(unique.values);
  }

  Future<void> _runSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      clearSearch();
      return;
    }

    final request = ++_searchRequest;
    setState(() {
      searchQuery = term;
      selectedCategory = 0;
      searching = true;
      searchError = null;
      searchResults = [];
    });

    try {
      final profile = context.read<PersonalizationService>();
      await profile.record(type: 'search', query: term);
      if (!mounted || request != _searchRequest) return;

      final available = <String, VideoModel>{};
      for (final video in [
        ...feedVideos,
        ...profile.playlists.expand((channel) => channel.videos),
      ]) {
        available.putIfAbsent(video.id, () => video);
      }
      final found = await repository.searchVideos(
        term,
        availableVideos: available.values.toList(),
      );
      if (!mounted || request != _searchRequest || term != searchQuery) return;
      setState(() {
        searchResults = profile.rankVideos(found);
      });
    } catch (error) {
      if (mounted && request == _searchRequest && term == searchQuery) {
        setState(() {
          searchError = _cleanError(error);
        });
      }
    } finally {
      if (mounted && request == _searchRequest) {
        setState(() => searching = false);
      }
    }
  }

  void clearSearch() {
    _searchController.clear();
    _searchRequest++;
    setState(() {
      searchQuery = '';
      searchResults = [];
      searchError = null;
      searching = false;
    });
  }

  Widget _buildEmptyState({
    required String message,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PersonalizationService>();
    final categories = repository.getCategories();
    final visibleVideos = videos(profile);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Tube Arena'),
        actions: [
          IconButton(
            tooltip: 'Add YouTube channel',
            onPressed: () => context.push('/playlists'),
            icon: const Icon(Icons.rss_feed),
          ),
          IconButton(
            tooltip: 'Personalization & privacy',
            onPressed: () => context.push('/personalization'),
            icon: const Icon(Icons.auto_awesome),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'downloads') context.go('/downloads');
              if (value == 'library') context.go('/library');
              if (value == 'links') context.push('/add-downloads');
              if (value == 'playlists') context.push('/playlists');
              if (value == 'privacy') context.push('/personalization');
              if (value == 'settings') context.push('/settings');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'links', child: Text('Add media links')),
              PopupMenuItem(value: 'downloads', child: Text('Downloads')),
              PopupMenuItem(value: 'library', child: Text('Library')),
              PopupMenuItem(
                value: 'playlists',
                child: Text('Add YouTube channel'),
              ),
              PopupMenuItem(
                value: 'privacy',
                child: Text('Personalization & privacy'),
              ),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _runSearch,
              decoration: InputDecoration(
                hintText: 'Search videos, channels, topics…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    searchQuery.isNotEmpty || _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: clearSearch,
                        icon: const Icon(Icons.close),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                filled: true,
              ),
            ),
          ),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: categories.length,
              itemBuilder: (context, index) => ChoiceChip(
                label: Text(categories[index]),
                selected: index == selectedCategory,
                onSelected: (_) {
                  _searchRequest++;
                  setState(() {
                    selectedCategory = index;
                    searchQuery = '';
                    _searchController.clear();
                    searchResults = [];
                    searchError = null;
                    searching = false;
                  });
                  _loadFeed();
                },
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
            ),
          ),
          Expanded(
            child: searching
                ? const Center(child: CircularProgressIndicator())
                : searchError != null
                ? _buildEmptyState(
                    message: searchError!,
                    onAction: () => _runSearch(searchQuery),
                    actionLabel: 'Retry search',
                  )
                : feedLoading && searchQuery.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : feedError != null && visibleVideos.isEmpty
                ? _buildEmptyState(
                    message: feedError!,
                    onAction: _loadFeed,
                    actionLabel: 'Retry',
                  )
                : visibleVideos.isEmpty
                ? _buildEmptyState(
                    message: searchQuery.isNotEmpty
                        ? 'No search results. Try another query.'
                        : 'No videos available',
                  )
                : RefreshIndicator(
                    onRefresh: _loadFeed,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: visibleVideos.length,
                      itemBuilder: (context, index) {
                        final video = visibleVideos[index];
                        return VideoCard(
                          video: video,
                          onTap: () => context.push('/watch', extra: video),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) context.go('/downloads');
          if (index == 2) context.go('/library');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'Downloads',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}
