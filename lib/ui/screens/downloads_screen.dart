import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads'), actions: [
        if (downloads.items.isNotEmpty)
          Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text('${downloads.items.length} items'))),
      ]),
      body: downloads.items.isEmpty
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.download_outlined, size: 64, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Text('No downloads yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('Downloads will appear here when enabled.', style: TextStyle(color: AppColors.textSecondary)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: downloads.items.length,
              itemBuilder: (context, index) {
                final item = downloads.items[index];
                final selected = downloads.selectedIds.contains(item.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Checkbox(value: selected, onChanged: (_) => downloads.toggleSelection(item.id)),
                    title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${item.format} • ${item.size}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'delete') {
                          downloads.deleteFileFor(item).then((deleted) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(deleted ? 'Download deleted.' : 'Could not delete this file.')),
                            );
                          });
                        }
                      },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
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
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.download_rounded), label: 'Downloads'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
        ],
      ),
      floatingActionButton: downloads.hasSelection
          ? FloatingActionButton.extended(
              onPressed: () {
                downloads.deleteSelectedFiles().then((count) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$count download(s) deleted')),
                  );
                });
              },
              backgroundColor: AppColors.danger,
              label: const Text('Delete Selected'),
              icon: const Icon(Icons.delete_forever_rounded),
            )
          : null,
    );
  }
}
