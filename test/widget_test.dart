import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/services/youtube_extraction_service.dart';

void main() {
  group('VideoModel', () {
    test('stores the supplied video details', () {
      const video = VideoModel(
        id: 'video123',
        title: 'Example video',
        channelName: 'Example channel',
        views: '1K views',
        duration: '4:20',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        channelAvatar: 'https://example.com/avatar.jpg',
        isVerified: true,
      );

      expect(video.id, 'video123');
      expect(video.title, 'Example video');
      expect(video.channelName, 'Example channel');
      expect(video.isVerified, isTrue);
    });
  });

  group('Quality option models', () {
    test('video quality option has a readable summary', () {
      final option = VideoQualityOption(
        quality: '720p',
        format: 'MP4',
        fileSize: '50 MB',
        videoUrl: 'https://example.com/video.mp4',
        audioUrl: 'https://example.com/audio.m4a',
        fps: 30,
        bitrate: '2 Mbps',
      );

      expect(option.toString(), contains('720p'));
      expect(option.toString(), contains('50 MB'));
      expect(option.toString(), contains('30 fps'));
    });

    test('audio quality option has a readable summary', () {
      final option = AudioQualityOption(
        format: 'M4A',
        bitrate: '128 kbps',
        fileSize: '8 MB',
        audioUrl: 'https://example.com/audio.m4a',
      );

      expect(option.toString(), contains('M4A'));
      expect(option.toString(), contains('128 kbps'));
      expect(option.toString(), contains('8 MB'));
    });
  });
}
