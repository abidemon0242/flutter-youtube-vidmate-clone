import '../../models/video_model.dart';
import '../../services/invidious_catalog_service.dart';

class YouTubeRepository {
  YouTubeRepository({InvidiousCatalogService? catalog})
    : _catalog = catalog ?? InvidiousCatalogService();

  final InvidiousCatalogService _catalog;

  void dispose() {}

  Future<List<VideoModel>> getFeedVideos({
    required List<VideoModel> subscribedVideos,
    String category = 'Trending',
    String recommendationQuery = '',
  }) async {
    if (category == 'Subscriptions') {
      return List.unmodifiable(_unique(subscribedVideos));
    }
    try {
      final trending = await _catalog.fetchTrending(region: 'BD');
      var recommended = <VideoModel>[];
      if (recommendationQuery.trim().isNotEmpty) {
        try {
          recommended = await _catalog.searchVideos(
            recommendationQuery,
            region: 'BD',
          );
        } on InvidiousCatalogException {
          // Keep the fresh trending and imported channel feed available.
        }
      }
      return List.unmodifiable(
        _unique([...subscribedVideos, ...recommended, ...trending]),
      );
    } on InvidiousCatalogException {
      if (subscribedVideos.isNotEmpty) {
        return List.unmodifiable(_unique(subscribedVideos));
      }
      rethrow;
    }
  }

  Future<List<VideoModel>> searchVideos(
    String query, {
    List<VideoModel> availableVideos = const [],
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    try {
      final remote = await _catalog.searchVideos(term, region: 'BD');
      final combined = _unique([
        ...remote,
        ..._localSearch(term, availableVideos),
      ]);
      return List.unmodifiable(combined);
    } on InvidiousCatalogException {
      final local = _localSearch(term, availableVideos);
      if (local.isNotEmpty) return List.unmodifiable(local);
      rethrow;
    }
  }

  List<VideoModel> _localSearch(
    String query,
    List<VideoModel> availableVideos,
  ) {
    final terms = query.toLowerCase().split(RegExp(r'\s+'));
    return availableVideos.where((video) {
      final haystack = '${video.title} ${video.channelName} ${video.category}'
          .toLowerCase();
      return terms.every(haystack.contains);
    }).toList();
  }

  List<VideoModel> _unique(Iterable<VideoModel> videos) {
    final unique = <String, VideoModel>{};
    for (final video in videos) {
      unique.putIfAbsent(video.id, () => video);
    }
    return unique.values.toList(growable: false);
  }

  List<String> getCategories() => const ['Trending', 'Subscriptions'];
}
