import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final folders = ['Music', 'Tutorials', 'Movies', 'Shorts'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: folders.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final folder = folders[index];
            return Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open_rounded, size: 36, color: AppColors.primaryStart),
                  const SizedBox(height: 10),
                  Text(folder, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('12 files', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
