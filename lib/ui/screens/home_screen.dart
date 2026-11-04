import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/repositories/mock_youtube_repository.dart';
import '../../models/video_model.dart';
import '../widgets/video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MockYouTubeRepository repository;
  int selectedCategory = 0;
  bool multiSelectMode = false;
  String searchQuery = '';
  List<VideoModel> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  final Set<String> selectedIds = {};

  @override
  void initState() {
    super.initState();
    repository = context.read<MockYouTubeRepository>();
  }

  List<VideoModel> get videos {
    if (searchQuery.trim().isNotEmpty) return _searchResults;
    final allVideos = repository.getTrendingVideos();
    final categories = repository.getCategories();
    final category = selectedCategory < categories.length
        ? categories[selectedCategory]
        : 'All';
    final categoryVideos = category == 'All'
        ? allVideos
        : allVideos.where((video) => video.category == category).toList();
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return categoryVideos;
    return categoryVideos.where((video) =>
      video.title.toLowerCase().contains(query) ||
      video.channelName.toLowerCase().contains(query),
    ).toList();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!selectedIds.add(id)) selectedIds.remove(id);
      multiSelectMode = selectedIds.isNotEmpty;
    });
  }

  Future<void> _search() async {
    final controller = TextEditingController(text: searchQuery);
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search YouTube'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search videos'),
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
    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }
    setState(() {
      searchQuery = query.trim();
      selectedCategory = 0;
      _isSearching = true;
      _searchError = null;
      _searchResults = [];
    });
    try {
      final results = await repository.searchVideos(searchQuery);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _searchError = 'Search is temporarily unavailable. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    setState(() {
      searchQuery = '';
      _searchResults = [];
      _searchError = null;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = repository.getCategories();
    final visibleVideos = videos;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Tube Arena'),
        actions: [
          if (searchQuery.isNotEmpty)
            IconButton(onPressed: _clearSearch, tooltip: 'Clear search', icon: const Icon(Icons.close)),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'add') context.push('/add-downloads');
              if (value == 'downloads') context.go('/downloads');
              if (value == 'library') context.go('/library');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'add', child: ListTile(leading: Icon(Icons.add_link), title: Text('Add video links'))),
              PopupMenuItem(value: 'downloads', child: ListTile(leading: Icon(Icons.download), title: Text('Downloads'))),
              PopupMenuItem(value: 'library', child: ListTile(leading: Icon(Icons.library_books), title: Text('Library'))),
            ],
          ),
          IconButton(onPressed: _search, tooltip: 'Search', icon: const Icon(Icons.search_rounded)),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) => ChoiceChip(
              label: Text(categories[index]),
              selected: index == selectedCategory,
              onSelected: (_) => setState(() => selectedCategory = index),
            ),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchError != null
                  ? Center(child: Text(_searchError!, textAlign: TextAlign.center))
                  : visibleVideos.isEmpty
                      ? Center(child: Text(searchQuery.isEmpty ? 'No videos available' : 'No search results found'))
                      : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: visibleVideos.length,
                  itemBuilder: (context, index) {
                    final video = visibleVideos[index];
                    return VideoCard(
                      video: video,
                      multiSelectMode: multiSelectMode,
                      isSelected: selectedIds.contains(video.id),
                      onLongPress: () => _toggleSelection(video.id),
                      onCheckboxTap: () => _toggleSelection(video.id),
                      onTap: () {
                        if (multiSelectMode) {
                          _toggleSelection(video.id);
                        } else {
                          context.push('/watch', extra: video);
                        }
                      },
                    );
                  },
                ),
        ),
      ]),
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
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.download_rounded), label: 'Downloads'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
        ],
      ),
      floatingActionButton: multiSelectMode
          ? FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('The home feed contains demo cards. Paste authorized media links to create real downloads.')),
                );
                context.push('/add-downloads');
              },
              label: const Text('Add download links'),
              icon: const Icon(Icons.add_link),
            )
          : null,
    );
  }
}
