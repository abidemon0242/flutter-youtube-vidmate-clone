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

    test('resolves a public @handle URL to a channel ID', () async {
      Uri? requested;
      final service = InvidiousCatalogService(
        instanceUris: [Uri.https('catalog.example.test', '')],
        loader: (uri) async {
          requested = uri;
          return jsonEncode({'ucid': 'UC0123456789012345678901'});
        },
      );

      final resolved = await service.resolveYoutubeUrl(
        'https://www.youtube.com/@examplecreator',
      );

      expect(requested?.path, '/api/v1/resolveurl');
      expect(
        requested?.queryParameters['url'],
        'https://www.youtube.com/@examplecreator',
      );
      expect(resolved.channelId, 'UC0123456789012345678901');
      expect(resolved.playlistId, isNull);
    });

    test('imports public playlist metadata and maps its videos', () async {
      final requested = <Uri>[];
      final service = InvidiousCatalogService(
        instanceUris: [Uri.https('catalog.example.test', '')],
        loader: (uri) async {
          requested.add(uri);
          if (uri.path == '/api/v1/resolveurl') {
            return jsonEncode({'playlistId': 'PL1234567890'});
          }
          return jsonEncode({
            'title': 'Public playlist',
            'author': 'Playlist owner',
            'videoCount': 1,
            'videos': [
              {
                'videoId': videoId,
                'title': 'Playlist video',
                'author': 'Example channel',
                'lengthSeconds': 90,
                'videoThumbnails': [
                  {'url': 'https://img.example.test/playlist.jpg'},
                ],
              },
            ],
          });
        },
      );

      final resolved = await service.resolveYoutubeUrl(
        'https://www.youtube.com/playlist?list=PL1234567890',
      );
      final playlist = await service.fetchPlaylist(resolved.playlistId!);

      expect(playlist.id, 'PL1234567890');
      expect(playlist.title, 'Public playlist');
      expect(playlist.channel, 'Playlist owner');
      expect(playlist.totalCount, 1);
      expect(playlist.videos.single.id, videoId);
      expect(playlist.videos.single.category, 'Imported playlist');
      expect(requested.last.path, '/api/v1/playlists/PL1234567890');
    });

    test('rejects non-YouTube URLs before contacting a catalog server', () async {
      var calls = 0;
      final service = InvidiousCatalogService(
        instanceUris: [Uri.https('catalog.example.test', '')],
        loader: (_) async {
          calls++;
          return '{}';
        },
      );

      await expectLater(
        service.resolveYoutubeUrl('https://example.com/playlist?list=PL1234567890'),
        throwsA(isA<InvidiousCatalogException>()),
      );
      expect(calls, 0);
    });
  });
}
