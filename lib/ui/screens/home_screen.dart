import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/repositories/youtube_repository.dart';
import '../../models/video_model.dart';
import '../../services/personalization_service.dart';
import '../../services/youtube_data_api_service.dart';
import '../widgets/video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final YouTubeRepository repository;
  int selectedCategory = 0;
  bool multiSelectMode = false;
  String searchQuery = '';
  List<VideoModel> searchResults = [];
  List<VideoModel> feedVideos = [];
  bool feedLoading = true;
  String? feedError;
  bool searching = false;
  String? searchError;
  final Set<String> selectedIds = {};
  int _feedRequest = 0;
  int _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    repository = context.read<YouTubeRepository>();
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

  Future<void> _loadFeed() async {
    final request = ++_feedRequest;
    final categories = repository.getCategories();
    final category = selectedCategory < categories.length
        ? categories[selectedCategory]
        : 'All';
    if (mounted) {
      setState(() {
        feedLoading = true;
        feedError = null;
      });
    }
    try {
      final results = await repository.getFeedVideos(category: category);
      if (!mounted || request != _feedRequest) return;
      setState(() {
        feedVideos = results;
        feedLoading = false;
        feedError = results.isEmpty ? 'No live results were returned. Try another category or refresh.' : null;
      });
    } catch (error) {
      if (!mounted || request != _feedRequest) return;
      setState(() {
        feedLoading = false;
        feedError = error is YouTubeApiException ? error.message : 'Could not load YouTube videos. Check your connection and try again.';
      });
    }
  }

  List<VideoModel> videos(PersonalizationService profile) {
    if (searchQuery.isNotEmpty) return searchResults;
    final unique = <String, VideoModel>{};
    for (final video in [
      ...feedVideos,
      ...profile.playlists.expand((playlist) => playlist.videos),
    ]) {
      unique.putIfAbsent(video.id, () => video);
    }
    return profile.rankVideos(unique.values.toList());
  }

  void toggle(String id) {
    setState(() {
      if (!selectedIds.add(id)) selectedIds.remove(id);
      multiSelectMode = selectedIds.isNotEmpty;
    });
  }

  Future<void> search() async {
    final controller = TextEditingController(text: searchQuery);
    final query = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Search videos'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(dialog, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (query == null || !mounted) return;
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }

    final term = query.trim();
    final request = ++_searchRequest;
    await context.read<PersonalizationService>().record(
          type: 'search',
          query: term,
        );
    setState(() {
      searchQuery = term;
      selectedCategory = 0;
      searching = true;
      searchError = null;
      searchResults = [];
      selectedIds.clear();
      multiSelectMode = false;
    });

    try {
      final found = await repository.searchVideos(term);
      if (!mounted || request != _searchRequest || term != searchQuery) return;
      setState(() {
        searchResults =
            context.read<PersonalizationService>().rankVideos(found);
      });
    } catch (_) {
      if (mounted && request == _searchRequest && term == searchQuery) {
        setState(() {
          searchError = error is YouTubeApiException ? error.message : 'Search is temporarily unavailable. Check your connection.';
        });
      }
    } finally {
      if (mounted && request == _searchRequest) setState(() => searching = false);
    }
  }

  void clearSearch() {
    _searchRequest++;
    setState(() {
      searchQuery = '';
      searchResults = [];
      searchError = null;
      searching = false;
      selectedIds.clear();
      multiSelectMode = false;
    });
  }

  String? _downloadUrlFor(VideoModel video) {
    final uri = Uri.tryParse(video.playbackUrl);
    const hosts = {
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtu.be',
      'www.youtu.be',
    };
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        hosts.contains(uri.host.toLowerCase())) {
      return uri.toString();
    }
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(video.id)) {
      return 'https://www.youtube.com/watch?v=' + video.id;
    }
    return null;
  }

  void _openSelectedDownloads(List<VideoModel> visibleVideos) {
    final urls = visibleVideos
        .where((video) => selectedIds.contains(video.id))
        .map(_downloadUrlFor)
        .whereType<String>()
        .toList();

    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The selected demo items have no YouTube source URL. Select live search results or add links manually.',
          ),
        ),
      );
      return;
    }

    setState(() {
      selectedIds.clear();
      multiSelectMode = false;
    });
    context.push('/add-downloads', extra: urls);
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
            tooltip: 'Import playlist',
            onPressed: () => context.push('/playlists'),
            icon: const Icon(Icons.playlist_add),
          ),
          IconButton(
            tooltip: 'Personalization & privacy',
            onPressed: () => context.push('/personalization'),
            icon: const Icon(Icons.auto_awesome),
          ),
          if (searchQuery.isNotEmpty)
            IconButton(onPressed: clearSearch, icon: const Icon(Icons.close)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'downloads') context.go('/downloads');
              if (value == 'library') context.go('/library');
              if (value == 'links') context.push('/add-downloads');
              if (value == 'playlists') context.push('/playlists');
              if (value == 'privacy') context.push('/personalization');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'links', child: Text('Add media links')),
              PopupMenuItem(value: 'downloads', child: Text('Downloads')),
              PopupMenuItem(value: 'library', child: Text('Library')),
              PopupMenuItem(value: 'playlists', child: Text('Import playlist')),
              PopupMenuItem(
                value: 'privacy',
                child: Text('Personalization & privacy'),
              ),
            ],
          ),
          IconButton(
            onPressed: search,
            tooltip: 'Search',
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) => ChoiceChip(
                label: Text(categories[index]),
                selected: index == selectedCategory,
                onSelected: (_) {
                  _searchRequest++;
                  setState(() {
                    selectedCategory = index;
                    searchQuery = '';
                    searchResults = [];
                    searchError = null;
                    searching = false;
                    selectedIds.clear();
                    multiSelectMode = false;
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
                    ? Center(child: Text(searchError!))
                    : feedLoading && searchQuery.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                    : feedError != null && visibleVideos.isEmpty
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(feedError!), const SizedBox(height: 12), FilledButton.icon(onPressed: _loadFeed, icon: const Icon(Icons.refresh), label: const Text('Retry'))]))
                    : visibleVideos.isEmpty
                        ? const Center(child: Text('No videos available'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            itemCount: visibleVideos.length,
                            itemBuilder: (context, index) {
                              final video = visibleVideos[index];
                              return VideoCard(
                                video: video,
                                multiSelectMode: multiSelectMode,
                                isSelected: selectedIds.contains(video.id),
                                onLongPress: () => toggle(video.id),
                                onCheckboxTap: () => toggle(video.id),
                                onTap: () {
                                  if (multiSelectMode) {
                                    toggle(video.id);
                                    return;
                                  }
                                  context.push('/watch', extra: video);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primaryStart,
        unselectedItemColor: AppColors.textSecondary,
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) context.go('/downloads');
          if (index == 2) context.go('/library');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
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
      floatingActionButton: multiSelectMode
          ? FloatingActionButton.extended(
              onPressed: () => _openSelectedDownloads(visibleVideos),
              label: const Text('Download selected'),
              icon: const Icon(Icons.add_link),
            )
          : null,
    );
  }
}
