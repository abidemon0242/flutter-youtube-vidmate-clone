import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/video_model.dart';

class MockYouTubeRepository {
  final YoutubeExplode _youtube = YoutubeExplode();

  void dispose() => _youtube.close();

  Future<List<VideoModel>> searchVideos(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final results = await _youtube.search
        .search(normalized)
        .timeout(const Duration(seconds: 30));
    return results.map((video) {
      final duration = video.duration;
      final durationLabel = duration == null
          ? (video.isLive ? 'LIVE' : '—')
          : _formatDuration(duration);
      return VideoModel(
        id: video.id.value,
        title: video.title,
        channelName: video.author,
        views: '${video.engagement.viewCount} views',
        duration: durationLabel,
        thumbnailUrl: video.thumbnails.highResUrl,
        channelAvatar: video.thumbnails.highResUrl,
        isVerified: false,
        category: 'Search',
        playbackUrl: video.url,
      );
    }).toList(growable: false);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds' : '$minutes:$seconds';
  }

  List<VideoModel> getTrendingVideos() => const [
        VideoModel(
          id: 'v1',
          title: 'Top 10 hidden features in Android apps that developers do not show',
          channelName: 'AppFlow',
          views: '1.9M views',
          duration: '08:11',
          thumbnailUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1200&q=80',
          channelAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
          isVerified: true,
          category: 'Tech',
        ),
        VideoModel(
          id: 'v2',
          title: 'How to build a beautiful modern dashboard in Flutter in 20 minutes',
          channelName: 'Flutter Craft',
          views: '845K views',
          duration: '14:02',
          thumbnailUrl: 'https://images.unsplash.com/photo-1522542550221-31fd19575a2d?auto=format&fit=crop&w=1200&q=80',
          channelAvatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=200&q=80',
          isVerified: false,
          category: 'Tutorials',
        ),
        VideoModel(
          id: 'v3',
          title: 'Mastering Figma for mobile product design with real workflow tips',
          channelName: 'Design Lens',
          views: '3.1M views',
          duration: '18:34',
          thumbnailUrl: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80',
          channelAvatar: 'https://images.unsplash.com/photo-1521119989659-a83eee488004?auto=format&fit=crop&w=200&q=80',
          isVerified: true,
          category: 'Design',
        ),
        VideoModel(
          id: 'v4',
          title: 'How to organize files, folders, and downloads for a clean media library',
          channelName: 'Tube Arena Docs',
          views: '520K views',
          duration: '09:50',
          thumbnailUrl: 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1200&q=80',
          channelAvatar: 'https://images.unsplash.com/photo-1504593811423-6dd665756598?auto=format&fit=crop&w=200&q=80',
          isVerified: true,
          category: 'Tutorials',
        ),
      ];

  List<String> getCategories() => const [
        'All', 'Music', 'Tech', 'Movies', 'Tutorials', 'Live', 'News', 'Gaming', 'Design',
      ];
}
