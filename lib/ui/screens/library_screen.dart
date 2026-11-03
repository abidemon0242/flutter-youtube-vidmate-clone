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
  static const Set<String> _defaultFolders = {'Music', 'Tutorials', 'Movies', 'Shorts', 'Downloads'};
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
    final items = (await fileManager.getFolders())
        .where((folder) => folder.name != 'Downloads')
        .toList();
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
    if (_defaultFolders.contains(folder)) return;
    setState(() {
      if (selectedFolders.contains(folder)) {
        selectedFolders.remove(folder);
      } else {
        selectedFolders.add(folder);
      }
      multiSelectMode = selectedFolders.isNotEmpty;
    });
  }

  Future<void> _renameFolder(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == oldName || !mounted) return;
    final renamed = await fileManager.renameFolder(oldName, newName);
    if (!mounted) return;
    if (renamed) {
      await _loadFolders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename folder. Check the name and try again.')),
      );
    }
  }

  Future<void> _deleteFolder(String folderName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text('Delete "$folderName" and all files inside it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await fileManager.deleteFolder(folderName);
    if (!mounted) return;
    if (deleted) {
      selectedFolders.remove(folderName);
      multiSelectMode = selectedFolders.isNotEmpty;
      await _loadFolders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this folder.')),
      );
    }
  }

  Future<void> _deleteSelectedFolders() async {
    final selected = List<String>.from(selectedFolders);
    var deleted = 0;
    for (final folder in selected) {
      if (await fileManager.deleteFolder(folder)) deleted++;
    }
    if (!mounted) return;
    setState(() {
      selectedFolders.clear();
      multiSelectMode = false;
    });
    await _loadFolders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$deleted folder(s) deleted')),
    );
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
        title: Text(multiSelectMode ? '${selectedFolders.length} selected' : 'My Library'),
        actions: [
          if (multiSelectMode)
            IconButton(
              tooltip: 'Delete selected folders',
              onPressed: _deleteSelectedFolders,
              icon: const Icon(Icons.delete_outline),
            )
          else
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
              onRename: _defaultFolders.contains(folder) ? null : () => _renameFolder(folder),
              onDelete: _defaultFolders.contains(folder) ? null : () => _deleteFolder(folder),
              onTap: () async {
                if (multiSelectMode) {
                  _toggleFolderSelection(folder);
                } else {
                  await context.push('/library/${Uri.encodeComponent(folder)}');
                  if (mounted) await _loadFolders();
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
