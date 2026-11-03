import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/local_file_manager_service.dart';
import '../widgets/folder_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final LocalFileManagerService fileManager;
  List<String> folders = [];
  final Map<String, int> folderCounts = {};
  final Set<String> selectedFolders = {};
  bool multiSelectMode = false;

  @override
  void initState() {
    super.initState();
    fileManager = LocalFileManagerService();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    await fileManager.initialize();
    for (final folder in ['Music', 'Tutorials', 'Movies', 'Shorts']) {
      await fileManager.createFolder(folder);
    }
    final items = await fileManager.getFolders();
    final counts = <String, int>{};
    for (final folder in items) {
      counts[folder.name] = (await fileManager.getFilesInFolder(folder.name)).length;
    }
    if (!mounted) return;
    setState(() {
      folders = items.map((e) => e.name).toList();
      folderCounts
        ..clear()
        ..addAll(counts);
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
              fileCount: folderCounts[folder] ?? 0,
              isSelected: selected,
              onTap: () {
                if (multiSelectMode) {
                  _toggleFolderSelection(folder);
                } else {
                  context.go('/library/${Uri.encodeComponent(folder)}');
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
              context.go('/');
              break;
            case 1:
              context.go('/downloads');
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
