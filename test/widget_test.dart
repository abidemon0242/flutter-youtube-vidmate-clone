import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/providers/downloads_provider.dart';
import 'package:tube_arena/services/ad_blocker_service.dart';

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
      expect(video.category, 'Tech');
    });
  });

  group('DownloadsProvider', () {
    test('adds and removes selected entries', () {
      final provider = DownloadsProvider();
      final entry = DownloadEntry(
        id: 'one',
        title: 'One',
        url: 'https://example.com/one.mp4',
        size: '1 MB',
        format: 'mp4',
        progress: 0,
        savedPath: '/tmp/one.mp4',
      );
      provider.addDownload(entry);
      expect(provider.items, hasLength(1));
      provider.toggleSelection('one');
      provider.removeSelected();
      expect(provider.items, isEmpty);
      expect(provider.hasSelection, isFalse);
      provider.dispose();
    });

    test('refuses to delete files outside the managed downloads folder', () async {
      final directory = await Directory.systemTemp.createTemp('tube-arena-test-');
      final file = File('${directory.path}/unmanaged.mp4');
      await file.writeAsString('keep');
      final provider = DownloadsProvider()
        ..addDownload(DownloadEntry(id: 'external', title: 'External', url: 'https://example.com/a.mp4', size: '4 B', format: 'mp4', progress: 100, savedPath: file.path));
      expect(await provider.deleteFileFor(provider.items.single), isFalse);
      expect(await file.exists(), isTrue);
      expect(provider.items, hasLength(1));
      provider.dispose();
      await directory.delete(recursive: true);
    });

    test('deletes selected file before removing its record', () async {
      final directory = await Directory.systemTemp.createTemp('tube-arena-test-');
      final downloadsDirectory = Directory('${directory.path}/TubeArena/Downloads');
      await downloadsDirectory.create(recursive: true);
      final file = File('${downloadsDirectory.path}/sample.mp4');
      await file.writeAsString('sample');
      final provider = DownloadsProvider()
        ..addDownload(
          DownloadEntry(
            id: 'file-one',
            title: 'Sample',
            url: 'https://example.com/sample.mp4',
            size: '6 B',
            format: 'mp4',
            progress: 100,
            savedPath: file.path,
          ),
        )
        ..toggleSelection('file-one');

      expect(await provider.deleteSelectedFiles(), 1);
      expect(await file.exists(), isFalse);
      expect(provider.items, isEmpty);
      provider.dispose();
      await directory.delete(recursive: true);
    });
  });

  group('AdBlockerService URL matching', () {
    final blocker = AdBlockerService();

    test('blocks ad host subdomains without matching lookalikes', () {
      expect(blocker.isAdDomain('https://ads.doubleclick.net/banner'), isTrue);
      expect(blocker.isAdDomain('https://notdoubleclick.net/banner'), isFalse);
    });

    test('does not classify YouTube privacy-enhanced host as advertising', () {
      expect(blocker.isAdDomain('https://www.youtube-nocookie.com/embed/demo'), isFalse);
    });

    test('matches known tracking URL paths', () {
      expect(blocker.isAdDomain('https://www.facebook.com/tr?id=123'), isTrue);
    });
  });
}
