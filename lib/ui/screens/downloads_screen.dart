import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          if (downloads.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${downloads.items.length} items',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (downloads.items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    const Icon(
                      Icons.download_outlined,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No downloads yet',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Videos you download will appear here',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...downloads.items.map((item) {
              final selected = downloads.selectedIds.contains(item.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: selected
                      ? Border.all(color: AppColors.primaryStart, width: 2)
                      : null,
                ),
                child: ListTile(
                  leading: Checkbox(
                    value: selected,
                    onChanged: (_) => downloads.toggleSelection(item.id),
                    activeColor: AppColors.primaryStart,
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.format} • ${item.size}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 7),
                      LinearProgressIndicator(
                        value: (item.progress.clamp(0, 100) / 100).toDouble(),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.status} • ${item.progress.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      var success = false;
                      switch (action) {
                        case 'pause':
                          success = await downloads.pauseDownload(item.id);
                          break;
                        case 'resume':
                          success = await downloads.resumeDownload(item.id);
                          break;
                        case 'cancel':
                          success = await downloads.cancelDownload(item.id);
                          break;
                        case 'retry':
                          success = await downloads.retryDownload(item.id);
                          break;
                        case 'delete':
                          final removed = await downloads.deleteFileFor(item);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  removed
                                      ? 'Download removed'
                                      : 'Download removed from the list, but its file could not be deleted',
                                ),
                              ),
                            );
                          }
                          return;
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Download action completed'
                                : 'Could not perform download action',
                          ),
                        ),
                      );
                    },
                    itemBuilder: (context) => [
                      if (item.status == 'failed' || item.status == 'cancelled')
                        const PopupMenuItem(
                          value: 'retry',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.refresh),
                            title: Text('Retry'),
                          ),
                        ),
                      if (item.status == 'downloading')
                        const PopupMenuItem(
                          value: 'pause',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.pause_circle_outline),
                            title: Text('Pause'),
                          ),
                        ),
                      if (item.status == 'paused')
                        const PopupMenuItem(
                          value: 'resume',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.play_circle_outline),
                            title: Text('Resume'),
                          ),
                        ),
                      if (item.status == 'downloading' ||
                          item.status == 'pending' ||
                          item.status == 'paused')
                        const PopupMenuItem(
                          value: 'cancel',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.cancel_outlined),
                            title: Text('Cancel'),
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_outline),
                          title: Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primaryStart,
        unselectedItemColor: AppColors.textSecondary,
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              break;
            case 2:
              context.go('/library');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.download_rounded), label: 'Downloads'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
        ],
      ),
      floatingActionButton: downloads.hasSelection
          ? FloatingActionButton.extended(
              onPressed: () async {
                final deletedCount = await downloads.removeSelected();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$deletedCount download(s) removed'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              backgroundColor: AppColors.danger,
              label: const Text('Delete Selected'),
              icon: const Icon(Icons.delete_forever_rounded),
            )
          : null,
    );
  }
}
