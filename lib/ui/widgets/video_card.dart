import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/video_model.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.multiSelectMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onCheckboxTap,
    this.onMore,
  });

  final VideoModel video;
  final VoidCallback? onTap;
  final bool multiSelectMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onCheckboxTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
                          color: context.placeholderColor,
                          height: 220,
                          width: double.infinity,
                          child: Icon(Icons.movie_outlined, size: 40, color: context.textSecondary),
                        )
                      : CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220,
                          placeholder: (context, url) => Container(color: context.placeholderColor, height: 220),
                          errorWidget: (context, url, error) => Container(
                            color: context.placeholderColor,
                            height: 220,
                            child: Icon(Icons.broken_image_outlined, color: context.textSecondary),
                          ),
                        ),
                ),
                if (video.duration.isNotEmpty)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        video.duration,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                if (multiSelectMode)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onCheckboxTap,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryStart : Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
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
                    backgroundColor: context.placeholderColor,
                    foregroundColor: context.textPrimary,
                    backgroundImage: video.channelAvatar.isEmpty
                        ? null
                        : CachedNetworkImageProvider(video.channelAvatar),
                    child: video.channelAvatar.isEmpty
                        ? Text(video.channelName.isEmpty ? '?' : video.channelName.characters.first.toUpperCase())
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
                          style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                video.channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.textSecondary, fontSize: 12),
                              ),
                            ),
                            if (video.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, size: 12, color: AppColors.primaryStart),
                            ],
                          ],
                        ),
                        if (video.metaLine.isNotEmpty)
                          Text(video.metaLine, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (onMore != null && video.isYoutube)
                    IconButton(
                      tooltip: 'More options',
                      onPressed: onMore,
                      icon: Icon(Icons.more_vert_rounded, color: context.textSecondary),
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
