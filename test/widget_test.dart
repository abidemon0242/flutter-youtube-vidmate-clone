import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/providers/downloads_provider.dart';

void main() {
  group('VideoModel', () {
    test('demo playback URL is non-empty and HTTPS', () {
      expect(VideoModel.demo.playbackUrl, startsWith('https://'));
      expect(VideoModel.demo.title, contains('Tube Arena'));
    });

    test('existing video data can omit playbackUrl and gets sample default', () {
      const video = VideoModel(
        id: 'test',
        title: 'Test video',
        channelName: 'Test channel',
        views: '1 view',
        duration: '00:01',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        channelAvatar: 'https://example.com/avatar.jpg',
        isVerified: false,
      );
      expect(video.playbackUrl, VideoModel.demoPlaybackUrl);
    });
  });

  group('DownloadsProvider', () {
    test('adds and removes selected entries', () {
      final provider = DownloadsProvider();
      final entry = DownloadEntry(
        id: 'one', title: 'One', url: 'https://example.com/one.mp4',
        size: '1 MB', format: 'mp4', progress: 0, savedPath: '/tmp/one.mp4',
      );
      provider.addDownload(entry);
      expect(provider.items, hasLength(1));
      provider.toggleSelection('one');
      provider.removeSelected();
      expect(provider.items, isEmpty);
      expect(provider.hasSelection, isFalse);
      provider.dispose();
    });
  });
}
