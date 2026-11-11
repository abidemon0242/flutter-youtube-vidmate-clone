import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/providers/downloads_provider.dart';
import 'package:tube_arena/services/background_download_service.dart';
import 'package:tube_arena/services/hls_resolution_service.dart';
import 'package:tube_arena/ui/widgets/video_card.dart';
import 'package:tube_arena/data/repositories/youtube_repository.dart';

void main() {
  testWidgets('VideoCard renders video metadata and responds to tap', (
    tester,
  ) async {
    var tapped = false;
    const video = VideoModel(
      id: 'widget-video',
      title: 'Widget test video',
      channelName: 'Test channel',
      views: '120 views',
      duration: '02:30',
      thumbnailUrl: '',
      channelAvatar: '',
      isVerified: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoCard(video: video, onTap: () => tapped = true),
        ),
      ),
    );
    expect(find.text('Widget test video'), findsOneWidget);
    expect(find.text('Test channel'), findsOneWidget);
    await tester.tap(find.text('Widget test video'));
    expect(tapped, isTrue);
  });

  group('HLS resolution discovery', () {
    test('parses available heights, bandwidths and relative playlist URLs', () {
      const manifest = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=650000,RESOLUTION=640x360
low/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1800000,RESOLUTION=1280x720
../hd/720.m3u8
#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=4200000,RESOLUTION=1920x1080
https://cdn.example/fullhd.m3u8
''';
      final options = HlsResolutionService.parseMasterPlaylist(
        Uri.parse('https://media.example/live/master.m3u8'),
        manifest,
      );
      expect(options, hasLength(3));
      expect(options.map((option) => option.height), [360, 720, 1080]);
      expect(options.first.url, 'https://media.example/live/low/index.m3u8');
      expect(options[1].url, 'https://media.example/hd/720.m3u8');
      expect(options.last.bandwidth, 4200000);
      expect(options.last.label, '1080p');
    });

    test('associates an external audio rendition with its video variant', () {
      const manifest = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="English",DEFAULT=YES,URI="audio/en.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=2200000,RESOLUTION=1280x720,AUDIO="aud"
video/720.m3u8
''';
      final options = HlsResolutionService.parseMasterPlaylist(
        Uri.parse('https://media.example/master.m3u8'),
        manifest,
      );
      expect(options.single.audioUrl, 'https://media.example/audio/en.m3u8');
    });

    test('rejects live HLS playlists without an end marker', () {
      expect(
        HlsResolutionService.isFiniteMediaPlaylist(
          '#EXTM3U\n#EXTINF:5,\nsegment.ts',
        ),
        isFalse,
      );
      expect(
        HlsResolutionService.isFiniteMediaPlaylist(
          '#EXTM3U\n#EXTINF:5,\nsegment.ts\n#EXT-X-ENDLIST',
        ),
        isTrue,
      );
    });

    test('rejects non-network and credential-bearing HLS URLs', () {
      expect(
        HlsResolutionService.isSupportedMediaUrl('file:///data/video.m3u8'),
        isFalse,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl('ftp://cdn.example/video.m3u8'),
        isFalse,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'https://user:pass@cdn.example/video.m3u8',
        ),
        isFalse,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'https://cdn.example/video.m3u8',
        ),
        isTrue,
      );
    });

    test('requires a real completed media playlist, not ENDLIST alone', () {
      expect(
        HlsResolutionService.isFiniteMediaPlaylist(
          '#EXTM3U\\n#EXT-X-ENDLIST',
        ),
        isFalse,
      );
      expect(
        HlsResolutionService.isFiniteMediaPlaylist(
          '#EXTM3U\\n#EXTINF:0,\\nsegment.ts\\n#EXT-X-ENDLIST',
        ),
        isFalse,
      );
      expect(
        HlsResolutionService.isFiniteMediaPlaylist(
          '#EXTM3U\\n#EXTINF:5,\\nsegment.ts\\n#EXT-X-ENDLIST',
        ),
        isTrue,
      );
    });

    test('accepts external HLS manifests but rejects YouTube pages', () {
      expect(
        HlsResolutionService.isSupportedManifestUrl(
          'https://cdn.example/master.m3u8',
        ),
        isTrue,
      );
      expect(
        HlsResolutionService.isSupportedManifestUrl(
          'https://www.youtube.com/watch?v=abcdefghijk',
        ),
        isFalse,
      );
    });
  });

  group('YouTubeRepository', () {
    test('provides supported live-feed categories', () {
      final repository = YouTubeRepository();
      expect(repository.getCategories(), ['Trending', 'Subscriptions']);
      repository.dispose();
    });
  });

  group('VideoModel', () {
    test('demo playback URL is non-empty and HTTPS', () {
      expect(VideoModel.demo.playbackUrl, startsWith('https://'));
      expect(VideoModel.demo.title, contains('Tube Arena'));
    });

    test(
      'existing video data can omit playbackUrl and gets sample default',
      () {
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
      },
    );
  });

  group('DownloadEntry persistence', () {
    test('round-trips progress, status, and saved file metadata', () {
      final entry = DownloadEntry(
        id: 'persisted-video',
        title: 'Persisted video',
        url: 'https://example.com/video.mp4',
        sourceUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
        size: '12 MB',
        format: '720p MP4',
        progress: 67.5,
        savedPath: '/private/TubeArena/Downloads/video.mp4',
        status: 'downloading',
      );

      final restored = DownloadEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, entry.id);
      expect(restored.title, entry.title);
      expect(restored.sourceUrl, entry.sourceUrl);
      expect(restored.progress, entry.progress);
      expect(restored.status, entry.status);
      expect(restored.savedPath, entry.savedPath);
    });
  });

  group('Background download task persistence', () {
    test('preserves the source URL and processing state across restart', () {
      final task = AppDownloadTask(
        id: 'youtube-video-12345678901',
        title: 'Video',
        videoUrl: 'https://cdn.example/video',
        audioUrl: 'https://cdn.example/audio',
        sourceUrl: 'https://www.youtube.com/watch?v=12345678901',
        savePath: '/private/TubeArena/Downloads/video.mp4',
        quality: '720p',
        format: 'MP4',
        outputFormat: 'MP4',
        isAudioOnly: false,
        requiresMerge: true,
        status: DownloadStatus.processing,
        progress: 99,
        isMerging: true,
      );
      final restored = AppDownloadTask.fromJson(
        jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>,
      );
      expect(restored.sourceUrl, task.sourceUrl);
      expect(restored.requiresMerge, isTrue);
      expect(restored.status, DownloadStatus.processing);
      expect(restored.isMerging, isTrue);
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

    test(
      'refuses to delete files outside the managed downloads folder',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'tube-arena-test-',
        );
        final downloadsDirectory = Directory(
          '${directory.path}/TubeArena/Downloads',
        );
        await downloadsDirectory.create(recursive: true);
        final file = File('${directory.path}/unmanaged.mp4');
        await file.writeAsString('keep');
        final provider =
            DownloadsProvider(
              downloadsDirectoryResolver: () async => downloadsDirectory,
            )..addDownload(
              DownloadEntry(
                id: 'external',
                title: 'External',
                url: 'https://example.com/a.mp4',
                size: '4 B',
                format: 'mp4',
                progress: 100,
                savedPath: file.path,
              ),
            );
        expect(await provider.deleteFileFor(provider.items.single), isFalse);
        expect(await file.exists(), isTrue);
        expect(provider.items, hasLength(1));
        provider.dispose();
        await directory.delete(recursive: true);
      },
    );

    test('deletes selected file before removing its record', () async {
      final directory = await Directory.systemTemp.createTemp(
        'tube-arena-test-',
      );
      final downloadsDirectory = Directory(
        '${directory.path}/TubeArena/Downloads',
      );
      await downloadsDirectory.create(recursive: true);
      final file = File('${downloadsDirectory.path}/sample.mp4');
      await file.writeAsString('sample');
      final provider =
          DownloadsProvider(
              downloadsDirectoryResolver: () async => downloadsDirectory,
            )
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
}
