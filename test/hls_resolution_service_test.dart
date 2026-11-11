import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/services/hls_resolution_service.dart';

void main() {
  group('HLS URL validation', () {
    test('accepts HTTP and HTTPS media URLs', () {
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'https://cdn.example.com/media/720p.m3u8?token=abc',
        ),
        isTrue,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'http://media.example.org/audio/index.m3u8',
        ),
        isTrue,
      );
    });

    test('rejects unsupported schemes and embedded credentials', () {
      expect(
        HlsResolutionService.isSupportedMediaUrl('file:///etc/passwd'),
        isFalse,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'ftp://cdn.example.com/video.m3u8',
        ),
        isFalse,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'https://user:password@cdn.example.com/video.m3u8',
        ),
        isFalse,
      );
    });

    test('rejects YouTube watch and short-link hosts', () {
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'https://www.youtube.com/watch?v=example',
        ),
        isFalse,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'https://youtu.be/example',
        ),
        isFalse,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'https://music.youtube.com/video.m3u8',
        ),
        isFalse,
      );
    });

    test('does not reject deceptive lookalike hostnames', () {
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'https://youtube.com.evil.example/video.m3u8',
        ),
        isTrue,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(
          'https://notyoutube.com/video.m3u8',
        ),
        isTrue,
      );
    });

    test('manifest URLs must end in m3u8', () {
      expect(
        HlsResolutionService.isSupportedManifestUrl(
          'https://cdn.example.com/master.M3U8?token=abc',
        ),
        isTrue,
      );
      expect(
        HlsResolutionService.isSupportedManifestUrl(
          'https://cdn.example.com/video.mp4',
        ),
        isFalse,
      );
    });
  });

  group('HLS playlist validation', () {
    test(
      'recognizes completed media playlists only when ENDLIST exists',
      () {
        expect(
          HlsResolutionService.isFiniteMediaPlaylist(
            '#EXTM3U\n#EXTINF:4.0,\nsegment.ts\n#EXT-X-ENDLIST',
          ),
          isTrue,
        );
        expect(
          HlsResolutionService.isFiniteMediaPlaylist(
            '#EXTM3U\n#EXTINF:4.0,\nsegment.ts',
          ),
          isFalse,
        );
      },
    );

    test('resolves variant and audio URLs against the master URL', () {
      final masterUri = Uri.parse('https://cdn.example.com/hls/master.m3u8');
      const playlist = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",URI="../audio/index.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=1280x720,AUDIO="audio"
../video/720p.m3u8
''';

      final variants = HlsResolutionService.parseMasterPlaylist(
        masterUri,
        playlist,
      );

      expect(variants, hasLength(1));
      expect(
        variants.single.url,
        'https://cdn.example.com/video/720p.m3u8',
      );
      expect(
        variants.single.audioUrl,
        'https://cdn.example.com/audio/index.m3u8',
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(variants.single.url),
        isTrue,
      );
      expect(
        HlsResolutionService.isSupportedMediaUrl(variants.single.audioUrl!),
        isTrue,
      );
    });

    test('flags non-network URLs introduced by a playlist', () {
      final masterUri = Uri.parse('https://cdn.example.com/hls/master.m3u8');
      const playlist = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=640x360
file:///etc/passwd
''';

      final variants = HlsResolutionService.parseMasterPlaylist(
        masterUri,
        playlist,
      );

      expect(variants, hasLength(1));
      expect(
        HlsResolutionService.isSupportedMediaUrl(variants.single.url),
        isFalse,
      );
    });
  });
}
