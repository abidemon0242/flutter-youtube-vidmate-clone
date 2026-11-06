import '../../models/video_model.dart';
import '../../services/youtube_data_api_service.dart';

class YouTubeRepository {
  YouTubeRepository({YouTubeDataApiService? api})
      : _api = api ?? YouTubeDataApiService();

  final YouTubeDataApiService _api;

  bool get isConfigured => _api.isConfigured;

  /// Kept for provider and test lifecycle compatibility. The API service
  /// creates and closes an HttpClient per request, so there is no open client.
  void dispose() {}

  Future<List<VideoModel>> searchVideos(String query) =>
      _api.searchVideos(query);

  Future<List<VideoModel>> getFeedVideos({String category = 'All'}) =>
      _api.getMostPopular(category: category, regionCode: 'BD');

  List<String> getCategories() => const [
        'All',
        'Music',
        'Tech',
        'Movies',
        'Tutorials',
        'Live',
        'News',
        'Gaming',
        'Design',
      ];
}
