import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/providers/downloads_provider.dart';
import 'package:tube_arena/services/background_download_service.dart';
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
  group('Download persistence models', () {
    test('DownloadEntry survives JSON serialization', () {
      final entry = DownloadEntry(
        id: 'sample-1',
        title: 'Sample video',
        url: 'https://example.com/video.mp4',
        size: '12 MB',
        format: '720p MP4',
        progress: 42,
        savedPath: '/app/TubeArena/Downloads/sample.mp4',
        status: 'downloading',
      );

      final restored = DownloadEntry.fromJson(entry.toJson());
      expect(restored.id, entry.id);
      expect(restored.title, entry.title);
      expect(restored.progress, 42);
      expect(restored.status, 'downloading');
      expect(restored.savedPath, entry.savedPath);
    });

    test('AppDownloadTask restores status and task metadata', () {
      final task = AppDownloadTask(
        id: 'sample-2',
        title: 'Authorized video',
        videoUrl: 'https://example.com/video.mp4',
        audioUrl: '',
        savePath: '/app/TubeArena/Downloads/video.mp4',
        quality: '720p',
        format: 'MP4',
        isAudioOnly: false,
        taskId: 'native-task-2',
        status: DownloadStatus.completed,
        progress: 100,
      );

      final restored = AppDownloadTask.fromJson(task.toJson());
      expect(restored.id, task.id);
      expect(restored.taskId, 'native-task-2');
      expect(restored.status, DownloadStatus.completed);
      expect(restored.progress, 100);
    });
  });
}
