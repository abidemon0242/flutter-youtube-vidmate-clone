import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/services/personalization_service.dart';
import 'package:tube_arena/services/youtube_rss_service.dart';
import 'package:tube_arena/services/invidious_catalog_service.dart';

void main() {
  late Directory temp;
  late PersonalizationService profile;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ta-profile-');
    profile = PersonalizationService(directoryResolver: () async => temp);
    await profile.initialize();
    await profile.setConsent(true);
  });
  tearDown(() async {
    profile.dispose();
    await temp.delete(recursive: true);
  });

  test('channel subscriptions work without personalization consent', () async {
    const xml = '''
      <feed xmlns="http://www.w3.org/2005/Atom"
            xmlns:yt="http://www.youtube.com/xml/schemas/2015">
        <title>Creator</title>
        <author><name>Creator</name></author>
        <entry><yt:videoId>abcdefghijk</yt:videoId><title>Upload</title></entry>
      </feed>
    ''';
    profile.dispose();
    profile = PersonalizationService(
      directoryResolver: () async => temp,
      rssService: YouTubeChannelRssService(loader: (_) async => xml),
    );
    await profile.initialize();
    await profile.setConsent(false);
    final channel = await profile.addChannelFeed(
      'https://www.youtube.com/channel/UC0123456789012345678901',
    );
    expect(channel.videos.single.id, 'abcdefghijk');
    expect(profile.playlists, hasLength(1));
    await profile.clearActivity();
    expect(profile.playlists, hasLength(1));
  });

  test('search and likes improve ranking of related content', () async {
    await profile.record(type: 'search', query: 'Flutter programming');
    const liked = VideoModel(
      id: 'liked',
      title: 'Flutter programming basics',
      channelName: 'Dev',
      views: '1',
      duration: '1',
      thumbnailUrl: '',
      channelAvatar: '',
      isVerified: false,
      category: 'Tutorials',
    );
    const related = VideoModel(
      id: 'related',
      title: 'Advanced Flutter programming',
      channelName: 'Developer',
      views: '1',
      duration: '1',
      thumbnailUrl: '',
      channelAvatar: '',
      isVerified: false,
      category: 'Tutorials',
    );
    const other = VideoModel(
      id: 'other',
      title: 'Cooking dinner',
      channelName: 'Kitchen',
      views: '1',
      duration: '1',
      thumbnailUrl: '',
      channelAvatar: '',
      isVerified: false,
      category: 'Food',
    );
    await profile.record(type: 'like', video: liked);
    expect(profile.rankVideos([other, related]).first.id, 'related');
    expect(profile.interestProfile['flutter'], greaterThan(0));
  });
  test('rejects non-YouTube playlist URLs', () async {
    await expectLater(
      profile.importPlaylist('https://example.com/?list=PL1234567890'),
      throwsA(isA<PlaylistImportException>()),
    );
  });
  test('imports and persists a public playlist without a YouTube API key', () async {
    profile.dispose();
    profile = PersonalizationService(
      directoryResolver: () async => temp,
      catalogService: InvidiousCatalogService(
        instanceUris: [Uri.https('catalog.example.test', '')],
        loader: (uri) async => jsonEncode({
          'title': 'Imported playlist',
          'author': 'Creator',
          'videoCount': 1,
          'videos': [
            {
              'videoId': 'abcdefghijk',
              'title': 'First video',
              'author': 'Creator',
              'lengthSeconds': 60,
            },
          ],
        }),
      ),
    );
    await profile.initialize();
    final playlist = await profile.importPlaylist(
      'https://www.youtube.com/playlist?list=PL1234567890',
    );
    expect(playlist.id, 'playlist:PL1234567890');
    expect(playlist.videos.single.id, 'abcdefghijk');
    expect(profile.playlists, hasLength(1));

    profile.dispose();
    profile = PersonalizationService(directoryResolver: () async => temp);
    await profile.initialize();
    expect(profile.playlists.single.title, 'Imported playlist');
  });

  test('resolves a public channel handle before subscribing to RSS', () async {
    const xml = '''
      <feed xmlns="http://www.w3.org/2005/Atom"
            xmlns:yt="http://www.youtube.com/xml/schemas/2015">
        <title>Creator</title>
        <author><name>Creator</name></author>
        <entry><yt:videoId>abcdefghijk</yt:videoId><title>Upload</title></entry>
      </feed>
    ''';
    profile.dispose();
    profile = PersonalizationService(
      directoryResolver: () async => temp,
      rssService: YouTubeChannelRssService(loader: (_) async => xml),
      catalogService: InvidiousCatalogService(
        instanceUris: [Uri.https('catalog.example.test', '')],
        loader: (_) async => jsonEncode({
          'ucid': 'UC0123456789012345678901',
        }),
      ),
    );
    await profile.initialize();
    final channel = await profile.addChannelFeed(
      'https://www.youtube.com/@creator',
    );
    expect(channel.id, 'UC0123456789012345678901');
    expect(channel.videos.single.id, 'abcdefghijk');
  });

  test(
    'unlike and unsave feedback reduce previously learned interest',
    () async {
      const video = VideoModel(
        id: 'feedback',
        title: 'Flutter programming',
        channelName: 'Dev',
        views: '1',
        duration: '1',
        thumbnailUrl: '',
        channelAvatar: '',
        isVerified: false,
        category: 'Tutorials',
      );
      await profile.record(type: 'like', video: video);
      await profile.record(type: 'unlike', video: video);
      expect(profile.interestProfile['flutter'], closeTo(0, 0.0001));
    },
  );
  test('learns Bengali search terms', () async {
    await profile.record(type: 'search', query: 'কৃত্রিম বুদ্ধিমত্তা');
    expect(profile.interestProfile['কৃত্রিম'], greaterThan(0));
    expect(profile.interestProfile['বুদ্ধিমত্তা'], greaterThan(0));
  });
  test('persists and restores activity', () async {
    await profile.record(type: 'search', query: 'cybersecurity basics');
    profile.dispose();
    profile = PersonalizationService(directoryResolver: () async => temp);
    await profile.initialize();
    expect(profile.activityCount, 1);
    expect(profile.interestProfile['cybersecurity'], greaterThan(0));
  });
}
