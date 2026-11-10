import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/data/repositories/youtube_repository.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/services/invidious_catalog_service.dart';

void main() {
  test('local search splits a multi-word query into separate terms', () async {
    final catalog = InvidiousCatalogService(
      instanceUris: [Uri.https('catalog.example', '')],
      loader: (_) async => throw const InvidiousCatalogException('offline'),
    );
    final repository = YouTubeRepository(catalog: catalog);
    const match = VideoModel(
      id: 'searchmatch01',
      title: 'Space exploration explained',
      channelName: 'Science Channel',
      views: '1K views',
      duration: '10:00',
      thumbnailUrl: '',
      channelAvatar: '',
      isVerified: false,
    );
    const noMatch = VideoModel(
      id: 'searchmatch02',
      title: 'Cooking at home',
      channelName: 'Food Channel',
      views: '1K views',
      duration: '10:00',
      thumbnailUrl: '',
      channelAvatar: '',
      isVerified: false,
    );

    final results = await repository.searchVideos(
      'space   exploration',
      availableVideos: const [match, noMatch],
    );

    expect(results.map((video) => video.id), ['searchmatch01']);
  });
}
