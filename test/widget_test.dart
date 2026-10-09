import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';
import 'package:tube_arena/services/youtube_extraction_service.dart';
import 'package:tube_arena/models/video_model.dart';

import 'widget_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  group('YoutubeExtractionService Tests', () {
    late YoutubeExtractionService youtubeExtractionService;
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      youtubeExtractionService = YoutubeExtractionService();
      // Replace the dio instance with mock
      youtubeExtractionService.dio = mockDio;
    });

    group('extractVideoMetadata', () {
      const validYouTubeUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      const validVideoId = 'dQw4w9WgXcQ';

      test('should extract metadata successfully from valid YouTube URL', () async {
        // Arrange
        final mockResponse = Response(
          data: {
            'title': 'Test Video Title',
            'author_name': 'Test Channel',
            'thumbnail_url': 'https://example.com/thumbnail.jpg',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final metadata = await youtubeExtractionService.extractVideoMetadata(validYouTubeUrl);

        // Assert
        expect(metadata, isNotNull);
        expect(metadata['videoId'], equals(validVideoId));
        expect(metadata['title'], equals('Test Video Title'));
        expect(metadata['author'], equals('Test Channel'));
        expect(metadata['thumbnail'], equals('https://example.com/thumbnail.jpg'));
        expect(metadata['duration'], equals('12:45'));

        // Verify that dio.get was called with correct parameters
        verify(mockDio.get(
          'https://www.youtube.com/oembed',
          queryParameters: {
            'url': 'https://www.youtube.com/watch?v=$validVideoId',
            'format': 'json'
          },
        )).called(1);
      });

      test('should handle missing metadata fields gracefully', () async {
        // Arrange
        final mockResponse = Response(
          data: {
            'title': 'Video Without All Data',
            // Missing author_name and thumbnail_url
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final metadata = await youtubeExtractionService.extractVideoMetadata(validYouTubeUrl);

        // Assert
        expect(metadata['title'], equals('Video Without All Data'));
        expect(metadata['author'], equals('Unknown Channel')); // Default fallback
        expect(metadata['thumbnail'], equals('')); // Default fallback
      });

      test('should throw exception for invalid YouTube URL', () async {
        // Arrange
        const invalidUrl = 'https://example.com/notayoutubevideo';

        // Act & Assert
        expect(
          () => youtubeExtractionService.extractVideoMetadata(invalidUrl),
          throwsException,
        );
      });

      test('should handle DIO network errors', () async {
        // Arrange
        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          message: 'Network error',
        ));

        // Act & Assert
        expect(
          () => youtubeExtractionService.extractVideoMetadata(validYouTubeUrl),
          throwsA(isA<DioException>()),
        );
      });

      test('should handle timeout errors', () async {
        // Arrange
        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ));

        // Act & Assert
        expect(
          () => youtubeExtractionService.extractVideoMetadata(validYouTubeUrl),
          throwsA(isA<DioException>()),
        );
      });

      test('should extract video ID from youtu.be short URL', () async {
        // Arrange
        const shortUrl = 'https://youtu.be/dQw4w9WgXcQ';
        final mockResponse = Response(
          data: {
            'title': 'Short URL Video',
            'author_name': 'Channel',
            'thumbnail_url': 'https://example.com/thumb.jpg',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final metadata = await youtubeExtractionService.extractVideoMetadata(shortUrl);

        // Assert
        expect(metadata['videoId'], equals('dQw4w9WgXcQ'));
        expect(metadata['title'], equals('Short URL Video'));
      });

      test('should extract video ID from direct video ID string', () async {
        // Arrange
        const directVideoId = 'dQw4w9WgXcQ';
        final mockResponse = Response(
          data: {
            'title': 'Direct ID Video',
            'author_name': 'Channel',
            'thumbnail_url': 'https://example.com/thumb.jpg',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final metadata = await youtubeExtractionService.extractVideoMetadata(directVideoId);

        // Assert
        expect(metadata['videoId'], equals(directVideoId));
        expect(metadata['title'], equals('Direct ID Video'));
      });
    });

    group('getVideoQualities', () {
      const testUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

      test('should return list of video quality options', () async {
        // Act
        final qualities = await youtubeExtractionService.getVideoQualities(testUrl);

        // Assert
        expect(qualities, isNotNull);
        expect(qualities, isNotEmpty);
        expect(qualities.length, equals(6)); // 360p, 480p, 720p, 1080p, 2K, 4K
      });

      test('should contain expected quality levels', () async {
        // Act
        final qualities = await youtubeExtractionService.getVideoQualities(testUrl);
        final qualityStrings = qualities.map((q) => q.quality).toList();

        // Assert
        expect(qualityStrings, contains('360p'));
        expect(qualityStrings, contains('480p'));
        expect(qualityStrings, contains('720p'));
        expect(qualityStrings, contains('1080p'));
        expect(qualityStrings, contains('2K'));
        expect(qualityStrings, contains('4K'));
      });

      test('should have valid VideoQualityOption objects', () async {
        // Act
        final qualities = await youtubeExtractionService.getVideoQualities(testUrl);

        // Assert
        for (final quality in qualities) {
          expect(quality.quality, isNotEmpty);
          expect(quality.format, isNotEmpty);
          expect(quality.fileSize, isNotEmpty);
          expect(quality.videoUrl, isNotEmpty);
          expect(quality.audioUrl, isNotEmpty);
          expect(quality.fps, isPositive);
          expect(quality.bitrate, isNotEmpty);
        }
      });

      test('should have increasing fps for higher resolutions', () async {
        // Act
        final qualities = await youtubeExtractionService.getVideoQualities(testUrl);

        // Assert - 360p and 480p should have 24 fps
        expect(qualities[0].fps, equals(24));
        expect(qualities[1].fps, equals(24));

        // 720p and 1080p should have 30 fps
        expect(qualities[2].fps, equals(30));
        expect(qualities[3].fps, equals(30));

        // 2K and 4K should have 60 fps
        expect(qualities[4].fps, equals(60));
        expect(qualities[5].fps, equals(60));
      });

      test('should have increasing bitrate for higher resolutions', () async {
        // Act
        final qualities = await youtubeExtractionService.getVideoQualities(testUrl);

        // Assert
        final bitrates = qualities.map((q) => int.parse(q.bitrate.replaceAll('k', ''))).toList();
        for (int i = 0; i < bitrates.length - 1; i++) {
          expect(bitrates[i], lessThan(bitrates[i + 1]),
              reason: 'Bitrate should increase with resolution');
        }
      });

      test('should return valid video and audio URLs', () async {
        // Act
        final qualities = await youtubeExtractionService.getVideoQualities(testUrl);

        // Assert
        for (final quality in qualities) {
          expect(quality.videoUrl.startsWith('https://'), isTrue);
          expect(quality.audioUrl.startsWith('https://'), isTrue);
        }
      });

      test('should provide readable toString format', () async {
        // Act
        final qualities = await youtubeExtractionService.getVideoQualities(testUrl);
        final firstQualityString = qualities.first.toString();

        // Assert
        expect(firstQualityString, contains('360p'));
        expect(firstQualityString, contains('mp4'));
        expect(firstQualityString, contains('24 fps'));
      });
    });

    group('getAudioQualities', () {
      const testUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

      test('should return list of audio quality options', () async {
        // Act
        final audioQualities = await youtubeExtractionService.getAudioQualities(testUrl);

        // Assert
        expect(audioQualities, isNotNull);
        expect(audioQualities, isNotEmpty);
        expect(audioQualities.length, equals(5));
      });

      test('should contain MP3 and M4A formats', () async {
        // Act
        final audioQualities = await youtubeExtractionService.getAudioQualities(testUrl);
        final formats = audioQualities.map((a) => a.format).toList();

        // Assert
        expect(formats, contains('MP3'));
        expect(formats, contains('M4A'));
      });

      test('should have valid AudioQualityOption objects', () async {
        // Act
        final audioQualities = await youtubeExtractionService.getAudioQualities(testUrl);

        // Assert
        for (final audio in audioQualities) {
          expect(audio.format, isNotEmpty);
          expect(audio.bitrate, isNotEmpty);
          expect(audio.fileSize, isNotEmpty);
          expect(audio.audioUrl, isNotEmpty);
        }
      });

      test('should have valid bitrates', () async {
        // Act
        final audioQualities = await youtubeExtractionService.getAudioQualities(testUrl);

        // Assert
        final expectedBitrates = ['128 kbps', '192 kbps', '320 kbps', '128 kbps', '256 kbps'];
        expect(
          audioQualities.map((a) => a.bitrate).toList(),
          expectedBitrates,
        );
      });

      test('should return valid audio URLs', () async {
        // Act
        final audioQualities = await youtubeExtractionService.getAudioQualities(testUrl);

        // Assert
        for (final audio in audioQualities) {
          expect(audio.audioUrl.startsWith('https://'), isTrue);
          expect(audio.audioUrl, contains('.mp3') | contains('.m4a'));
        }
      });

      test('should provide readable toString format', () async {
        // Act
        final audioQualities = await youtubeExtractionService.getAudioQualities(testUrl);
        final firstAudioString = audioQualities.first.toString();

        // Assert
        expect(firstAudioString, contains('MP3'));
        expect(firstAudioString, contains('128 kbps'));
      });
    });

    group('Video ID Extraction Tests', () {
      test('should extract video ID from standard YouTube URL', () async {
        // Arrange
        const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
        final mockResponse = Response(
          data: {
            'title': 'Test',
            'author_name': 'Channel',
            'thumbnail_url': 'https://example.com/thumb.jpg',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final metadata = await youtubeExtractionService.extractVideoMetadata(url);

        // Assert
        expect(metadata['videoId'], equals('dQw4w9WgXcQ'));
      });

      test('should extract video ID from URL with additional parameters', () async {
        // Arrange
        const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10s&list=abc';
        final mockResponse = Response(
          data: {
            'title': 'Test',
            'author_name': 'Channel',
            'thumbnail_url': 'https://example.com/thumb.jpg',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final metadata = await youtubeExtractionService.extractVideoMetadata(url);

        // Assert
        expect(metadata['videoId'], equals('dQw4w9WgXcQ'));
      });

      test('should extract video ID from youtu.be URL with query parameters', () async {
        // Arrange
        const url = 'https://youtu.be/dQw4w9WgXcQ?t=10s';
        final mockResponse = Response(
          data: {
            'title': 'Test',
            'author_name': 'Channel',
            'thumbnail_url': 'https://example.com/thumb.jpg',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final metadata = await youtubeExtractionService.extractVideoMetadata(url);

        // Assert
        expect(metadata['videoId'], equals('dQw4w9WgXcQ'));
      });

      test('should accept 11-character video ID directly', () async {
        // Arrange
        const videoId = 'dQw4w9WgXcQ';
        final mockResponse = Response(
          data: {
            'title': 'Test',
            'author_name': 'Channel',
            'thumbnail_url': 'https://example.com/thumb.jpg',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final metadata = await youtubeExtractionService.extractVideoMetadata(videoId);

        // Assert
        expect(metadata['videoId'], equals(videoId));
      });
    });

    group('Error Handling Tests', () {
      test('should handle API returning empty response', () async {
        // Arrange
        const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
        final mockResponse = Response(
          data: {},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final metadata = await youtubeExtractionService.extractVideoMetadata(url);

        // Assert
        expect(metadata['title'], equals('Unknown'));
        expect(metadata['author'], equals('Unknown Channel'));
        expect(metadata['thumbnail'], equals(''));
      });

      test('should handle HTTP 404 response', () async {
        // Arrange
        const url = 'https://www.youtube.com/watch?v=invalidID';
        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            statusCode: 404,
            requestOptions: RequestOptions(path: ''),
          ),
        ));

        // Act & Assert
        expect(
          () => youtubeExtractionService.extractVideoMetadata(url),
          throwsException,
        );
      });

      test('should handle HTTP 403 Forbidden response', () async {
        // Arrange
        const url = 'https://www.youtube.com/watch?v=restrictedVideo';
        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            statusCode: 403,
            requestOptions: RequestOptions(path: ''),
          ),
        ));

        // Act & Assert
        expect(
          () => youtubeExtractionService.extractVideoMetadata(url),
          throwsException,
        );
      });

      test('should handle HTTP 500 server error', () async {
        // Arrange
        const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: ''),
          ),
        ));

        // Act & Assert
        expect(
          () => youtubeExtractionService.extractVideoMetadata(url),
          throwsException,
        );
      });
    });
  });

  group('VideoModel Tests', () {
    test('should create VideoModel with all required fields', () {
      // Act
      const video = VideoModel(
        id: 'test123',
        title: 'Test Video',
        channelName: 'Test Channel',
        views: '1M views',
        duration: '10:30',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        channelAvatar: 'https://example.com/avatar.jpg',
        isVerified: true,
      );

      // Assert
      expect(video.id, equals('test123'));
      expect(video.title, equals('Test Video'));
      expect(video.channelName, equals('Test Channel'));
      expect(video.views, equals('1M views'));
      expect(video.duration, equals('10:30'));
      expect(video.thumbnailUrl, equals('https://example.com/thumb.jpg'));
      expect(video.channelAvatar, equals('https://example.com/avatar.jpg'));
      expect(video.isVerified, isTrue);
    });

    test('should handle unverified channels', () {
      // Act
      const video = VideoModel(
        id: 'test456',
        title: 'Unverified Video',
        channelName: 'Small Channel',
        views: '100 views',
        duration: '5:00',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        channelAvatar: 'https://example.com/avatar.jpg',
        isVerified: false,
      );

      // Assert
      expect(video.isVerified, isFalse);
    });

    test('should have demo constant', () {
      // Assert
      expect(VideoModel.demo.id, equals('demo1'));
      expect(VideoModel.demo.title, contains('Tube Arena'));
      expect(VideoModel.demo.isVerified, isTrue);
    });

    test('demo constant should have valid URLs', () {
      // Assert
      expect(VideoModel.demo.thumbnailUrl.startsWith('https://'), isTrue);
      expect(VideoModel.demo.channelAvatar.startsWith('https://'), isTrue);
    });
  });

  group('Quality Options toString Tests', () {
    test('VideoQualityOption toString should be readable', () {
      // Arrange
      final quality = VideoQualityOption(
        quality: '720p',
        format: 'mp4',
        fileSize: '50 MB',
        videoUrl: 'https://example.com/video.m4v',
        audioUrl: 'https://example.com/audio.m4a',
        fps: 30,
        bitrate: '2000k',
      );

      // Act
      final result = quality.toString();

      // Assert
      expect(result, contains('720p'));
      expect(result, contains('mp4'));
      expect(result, contains('50 MB'));
      expect(result, contains('30 fps'));
    });

    test('AudioQualityOption toString should be readable', () {
      // Arrange
      final audio = AudioQualityOption(
        format: 'MP3',
        bitrate: '320 kbps',
        fileSize: '10 MB',
        audioUrl: 'https://example.com/audio.mp3',
      );

      // Act
      final result = audio.toString();

      // Assert
      expect(result, contains('MP3'));
      expect(result, contains('320 kbps'));
      expect(result, contains('10 MB'));
    });
  });

  group('Integration-style Tests', () {
    late YoutubeExtractionService service;
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      service = YoutubeExtractionService();
      service.dio = mockDio;
    });

    test('should extract metadata and qualities for complete workflow', () async {
      // Arrange
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final metadataResponse = Response(
        data: {
          'title': 'Sample Video',
          'author_name': 'Sample Channel',
          'thumbnail_url': 'https://example.com/thumb.jpg',
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

      when(mockDio.get(
        any,
        queryParameters: anyNamed('queryParameters'),
      )).thenAnswer((_) async => metadataResponse);

      // Act
      final metadata = await service.extractVideoMetadata(url);
      final videoQualities = await service.getVideoQualities(url);
      final audioQualities = await service.getAudioQualities(url);

      // Assert
      expect(metadata, isNotNull);
      expect(metadata['videoId'], isNotEmpty);
      expect(videoQualities, isNotEmpty);
      expect(audioQualities, isNotEmpty);
    });
  });
}
