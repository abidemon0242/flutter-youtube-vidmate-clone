import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/repositories/mock_youtube_repository.dart';
import '../../models/video_model.dart';
import '../../providers/downloads_provider.dart';
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
            onPressed: () {},
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
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
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
                    await Navigator.pushNamed(context, '/watch');
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
              Navigator.pushNamed(context, '/downloads');
              break;
            case 2:
              Navigator.pushNamed(context, '/library');
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
                final downloads = context.read<DownloadsProvider>();
                for (final id in selectedIds) {
                  downloads.addDownload(
                    DownloadEntry(
                      id: id,
                      title: 'Queued $id',
                      url: 'https://example.com/video/$id',
                      size: '42 MB',
                      format: '1080p',
                      progress: 0.0,
                      savedPath: '/storage/emulated/0/Download/tube_arena/$id.mp4',
                    ),
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${selectedIds.length} video(s) added to batch download'),
                  ),
                );
                setState(() {
                  selectedIds.clear();
                  multiSelectMode = false;
                });
              },
              label: const Text('Download All'),
              icon: const Icon(Icons.download_rounded),
            )
          : null,
    );
  }
}
