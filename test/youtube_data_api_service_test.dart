import 'package:flutter_test/flutter_test.dart';
import 'package:tube_arena/services/youtube_data_api_service.dart';

void main() {
  group('YouTubeDataApiService configuration', () {
    test('reports a clear error when the API key is missing', () async {
      final service = YouTubeDataApiService(apiKey: '');
      await expectLater(
        service.getMostPopular(),
        throwsA(
          isA<YouTubeApiException>().having(
            (error) => error.message,
            'message',
            contains('YOUTUBE_DATA_API_KEY'),
          ),
        ),
      );
    });

    test('reports configured state without exposing the API key', () {
      final service = YouTubeDataApiService(apiKey: 'test-key');
      expect(service.isConfigured, isTrue);
    });
  });
}
