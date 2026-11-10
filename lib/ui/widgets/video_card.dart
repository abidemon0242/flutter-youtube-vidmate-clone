import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/video_model.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, this.onTap});

  final VideoModel video;
  final VoidCallback? onTap;

  void _showDownloadInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Download options', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              const Text(
                'This item is a YouTube watch-page link. Tube Arena does not extract YouTube streams, so resolution and format choices are not available for this source. You can download a direct media file that you own or have permission to save.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.push('/add-downloads');
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Add a direct media link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: video.thumbnailUrl.isEmpty
                      ? Container(
                          color: AppColors.card,
                          width: double.infinity,
                          height: 220,
                          child: const Icon(Icons.video_library_outlined),
                        )
                      : CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220,
                          placeholder: (context, url) =>
                              Container(color: AppColors.card, height: 220),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.card,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
                if (video.duration.isNotEmpty && video.duration != '—')
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        video.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: video.channelAvatar.isEmpty
                        ? null
                        : CachedNetworkImageProvider(video.channelAvatar),
                    child: video.channelAvatar.isEmpty
                        ? const Icon(Icons.person_outline, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              video.channelName,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            if (video.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                size: 12,
                                color: AppColors.primaryStart,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          video.views,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Video options',
                    onSelected: (value) {
                      if (value == 'download') _showDownloadInfo(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download_outlined),
                            SizedBox(width: 12),
                            Text('Download options'),
                          ],
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
