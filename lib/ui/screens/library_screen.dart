import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
  final Set<String> selectedFolders = {};

  @override
  void initState() {
    super.initState();
    fileManager = context.read<LocalFileManagerService>();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final items = await fileManager.getFolders();
    if (!mounted) return;
    setState(() => folders = items.map((item) => item.name).toList());
  }

  Future<void> _createNewFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final created = await fileManager.createFolder(name);
    if (!mounted) return;
    if (!created) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folder already exists or could not be created.')));
    }
    await _loadFolders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Library'), actions: [
        IconButton(onPressed: _createNewFolder, icon: const Icon(Icons.add_rounded), tooltip: 'Create folder'),
      ]),
      body: folders.isEmpty
          ? const Center(child: Text('No folders yet. Create one with +.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: folders.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15),
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  final selected = selectedFolders.contains(folder);
                  return FolderCard(
                    folderName: folder,
                    fileCount: 0,
                    isSelected: selected,
                    onTap: () {
                      if (selectedFolders.isNotEmpty) {
                        setState(() => selected ? selectedFolders.remove(folder) : selectedFolders.add(folder));
                      } else {
                        context.push('/library/${Uri.encodeComponent(folder)}');
                      }
                    },
                    onLongPress: () => setState(() => selected ? selectedFolders.remove(folder) : selectedFolders.add(folder)),
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
          if (index == 0) context.go('/');
          if (index == 1) context.go('/downloads');
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

class LibraryFolderScreen extends StatelessWidget {
  const LibraryFolderScreen({super.key, required this.folderName});

  final String folderName;

  @override
  Widget build(BuildContext context) {
    final manager = context.read<LocalFileManagerService>();
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: FutureBuilder(
        future: manager.getFilesInFolder(folderName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final files = snapshot.data ?? const [];
          if (files.isEmpty) return const Center(child: Text('This folder is empty.'));
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(files[index].name),
              subtitle: Text(files[index].sizeFormatted),
            ),
          );
        },
      ),
    );
  }
}
