import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          downloads.hasSelection
              ? '${downloads.selectedIds.length} selected'
              : 'Downloads',
        ),
        actions: [
          if (downloads.hasSelection)
            IconButton(
              tooltip: 'Clear selection',
              onPressed: downloads.clearSelection,
              icon: const Icon(Icons.close),
            ),
          IconButton(
            tooltip: 'Add video links',
            onPressed: () => context.push('/add-downloads'),
            icon: const Icon(Icons.add_link),
          ),
        ],
      ),
      body: downloads.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No downloads yet',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add an authorized video or audio link to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: downloads.items.length,
              itemBuilder: (context, index) {
                final item = downloads.items[index];
                final selected = downloads.selectedIds.contains(item.id);
                final completed = item.status == 'completed';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Checkbox(
                      value: selected,
                      onChanged: (_) => downloads.toggleSelection(item.id),
                    ),
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${item.format} • ${item.size}'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: item.status == 'processing'
                              ? null
                              : (item.progress.clamp(0, 100) / 100).toDouble(),
                          minHeight: 4,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.status == 'processing'
                              ? 'Merging file…'
                              : '${item.status} • ${item.progress.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    onTap: completed
                        ? () async {
                            final file = File(item.savedPath);
                            if (await file.exists() && context.mounted) {
                              context.push(
                                '/local-player',
                                extra: item.savedPath,
                              );
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'The downloaded file is missing.',
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        bool success;
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
                          case 'readd':
                            final source = item.sourceUrl;
                            if (source != null && source.isNotEmpty) {
                              context.push('/add-downloads', extra: source);
                            }
                            return;
                          case 'share':
                            try {
                              final file = File(item.savedPath);
                              if (await file.exists()) {
                                await Share.shareXFiles([
                                  XFile(item.savedPath),
                                ], text: item.title);
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'The downloaded file is missing.',
                                    ),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Could not export this file: $error',
                                    ),
                                  ),
                                );
                            }
                            return;
                          case 'delete':
                            success = await downloads.deleteFileFor(item);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Download and file removed.'
                                        : 'Could not safely remove this download.',
                                  ),
                                ),
                              );
                            }
                            return;
                          default:
                            return;
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Download action completed.'
                                    : 'Could not perform that download action.',
                              ),
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        if (item.status == 'processing')
                          const PopupMenuItem(
                            enabled: false,
                            child: Text('Merging — actions unavailable'),
                          ),
                        if (item.status == 'downloading')
                          const PopupMenuItem(
                            value: 'pause',
                            child: Text('Pause'),
                          ),
                        if (item.status == 'paused')
                          const PopupMenuItem(
                            value: 'resume',
                            child: Text('Resume'),
                          ),
                        if (item.status == 'pending' ||
                            item.status == 'downloading' ||
                            item.status == 'paused')
                          const PopupMenuItem(
                            value: 'cancel',
                            child: Text('Cancel'),
                          ),
                        if ((item.status == 'failed' ||
                                item.status == 'cancelled') &&
                            downloads.hasServiceTask(item.id))
                          const PopupMenuItem(
                            value: 'retry',
                            child: Text('Retry'),
                          ),
                        if ((item.status == 'failed' ||
                                item.status == 'cancelled') &&
                            item.sourceUrl != null &&
                            item.sourceUrl!.isNotEmpty)
                          const PopupMenuItem(
                            value: 'readd',
                            child: Text('Re-add source link'),
                          ),
                        if (completed)
                          const PopupMenuItem(
                            value: 'share',
                            child: Text('Share / export file'),
                          ),
                        if (item.status != 'processing')
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete file and record'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primaryStart,
        unselectedItemColor: AppColors.textSecondary,
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) context.go('/');
          if (index == 2) context.go('/library');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.download_rounded),
            label: 'Downloads',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            label: 'Library',
          ),
        ],
      ),
      floatingActionButton: downloads.hasSelection
          ? FloatingActionButton.extended(
              onPressed: () async {
                final count = await downloads.deleteSelectedFiles();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$count file(s) deleted')),
                  );
                }
              },
              backgroundColor: AppColors.danger,
              label: const Text('Delete selected'),
              icon: const Icon(Icons.delete_forever_rounded),
            )
          : FloatingActionButton(
              onPressed: () => context.push('/add-downloads'),
              tooltip: 'Add video links',
              child: const Icon(Icons.add_link),
            ),
    );
  }
}
