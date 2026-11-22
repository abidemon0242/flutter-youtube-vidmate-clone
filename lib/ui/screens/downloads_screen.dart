import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/video_model.dart';
import '../../providers/downloads_provider.dart';
import '../../services/youtube_extraction_service.dart';
import '../widgets/download_options_sheet.dart';
import '../widgets/file_actions.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    final selecting = downloads.hasSelection;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) downloads.clearSelection();
      },
      child: Scaffold(
        appBar: selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: downloads.clearSelection,
                ),
                title: Text('${downloads.selectedIds.length} selected'),
                actions: [
                  TextButton(onPressed: downloads.selectAll, child: const Text('Select all')),
                  IconButton(
                    tooltip: 'Remove from list (keep files)',
                    icon: const Icon(Icons.playlist_remove_rounded),
                    onPressed: downloads.removeSelected,
                  ),
                ],
              )
            : AppBar(
                automaticallyImplyLeading: false,
                title: const Text('Downloads'),
                actions: [
                  if (downloads.items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Center(child: Text('${downloads.items.length} items')),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Download settings',
                    onSelected: (value) {
                      if (value == 'wifi') downloads.setWifiOnly(!downloads.wifiOnly);
                    },
                    itemBuilder: (_) => [
                      CheckedPopupMenuItem(
                        value: 'wifi',
                        checked: downloads.wifiOnly,
                        child: const Text('Download on Wi-Fi only'),
                      ),
                    ],
                  ),
                ],
              ),
        body: downloads.items.isEmpty && !downloads.waitingForWifi
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_outlined, size: 64, color: context.textSecondary),
                      SizedBox(height: 16),
                      Text(
                        'No downloads yet',
                        style: TextStyle(color: context.textSecondary, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Open a video and tap Download, or paste a YouTube link on Home.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  if (downloads.waitingForWifi)
                    MaterialBanner(
                      leading: const Icon(Icons.wifi_off_rounded),
                      content: const Text('Waiting for Wi-Fi. Downloads continue when Wi-Fi is back.'),
                      actions: [
                        TextButton(onPressed: () => downloads.setWifiOnly(false), child: const Text('Use mobile data')),
                      ],
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: downloads.items.length,
                      itemBuilder: (context, index) => _DownloadTile(entry: downloads.items[index]),
                    ),
                  ),
                ],
              ),
        floatingActionButton: selecting
            ? FloatingActionButton.extended(
                onPressed: () => _confirmDeleteSelected(context, downloads),
                backgroundColor: AppColors.danger,
                label: const Text('Delete selected'),
                icon: const Icon(Icons.delete_forever_rounded),
              )
            : null,
      ),
    );
  }

  Future<void> _confirmDeleteSelected(BuildContext context, DownloadsProvider downloads) async {
    final count = downloads.selectedIds.length;
    final ok = await _confirm(context, 'Delete $count download(s)?', 'The files will be removed from this device.');
    if (!ok || !context.mounted) return;
    final removed = await downloads.deleteSelectedFiles();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$removed download(s) deleted')));
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    ) ??
    false;

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.entry});
  final DownloadEntry entry;

  String _status(bool waitingForWifi) => switch (entry.status) {
    DownloadStatus.queued => waitingForWifi ? 'Waiting for Wi-Fi' : 'Waiting...',
    DownloadStatus.downloading =>
      '${(entry.progress * 100).toStringAsFixed(0)}% · ${formatBytes(entry.receivedBytes)} of ${formatBytes(entry.totalBytes)}',
    DownloadStatus.paused => 'Paused · ${(entry.progress * 100).toStringAsFixed(0)}%',
    DownloadStatus.merging =>
      entry.option.transcodesAudio ? 'Converting audio format...' : 'Combining video and audio...',
    DownloadStatus.completed => formatBytes(entry.totalBytes),
    DownloadStatus.failed => entry.error ?? 'Failed',
    DownloadStatus.canceled => 'Canceled',
  };

  @override
  Widget build(BuildContext context) {
    final downloads = context.read<DownloadsProvider>();
    final selecting = context.select<DownloadsProvider, bool>((d) => d.hasSelection);
    final selected = context.select<DownloadsProvider, bool>((d) => d.isSelected(entry.id));
    final waitingForWifi = context.select<DownloadsProvider, bool>((d) => d.waitingForWifi);
    final done = entry.status == DownloadStatus.completed;
    final audio = entry.option.kind == DownloadKind.audio;

    void play() => context.push(
      '/watch',
      extra: VideoModel(
        id: 'local:${entry.savedPath}',
        title: entry.title,
        channelName: entry.channelName,
        thumbnailUrl: entry.thumbnailUrl,
        localPath: entry.savedPath,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: selecting ? () => downloads.toggleSelection(entry.id) : (done ? play : null),
        onLongPress: () => downloads.toggleSelection(entry.id),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (selecting)
                Checkbox(value: selected, onChanged: (_) => downloads.toggleSelection(entry.id))
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 96,
                    height: 54,
                    child: entry.thumbnailUrl.isEmpty
                        ? ColoredBox(
                            color: context.placeholderColor,
                            child: Icon(Icons.movie_outlined, color: context.textSecondary),
                          )
                        : CachedNetworkImage(
                            imageUrl: entry.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => ColoredBox(
                              color: context.placeholderColor,
                              child: Icon(Icons.movie_outlined, color: context.textSecondary),
                            ),
                          ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.option.label} · ${entry.option.container.toUpperCase()}',
                      style: TextStyle(color: context.textSecondary, fontSize: 12),
                    ),
                    Text(
                      _status(waitingForWifi),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: entry.status == DownloadStatus.failed ? AppColors.danger : context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (entry.isActive || entry.status == DownloadStatus.paused) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: entry.status == DownloadStatus.merging || entry.status == DownloadStatus.queued
                            ? null
                            : entry.progress,
                      ),
                    ],
                  ],
                ),
              ),
              if (!selecting) ...[
                if (entry.status == DownloadStatus.downloading || entry.status == DownloadStatus.queued)
                  IconButton(
                    tooltip: 'Pause',
                    onPressed: () => downloads.pause(entry.id),
                    icon: const Icon(Icons.pause_rounded),
                  ),
                if (entry.status == DownloadStatus.paused)
                  IconButton(
                    tooltip: 'Resume',
                    onPressed: () => downloads.resume(entry.id),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                if (entry.status == DownloadStatus.failed || entry.status == DownloadStatus.canceled)
                  IconButton(
                    tooltip: 'Retry',
                    onPressed: () => downloads.retry(entry.id),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                if (done)
                  IconButton(tooltip: 'Play', onPressed: play, icon: const Icon(Icons.play_circle_outline_rounded)),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (action) async {
                    final messenger = ScaffoldMessenger.of(context);
                    switch (action) {
                      case 'cancel':
                        await downloads.cancel(entry.id);
                      case 'save':
                        await saveFileToPhone(context, entry.savedPath, audio: audio);
                      case 'share':
                        await shareFile(context, entry.savedPath, title: entry.title, audio: audio);
                      case 'remove':
                        await downloads.remove(entry, deleteFile: false);
                        messenger.showSnackBar(const SnackBar(content: Text('Removed from list. The file was kept.')));
                      case 'delete':
                        if (!await _confirm(context, 'Delete this download?', entry.title)) return;
                        final deleted = await downloads.remove(entry);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(deleted ? 'Download deleted.' : 'Removed from list (no file to delete).'),
                          ),
                        );
                    }
                  },
                  itemBuilder: (_) => [
                    if (entry.isActive || entry.status == DownloadStatus.paused)
                      const PopupMenuItem(value: 'cancel', child: Text('Cancel download')),
                    if (done) ...const [
                      PopupMenuItem(value: 'save', child: Text('Save to phone')),
                      PopupMenuItem(value: 'share', child: Text('Share')),
                    ],
                    const PopupMenuItem(value: 'remove', child: Text('Remove from list')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete file')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
