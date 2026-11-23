import '../../models/video_model.dart';
import '../../services/youtube_extraction_service.dart';
import '../paged_feed.dart';

class FeedResult {
  FeedResult({required this.feed, this.isSample = false, this.message});

  FeedResult.empty() : this(feed: PagedFeed.fixed(const []), isSample: true);

  /// The videos loaded so far; call [PagedFeed.loadMore] for the next page.
  final PagedFeed feed;

  List<VideoModel> get videos => feed.items;

  /// True when YouTube could not be reached and sample videos are shown.
  final bool isSample;
  final String? message;
}

/// Home feed: live YouTube search results per category, falling back to a
/// small set of sample videos when YouTube is unreachable.
class FeedRepository {
  FeedRepository(YoutubeExtractionService youtube) : _search = youtube.searchPage;

  /// For tests: any function that returns the first page of results.
  FeedRepository.withSearch(this._search);

  final Future<VideoPage> Function(String query, {String category}) _search;
  final Map<String, FeedResult> _cache = {};

  static const categories = ['All', 'Music', 'Tech', 'Movies', 'Tutorials', 'Live', 'News', 'Gaming', 'Design'];

  static const _categoryQueries = {
    'All': 'trending videos today',
    'Music': 'new music videos',
    'Tech': 'tech review',
    'Movies': 'official movie trailer',
    'Tutorials': 'tutorial for beginners',
    'Live': 'live stream now',
    'News': 'news today',
    'Gaming': 'gaming highlights',
    'Design': 'design tutorial',
  };

  Future<FeedResult> load({String category = 'All', String query = '', bool refresh = false}) async {
    final trimmed = query.trim();
    final key = '$category|$trimmed';
    if (!refresh && _cache.containsKey(key)) return _cache[key]!;
    final search = trimmed.isNotEmpty
        ? (category == 'All' ? trimmed : '$trimmed $category')
        : _categoryQueries[category] ?? category;
    try {
      final result = FeedResult(feed: PagedFeed(await _search(search, category: category)));
      _cache[key] = result;
      return result;
    } on YoutubeServiceException catch (error) {
      final fallback = FeedResult(
        feed: PagedFeed.fixed(_samples(category, trimmed)),
        isSample: true,
        message: error.message,
      );
      // A failed refresh must not leave an older feed cached under this key.
      _cache[key] = fallback;
      return fallback;
    }
  }

  List<VideoModel> _samples(String category, String query) {
    final q = query.toLowerCase();
    return sampleVideos
        .where((v) => category == 'All' || v.category == category)
        .where((v) => q.isEmpty || v.title.toLowerCase().contains(q) || v.channelName.toLowerCase().contains(q))
        .toList();
  }
}

/// Offline sample content. These play a short public-domain clip and cannot
/// be downloaded.
const sampleVideos = [
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
    playbackUrl: VideoModel.samplePlaybackUrl,
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
    playbackUrl: VideoModel.samplePlaybackUrl,
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
    playbackUrl: VideoModel.samplePlaybackUrl,
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
    playbackUrl: VideoModel.samplePlaybackUrl,
  ),
];
