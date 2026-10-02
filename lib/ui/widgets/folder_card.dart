import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.folderName,
    required this.fileCount,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
  });

  final String folderName;
  final int fileCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryStart.withOpacity(0.2) : AppColors.card,
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
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primaryStart,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
