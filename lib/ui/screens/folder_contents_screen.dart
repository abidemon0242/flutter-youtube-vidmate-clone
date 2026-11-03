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
                  trailing: playable ? const Icon(Icons.play_circle_outline) : null,
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
