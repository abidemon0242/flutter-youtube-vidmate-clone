import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.folderName,
    required this.fileCount,
    required this.onTap,
    required this.onLongPress,
    required this.onRename,
    required this.onDelete,
    this.isSelected = false,
  });

  final String folderName;
  final int fileCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryStart.withValues(alpha: 0.2) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: AppColors.primaryStart, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 40,
                  color: isSelected ? AppColors.primaryStart : AppColors.accent,
                ),
                const SizedBox(height: 12),
                Text(
                  folderName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '$fileCount file${fileCount != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                tooltip: 'Folder actions',
                onSelected: (action) {
                  if (action == 'rename') onRename();
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                icon: const Icon(Icons.more_vert, size: 20),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                left: 8,
                child: Icon(Icons.check_circle, color: AppColors.primaryStart),
              ),
          ],
        ),
      ),
    );
  }
}
