import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/video_model.dart';

class YouTubeRepository {
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

  Future<List<VideoModel>> getFeedVideos({String category = 'All'}) async {
    // YoutubeExplode does not expose YouTube's official trending feed. Use
    // live public search results instead of presenting fabricated demo cards
    // as current trending videos.
    const queries = <String, String>{
      'All': 'trending videos',
      'Music': 'popular music videos',
      'Tech': 'technology news and gadgets',
      'Movies': 'movie trailers',
      'Tutorials': 'programming tutorials',
      'Live': 'live streams',
      'News': 'latest news',
      'Gaming': 'gaming videos',
      'Design': 'graphic design tutorials',
    };
    final query = queries[category] ?? category;
    return searchVideos(query).timeout(const Duration(seconds: 35));
  }

  List<String> getCategories() => const [
        'All', 'Music', 'Tech', 'Movies', 'Tutorials', 'Live', 'News', 'Gaming', 'Design',
      ];
}
