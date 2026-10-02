import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';

class BatchDownloadBar extends StatelessWidget {
  const BatchDownloadBar({
    super.key,
    required this.selectedCount,
    required this.onDownloadAll,
    required this.onCancel,
  });

  final int selectedCount;
  final VoidCallback onDownloadAll;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: selectedCount > 0 ? 70 : 0,
      color: AppColors.darkSurface,
      child: selectedCount > 0
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$selectedCount video${selectedCount > 1 ? 's' : ''} selected',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'Default: 720p',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onDownloadAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryStart,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Download All'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
