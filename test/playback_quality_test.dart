import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tube_arena/models/playback_quality.dart';
import 'package:tube_arena/models/video_details.dart';
import 'package:tube_arena/providers/playback_settings.dart';
import 'package:tube_arena/services/youtube_extraction_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

PlaybackQuality q(int height, {int fps = 30, bool hls = false, int tag = 0, int bitrate = 0}) => PlaybackQuality(
  height: height,
  fps: fps,
  isHls: hls,
  tag: tag,
  bitrate: bitrate,
  url: Uri.parse('https://example.com/$height-$fps-$hls-$tag'),
);

Map<String, dynamic> _streamJson(
  int tag,
  String label,
  int width,
  int height, {
  String quality = 'medium360',
  int fps = 30,
  String codec = 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
}) => {
  'videoId': {'value': 'abcdefghijk'},
  'tag': tag,
  'url': 'https://example.com/$tag',
  'container': {'name': 'mp4'},
  'size': {'totalBytes': 1000},
  'bitrate': {'bitsPerSecond': tag * 1000},
  'audioCodec': 'mp4a.40.2',
  'videoCodec': 'avc1.42001E',
  'qualityLabel': label,
  'videoQuality': quality,
  'videoResolution': {'width': width, 'height': height},
  'framerate': {'framesPerSecond': fps},
  'codec': codec,
};

void main() {
  group('playback quality selection', () {
    test('merge sorts best first and keeps one entry per label', () {
      final merged = mergePlaybackQualities([
        q(360, tag: 18),
        q(1080, hls: true, tag: 96),
        q(720, hls: true, tag: 95),
        q(720, fps: 60, hls: true, tag: 300),
        q(360, hls: true, tag: 93),
      ]);
      expect(merged.map((e) => e.label), ['1080p', '720p60', '720p', '360p']);
    });

    test('progressive wins over HLS at the same label, then higher bitrate', () {
      final merged = mergePlaybackQualities([
        q(360, hls: true, tag: 93),
        q(360, tag: 18),
        q(720, hls: true, tag: 1, bitrate: 100),
        q(720, hls: true, tag: 2, bitrate: 900),
      ]);
      expect(merged.firstWhere((e) => e.height == 360).isHls, isFalse);
      expect(merged.firstWhere((e) => e.height == 720).tag, 2);
    });

    test('ignores streams without a resolution', () {
      expect(mergePlaybackQualities([q(0), q(-1)]), isEmpty);
    });

    test('picks the best quality not above the preference', () {
      final all = [q(360), q(480, hls: true), q(720, hls: true), q(1080, hls: true)];
      expect(pickPlaybackQuality(all, 720)!.height, 720);
      expect(pickPlaybackQuality(all, 600)!.height, 480);
      expect(pickPlaybackQuality(all, 0)!.height, 1080);
      expect(pickPlaybackQuality(all, 4320)!.height, 1080);
    });

    test('falls back to the lowest quality when all are above the preference', () {
      expect(pickPlaybackQuality([q(720), q(360)], 240)!.height, 360);
    });

    test('falls back to muxed 360p when no HLS is offered', () {
      expect(pickPlaybackQuality([q(360, tag: 18)], 1080)!.tag, 18);
      expect(pickPlaybackQuality(const [], 720), isNull);
    });

    test('parses quality labels', () {
      expect(parseQualityLabel('720p60'), (height: 720, fps: 60));
      expect(parseQualityLabel('1080p HDR'), (height: 1080, fps: 30));
      expect(parseQualityLabel('360p', fallbackFps: 25), (height: 360, fps: 25));
      expect(parseQualityLabel('tiny'), isNull);
    });

    test('labels and keys', () {
      expect(q(1080, fps: 60).label, '1080p60');
      expect(q(1080, fps: 30).label, '1080p');
      expect(q(720, hls: true, tag: 95).key, isNot(q(720, tag: 95).key));
    });
  });

  group('playable streams from a manifest', () {
    test('keeps muxed and HLS-with-audio streams, skips video-only and audio-only', () {
      final muxed = MuxedStreamInfo.fromJson(_streamJson(18, '360p', 640, 360));
      final hls = HlsMuxedStreamInfo.fromJson(
        _streamJson(96, '1080p', 1920, 1080, quality: 'high1080', codec: 'application/x-mpegURL'),
      );
      final shortHls = HlsMuxedStreamInfo.fromJson(
        _streamJson(95, '720p60', 720, 1280, quality: 'high720', fps: 60, codec: 'application/x-mpegURL'),
      );
      final videoOnly = VideoOnlyStreamInfo.fromJson({
        ..._streamJson(137, '1080p', 1920, 1080, quality: 'high1080', codec: 'video/mp4; codecs="avc1.640028"'),
        'fragments': <Map<String, dynamic>>[],
      });
      final qualities = playbackQualitiesFromStreams([muxed, hls, shortHls, videoOnly]);
      expect(qualities.map((e) => '${e.label}/${e.detail}'), ['1080p/HLS', '720p60/HLS', '360p/MP4']);
      expect(qualities.last.url, Uri.parse('https://example.com/18'));
    });
  });

  group('playback settings', () {
    test('defaults: background playback on, 720p', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await PlaybackSettings.load();
      expect(settings.backgroundPlayback, isTrue);
      expect(settings.preferredHeight, 720);
    });

    test('remembers changes', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await PlaybackSettings.load();
      await settings.setBackgroundPlayback(false);
      await settings.setPreferredHeight(1080);
      final reloaded = await PlaybackSettings.load();
      expect(reloaded.backgroundPlayback, isFalse);
      expect(reloaded.preferredHeight, 1080);
    });
  });

  group('video details', () {
    test('formats the stats line', () {
      final details = VideoDetails(viewCount: 1234567, likeCount: 1200, uploadDate: DateTime(2025, 3, 4));
      expect(details.statsLine, '1,234,567 views · 1,200 likes · Mar 4, 2025');
      expect(const VideoDetails(viewCount: 1).statsLine, '1 view');
      expect(const VideoDetails().statsLine, '');
      expect(VideoDetails.groupDigits(999), '999');
      expect(VideoDetails.groupDigits(1000), '1,000');
    });
  });
}
