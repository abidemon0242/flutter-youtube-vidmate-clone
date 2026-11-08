import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/services/youtube_rss_service.dart';

const channelId = 'UC0123456789012345678901';

void main() {
  group('YouTubeChannelRssService', () {
    test('parses a public channel RSS feed without an API key', () async {
      Uri? requested;
      final service = YouTubeChannelRssService(loader: (uri) async {
        requested = uri;
        return '''
          <feed xmlns="http://www.w3.org/2005/Atom"
                xmlns:yt="http://www.youtube.com/xml/schemas/2015">
            <title>Example Channel</title>
            <author><name>Example Creator</name></author>
            <entry>
              <yt:videoId>abcdefghijk</yt:videoId>
              <title>Latest upload</title>
              <published>2026-11-08T08:00:00+00:00</published>
            </entry>
          </feed>
        ''';
      });
      final videos = await service.fetchChannel(
        'https://www.youtube.com/channel/$channelId',
      );
      expect(requested?.queryParameters['channel_id'], channelId);
      expect(videos, hasLength(1));
      expect(videos.single.id, 'abcdefghijk');
      expect(videos.single.title, 'Latest upload');
      expect(videos.single.channelName, 'Example Creator');
      expect(videos.single.playbackUrl, contains('youtube.com/watch?v='));
    });

    test('accepts a channel RSS URL', () async {
      final service = YouTubeChannelRssService(
        loader: (_) async => '<feed xmlns="http://www.w3.org/2005/Atom"/>',
      );
      expect(
        service.channelIdFromInput(
          'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId',
        ),
        channelId,
      );
    });

    test('rejects unsupported handles and non-YouTube URLs clearly', () {
      final service = YouTubeChannelRssService();
      expect(
        () => service.channelIdFromInput('https://example.com/channel'),
        throwsA(isA<YouTubeRssException>()),
      );
      expect(
        () => service.channelIdFromInput('https://www.youtube.com/@creator'),
        throwsA(isA<YouTubeRssException>()),
      );
    });
  });
}
