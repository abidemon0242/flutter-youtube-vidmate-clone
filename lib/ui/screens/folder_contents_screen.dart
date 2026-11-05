import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../services/ffmpeg_merge_service.dart';
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
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _files = _fileManager.getFilesInFolder(widget.folderName);
  }

  Future<void> _refresh() async {
    setState(() => _files = _fileManager.getFilesInFolder(widget.folderName));
    await _files;
  }

  Future<void> _renameFile(LocalFile file) async {
    final controller = TextEditingController(text: file.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'File name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Rename')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not rename this file.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not move this file.')));
    }
  }

  Future<bool> _isWebmAudioOnly(LocalFile file) async {
    if (!file.name.toLowerCase().endsWith('.webm')) return false;
    try {
      final session = await FFprobeKit.getMediaInformation(file.path);
      final information = await session.getMediaInformation();
      final streams = information?.getStreams() ?? const [];
      final hasAudio = streams.any((stream) => stream.getType() == 'audio');
      final hasVideo = streams.any((stream) => stream.getType() == 'video');
      return hasAudio && !hasVideo;
    } catch (_) {
      return false;
    }
  }

  Future<void> _mergeWithAudio(LocalFile videoFile) async {
    const audioExtensions = ['.mp3', '.m4a', '.aac', '.wav', '.ogg', '.flac'];
    final folders = await _fileManager.getFolders();
    final folderNames = <String>{'Downloads', widget.folderName, ...folders.map((folder) => folder.name)};
    final candidates = <LocalFile>[];
    for (final name in folderNames) {
      final entries = await _fileManager.getFilesInFolder(name);
      for (final entry in entries) {
        if (entry.path == videoFile.path) continue;
        final lowerName = entry.name.toLowerCase();
        if (audioExtensions.any(lowerName.endsWith) || await _isWebmAudioOnly(entry)) {
          candidates.add(entry);
        }
      }
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No local audio files were found.')));
      return;
    }
    final audioPath = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose an audio track'),
        children: candidates.map((entry) => SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, entry.path),
          child: Text('${entry.name} • ${entry.sizeFormatted}', maxLines: 1, overflow: TextOverflow.ellipsis),
        )).toList(),
      ),
    );
    if (audioPath == null || !mounted) return;
    final dot = videoFile.path.lastIndexOf('.');
    final separator = videoFile.path.lastIndexOf(Platform.pathSeparator);
    final base = dot > separator ? videoFile.path.substring(0, dot) : videoFile.path;
    final outputPath = '${base}_merged.mp4';
    if (await File(outputPath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The merged output already exists. Rename or remove it first.')));
      return;
    }
    setState(() => _isMerging = true);
    final success = await FFmpegMergeService().mergeVideoAndAudio(
      videoPath: videoFile.path,
      audioPath: audioPath,
      outputPath: outputPath,
      quality: 'original',
    );
    if (!mounted) return;
    setState(() => _isMerging = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'Merged file saved: ${outputPath.split(Platform.pathSeparator).last}' : 'Could not merge these media files.'),
    ));
    if (success) await _refresh();
  }

  Future<void> _deleteFile(LocalFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Delete "${file.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await _fileManager.deleteFile(file.path);
    if (!mounted) return;
    if (deleted) {
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete this file.')));
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
          if (snapshot.hasError) return const Center(child: Text('Could not load this folder.'));
          final files = snapshot.data ?? const <LocalFile>[];
          if (files.isEmpty) {
            return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.folder_open_outlined, size: 56, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text('This folder is empty', style: TextStyle(color: AppColors.textSecondary)),
            ]));
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
                final audio = ['.mp3', '.m4a', '.aac', '.wav', '.ogg', '.flac'].any(lowerName.endsWith);
                final playable = audio || ['.mp4', '.m4v', '.mov', '.webm', '.mkv', '.3gp'].any(lowerName.endsWith);
                return ListTile(
                  leading: Icon(audio ? Icons.audio_file_outlined : Icons.video_file_outlined),
                  title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(file.sizeFormatted),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (playable) const Icon(Icons.play_circle_outline),
                    if (playable && !audio)
                      IconButton(tooltip: 'Merge with local audio', onPressed: _isMerging ? null : () => _mergeWithAudio(file), icon: const Icon(Icons.merge_type)),
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
                  ]),
                  onTap: playable
                      ? () => context.push('/local-player', extra: file.path)
                      : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This file format is not supported by the player.'))),
                );
              },
            ),
          );
        },
      ),
    );
  }
}