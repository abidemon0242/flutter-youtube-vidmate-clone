import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int get _selectedCount => context.watch<DownloadsProvider>().selectedIds.length;

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
                  subtitle: Text(
                    '${item.format} • ${item.size}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        child: Text('Move'),
                      ),
                      const PopupMenuItem(
                        child: Text('Rename'),
                      ),
                      const PopupMenuItem(
                        child: Text('Delete'),
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
              Navigator.pushNamed(context, '/');
              break;
            case 1:
              break;
            case 2:
              Navigator.pushNamed(context, '/library');
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
              onPressed: () {
                downloads.removeSelected();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_selectedCount} download(s) deleted'),
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
