import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../services/local_file_manager_service.dart';

class FolderContentsScreen extends StatefulWidget {
  const FolderContentsScreen({super.key, required this.folderName});

  final String folderName;

  @override
  State<FolderContentsScreen> createState() => _FolderContentsScreenState();
}

class _FolderContentsScreenState extends State<FolderContentsScreen> {
  final LocalFileManagerService _fileManager = LocalFileManagerService();
  late Future<List<LocalFile>> _files;

  @override
  void initState() {
    super.initState();
    _files = _fileManager.getFilesInFolder(widget.folderName);
  }

  Future<void> _refresh() async {
    setState(() {
      _files = _fileManager.getFilesInFolder(widget.folderName);
    });
    await _files;
  }

  Future<void> _renameFile(LocalFile file) async {
    final controller = TextEditingController(text: file.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
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
    if (newName == null || newName.isEmpty || !mounted) return;
    final renamed = await _fileManager.renameFile(file.path, newName);
    if (!mounted) return;
    if (renamed) {
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename this file.')),
      );
    }
  }

  Future<void> _moveFile(LocalFile file) async {
    final folders = await _fileManager.getFolders();
    if (!mounted) return;
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Move to folder'),
        children: folders
            .where((folder) => folder.name != widget.folderName && folder.name != 'Downloads')
            .map((folder) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, folder.name),
                  child: Text(folder.name),
                ))
            .toList(),
      ),
    );
    if (target == null || !mounted) return;
    final moved = await _fileManager.moveFile(file.path, target);
    if (!mounted) return;
    if (moved) {
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not move this file.')),
      );
    }
  }

  Future<void> _deleteFile(LocalFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Delete "${file.name}" permanently?'),
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
    final deleted = await _fileManager.deleteFile(file.path);
    if (!mounted) return;
    if (deleted) {
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folderName)),
      body: FutureBuilder<List<LocalFile>>(
        future: _files,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this folder.'));
          }
          final files = snapshot.data ?? const <LocalFile>[];
          if (files.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_outlined, size: 56, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('This folder is empty', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: files.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final file = files[index];
                final lowerName = file.name.toLowerCase();
                final playable = [
                  '.mp4', '.m4v', '.mov', '.webm', '.mkv',
                  '.mp3', '.m4a', '.aac', '.wav', '.ogg', '.flac',
                ].any(lowerName.endsWith);
                final audio = [
                  '.mp3', '.m4a', '.aac', '.wav', '.ogg', '.flac',
                ].any(lowerName.endsWith);
                return ListTile(
                  leading: Icon(audio ? Icons.audio_file_outlined : Icons.video_file_outlined),
                  title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(file.sizeFormatted),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (playable) const Icon(Icons.play_circle_outline),
                      if (widget.folderName != 'Downloads')
                        PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'rename') _renameFile(file);
                            if (action == 'move') _moveFile(file);
                            if (action == 'delete') _deleteFile(file);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(value: 'move', child: Text('Move')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                    ],
                  ),
                  onTap: playable
                      ? () => context.push('/local-player', extra: file.path)
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('This file format is not supported by the player.')),
                          ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
