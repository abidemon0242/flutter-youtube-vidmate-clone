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
  final Set<String> selectedIds = {};

  @override
  void initState() {
    super.initState();
    repository = context.read<MockYouTubeRepository>();
  }

  List<VideoModel> get videos => repository.getTrendingVideos();

  List<VideoModel> get visibleVideos {
    final allVideos = videos;
    switch (repository.getCategories()[selectedCategory]) {
      case 'Tech':
        return allVideos.where((video) {
          final text = video.title.toLowerCase() + ' ' + video.channelName.toLowerCase();
          return text.contains('android') || text.contains('flutter') || text.contains('app');
        }).toList();
      case 'Tutorials':
        return allVideos.where((video) =>
            video.title.toLowerCase().contains('how to') ||
            video.title.toLowerCase().contains('workflow')).toList();
      case 'Design':
        return allVideos.where((video) =>
            (video.title + ' ' + video.channelName).toLowerCase().contains('design') ||
            video.title.toLowerCase().contains('figma')).toList();
      case 'All':
        return allVideos;
      default:
        return [];
    }
  }

  Future<void> _openSearch() async {
    final result = await showSearch<VideoModel?>(
      context: context,
      delegate: _VideoSearchDelegate(videos),
    );
    if (!mounted || result == null) return;
    context.go('/watch', extra: result);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
      multiSelectMode = selectedIds.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = repository.getCategories();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.menu_rounded, color: AppColors.white),
            const SizedBox(width: 12),
            const Text('Tube Arena'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add video links',
            onPressed: () => context.push('/add-downloads'),
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            onPressed: _openSearch,
            tooltip: 'Search videos',
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final isSelected = index == selectedCategory;
                return ChoiceChip(
                  label: Text(categories[index]),
                  selected: isSelected,
                  onSelected: (_) => setState(() => selectedCategory = index),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
            ),
          ),
          Expanded(
            child: visibleVideos.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No demo videos are available in this category yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: visibleVideos.length,
              itemBuilder: (context, index) {
                final video = visibleVideos[index];
                final checked = selectedIds.contains(video.id);
                return VideoCard(
                  video: video,
                  multiSelectMode: multiSelectMode,
                  isSelected: checked,
                  onLongPress: () => _toggleSelection(video.id),
                  onCheckboxTap: () => _toggleSelection(video.id),
                  onTap: () async {
                    if (multiSelectMode) {
                      _toggleSelection(video.id);
                      return;
                    }
                    context.go('/watch', extra: video);
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
          switch (index) {
            case 0:
              break;
            case 1:
              context.go('/downloads');
              break;
            case 2:
              context.go('/library');
              break;
          }
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
                  const SnackBar(
                    content: Text(
                      'Batch downloads are not available yet. These demo videos do not have verified download streams.',
                    ),
                    duration: Duration(seconds: 4),
                  ),
                );
              },
              label: const Text('Batch download unavailable'),
              icon: const Icon(Icons.info_outline_rounded),
            )
          : null,
    );
  }
}


class _VideoSearchDelegate extends SearchDelegate<VideoModel?> {
  _VideoSearchDelegate(this.videos);

  final List<VideoModel> videos;

  @override
  String get searchFieldLabel => 'Search demo videos';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            onPressed: () => query = '',
            icon: const Icon(Icons.clear),
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final matches = videos.where((video) {
      return video.title.toLowerCase().contains(normalized) ||
          video.channelName.toLowerCase().contains(normalized);
    }).toList();
    if (matches.isEmpty) {
      return const Center(child: Text('No matching demo videos found.'));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final video = matches[index];
        return ListTile(
          leading: const Icon(Icons.play_circle_outline),
          title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(video.channelName),
          onTap: () => close(context, video),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
