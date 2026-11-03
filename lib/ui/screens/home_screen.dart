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
  final Set<String> selectedIds = {};

  @override
  void initState() {
    super.initState();
    repository = context.read<MockYouTubeRepository>();
  }

  List<VideoModel> get videos {
    final allVideos = repository.getTrendingVideos();
    if (searchQuery.trim().isEmpty) return allVideos;
    final query = searchQuery.toLowerCase();
    return allVideos.where((video) =>
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
        title: const Text('Search videos'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Title or channel'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Search')),
        ],
      ),
    );
    if (query != null && mounted) setState(() => searchQuery = query);
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = repository.getCategories();
    final visibleVideos = videos;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.menu_rounded, color: AppColors.white),
            SizedBox(width: 12),
            Text('Tube Arena'),
          ],
        ),
        actions: [
          IconButton(onPressed: _search, tooltip: 'Search', icon: const Icon(Icons.search_rounded)),
        ],
      ),
      body: Column(
        children: [
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
            child: visibleVideos.isEmpty
                ? const Center(child: Text('No matching videos'))
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
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.download_rounded), label: 'Downloads'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
        ],
      ),
      floatingActionButton: multiSelectMode
          ? FloatingActionButton.extended(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Batch downloads are not available in this demo yet.')),
              ),
              label: Text('Download selected (${selectedIds.length})'),
              icon: const Icon(Icons.download_rounded),
            )
          : null,
    );
  }
}
