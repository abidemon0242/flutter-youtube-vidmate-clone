import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/services/invidious_catalog_service.dart';

void main() {
  const videoId = 'abcdefghijk';
  final sampleVideo = {
    'type': 'video',
    'videoId': videoId,
    'title': 'Public catalog result',
    'author': 'Example channel',
    'viewCount': 1200,
    'lengthSeconds': 125,
    'publishedText': '2 days ago',
    'videoThumbnails': [
      {'quality': 'medium', 'url': 'https://img.example.test/thumb.jpg'},
    ],
  };

  group('InvidiousCatalogService', () {
    test('searches public video metadata without an API key', () async {
      Uri? requested;
      final service = InvidiousCatalogService(
        instanceUris: [Uri.https('catalog.example.test', '')],
        loader: (uri) async {
          requested = uri;
          return jsonEncode([sampleVideo]);
        },
      );

      final videos = await service.searchVideos('flutter tutorial');

      expect(requested?.path, '/api/v1/search');
      expect(requested?.queryParameters['q'], 'flutter tutorial');
      expect(requested?.queryParameters['type'], 'video');
      expect(requested?.queryParameters['region'], 'BD');
      expect(videos, hasLength(1));
      expect(videos.single.id, videoId);
      expect(videos.single.title, 'Public catalog result');
      expect(videos.single.duration, '02:05');
      expect(
        videos.single.playbackUrl,
        'https://www.youtube.com/watch?v=$videoId',
      );
      expect(videos.single.thumbnailUrl, 'https://img.example.test/thumb.jpg');
    });

    test('loads trending metadata for the Bangladesh region', () async {
      Uri? requested;
      final service = InvidiousCatalogService(
        instanceUris: [Uri.https('catalog.example.test', '')],
        loader: (uri) async {
          requested = uri;
          return jsonEncode([sampleVideo]);
        },
      );

      final videos = await service.fetchTrending();

      expect(requested?.path, '/api/v1/trending');
      expect(requested?.queryParameters['region'], 'BD');
      expect(videos.single.category, 'Trending');
    });

    test('ignores non-video entries and duplicate video IDs', () async {
      final service = InvidiousCatalogService(
        instanceUris: [Uri.https('catalog.example.test', '')],
        loader: (_) async => jsonEncode([
          sampleVideo,
          sampleVideo,
          {'type': 'channel', 'author': 'A channel'},
          {'type': 'video', 'videoId': 'bad', 'title': 'Invalid ID'},
        ]),
      );

      final videos = await service.searchVideos('example');

      expect(videos, hasLength(1));
      expect(videos.single.id, videoId);
    });

    test('fails over to the next public instance', () async {
      final requestedHosts = <String>[];
      final service = InvidiousCatalogService(
        instanceUris: [
          Uri.https('first.example.test', ''),
          Uri.https('second.example.test', ''),
        ],
        loader: (uri) async {
          requestedHosts.add(uri.host);
          if (uri.host == 'first.example.test') {
            throw Exception('temporary outage');
          }
          return jsonEncode([sampleVideo]);
        },
      );

      final videos = await service.fetchTrending();

      expect(requestedHosts, ['first.example.test', 'second.example.test']);
      expect(videos, hasLength(1));
    });
  });
}
