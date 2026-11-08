import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/services/personalization_service.dart';

void main() {
  late Directory temp;
  late PersonalizationService profile;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ta-profile-');
    profile = PersonalizationService(
      directoryResolver: () async => temp,
    );
    await profile.initialize();
    await profile.setConsent(true);
  });
  tearDown(() async {
    profile.dispose();
    await temp.delete(recursive: true);
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
  test('explains playlist import limitation in no-key mode', () async {
    await expectLater(
      profile.importPlaylist('https://youtube.com/playlist?list=PL1234567890'),
      throwsA(isA<PlaylistImportException>()),
    );
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
    profile = PersonalizationService(
      directoryResolver: () async => temp,
    );
    await profile.initialize();
    expect(profile.activityCount, 1);
    expect(profile.interestProfile['cybersecurity'], greaterThan(0));
  });
}
