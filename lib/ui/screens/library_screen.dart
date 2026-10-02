import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';
import '../../services/local_file_manager_service.dart';
import '../modals/download_quality_modal.dart';
import '../widgets/batch_download_bar.dart';
import '../widgets/folder_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final LocalFileManagerService fileManager;
  List<String> folders = [];
  final Set<String> selectedFolders = {};
  bool multiSelectMode = false;

  @override
  void initState() {
    super.initState();
    fileManager = LocalFileManagerService();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final items = await fileManager.getFolders();
    setState(() {
      folders = items.map((e) => e.name).toList();
      if (!folders.contains('Music')) folders.add('Music');
      if (!folders.contains('Tutorials')) folders.add('Tutorials');
      if (!folders.contains('Movies')) folders.add('Movies');
      if (!folders.contains('Shorts')) folders.add('Shorts');
    });
  }

  void _toggleFolderSelection(String folder) {
    setState(() {
      if (selectedFolders.contains(folder)) {
        selectedFolders.remove(folder);
      } else {
        selectedFolders.add(folder);
      }
      multiSelectMode = selectedFolders.isNotEmpty;
    });
  }

  void _createNewFolder() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('New Folder'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Folder name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await fileManager.createFolder(controller.text);
                  Navigator.pop(context);
                  _loadFolders();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          if (!multiSelectMode)
            IconButton(
              onPressed: _createNewFolder,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: folders.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final folder = folders[index];
            final selected = selectedFolders.contains(folder);
            return FolderCard(
              folderName: folder,
              fileCount: 12,
              isSelected: selected,
              onTap: () {
                if (multiSelectMode) {
                  _toggleFolderSelection(folder);
                } else {
                  Navigator.pushNamed(context, '/library/$folder');
                }
              },
              onLongPress: () => _toggleFolderSelection(folder),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primaryStart,
        unselectedItemColor: AppColors.textSecondary,
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/');
              break;
            case 1:
              Navigator.pushNamed(context, '/downloads');
              break;
            case 2:
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.download_rounded), label: 'Downloads'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
        ],
      ),
    );
  }
}
