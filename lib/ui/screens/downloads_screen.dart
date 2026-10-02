import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads & Library'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (downloads.items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: Text(
                  'No downloads yet',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
                ),
              ),
            )
          else
            ...downloads.items.map((item) {
              final selected = downloads.selectedIds.contains(item.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Checkbox(
                    value: selected,
                    onChanged: (_) => downloads.toggleSelection(item.id),
                  ),
                  title: Text(item.title),
                  subtitle: Text('${item.format} · ${item.size}'),
                  trailing: IconButton(
                    onPressed: () => downloads.deleteFileFor(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              );
            }),
        ],
      ),
      floatingActionButton: downloads.hasSelection
          ? FloatingActionButton.extended(
              onPressed: () {
                downloads.removeSelected();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selected downloads removed.')),
                );
              },
              label: const Text('Delete Selected'),
              icon: const Icon(Icons.delete_forever_rounded),
            )
          : null,
    );
  }
}
