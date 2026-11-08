import '../../models/video_model.dart';

class YouTubeRepository {
  const YouTubeRepository();

  List<VideoModel> getFeedVideos({
    required List<VideoModel> subscribedVideos,
    String category = 'All',
  }) {
    final unique = <String, VideoModel>{};
    for (final video in subscribedVideos) {
      if (category == 'All' || category == 'Subscriptions') {
        unique.putIfAbsent(video.id, () => video);
      }
    }
    final result = unique.values.toList()
      ..sort((a, b) => b.views.compareTo(a.views));
    return List.unmodifiable(result);
  }

  Future<List<VideoModel>> searchVideos(
    String query, {
    required List<VideoModel> availableVideos,
  }) async {
    final terms = query.toLowerCase().trim().split(RegExp(r'\s+'));
    if (terms.isEmpty || terms.every((term) => term.isEmpty)) return const [];
    final matches = availableVideos.where((video) {
      final haystack =
          '${video.title} ${video.channelName} ${video.category}'.toLowerCase();
      return terms.every(haystack.contains);
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return List.unmodifiable(matches);
  }

  List<String> getCategories() => const ['All', 'Subscriptions'];
}
