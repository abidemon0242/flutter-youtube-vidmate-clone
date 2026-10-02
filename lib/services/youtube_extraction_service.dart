import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

class VideoQualityOption {
  VideoQualityOption({
    required this.quality,
    required this.format,
    required this.fileSize,
    required this.videoUrl,
    required this.audioUrl,
    required this.fps,
    required this.bitrate,
  });

  final String quality;
  final String format;
  final String fileSize;
  final String videoUrl;
  final String audioUrl;
  final int fps;
  final String bitrate;

  @override
  String toString() => '$quality ($format) - $fileSize @ $fps fps';
}

class AudioQualityOption {
  AudioQualityOption({
    required this.format,
    required this.bitrate,
    required this.fileSize,
    required this.audioUrl,
  });

  final String format;
  final String bitrate;
  final String fileSize;
  final String audioUrl;

  @override
  String toString() => '$format - $bitrate - $fileSize';
}

class YoutubeExtractionService {
  final logger = Logger();
  final dio = Dio();

  /// Extract video metadata and stream URLs from YouTube video ID
  /// Uses youtube-oembed and alternative extraction methods
  Future<Map<String, dynamic>> extractVideoMetadata(String videoUrl) async {
    try {
      logger.i('Extracting metadata from: $videoUrl');

      // Extract video ID from URL
      final videoId = _extractVideoId(videoUrl);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }

      // Get video info via oEmbed API (public, no auth needed)
      final response = await dio.get(
        'https://www.youtube.com/oembed',
        queryParameters: {'url': 'https://www.youtube.com/watch?v=$videoId', 'format': 'json'},
      );

      final metadata = {
        'videoId': videoId,
        'title': response.data['title'] ?? 'Unknown',
        'author': response.data['author_name'] ?? 'Unknown Channel',
        'duration': '12:45', // Mock duration
        'thumbnail': response.data['thumbnail_url'] ?? '',
      };

      logger.i('Metadata extracted successfully');
      return metadata;
    } catch (e) {
      logger.e('Error extracting metadata: $e');
      rethrow;
    }
  }

  /// Get available video quality options
  /// Simulates extracting multiple quality streams (real impl uses yt-dlp or similar)
  Future<List<VideoQualityOption>> getVideoQualities(String videoUrl) async {
    try {
      logger.i('Fetching video qualities for: $videoUrl');

      // Mock video quality options
      // In production, this would use youtube_explode_dart or yt-dlp wrapper
      final qualities = [
        VideoQualityOption(
          quality: '360p',
          format: 'mp4',
          fileSize: '5.3 MB',
          videoUrl: 'https://example.com/stream/360p.m4v',
          audioUrl: 'https://example.com/stream/audio.m4a',
          fps: 24,
          bitrate: '500k',
        ),
        VideoQualityOption(
          quality: '480p',
          format: 'mp4',
          fileSize: '9.4 MB',
          videoUrl: 'https://example.com/stream/480p.m4v',
          audioUrl: 'https://example.com/stream/audio.m4a',
          fps: 24,
          bitrate: '1000k',
        ),
        VideoQualityOption(
          quality: '720p',
          format: 'mp4',
          fileSize: '18 MB',
          videoUrl: 'https://example.com/stream/720p.m4v',
          audioUrl: 'https://example.com/stream/audio.m4a',
          fps: 30,
          bitrate: '2000k',
        ),
        VideoQualityOption(
          quality: '1080p',
          format: 'mp4',
          fileSize: '34 MB',
          videoUrl: 'https://example.com/stream/1080p.m4v',
          audioUrl: 'https://example.com/stream/audio.m4a',
          fps: 30,
          bitrate: '4000k',
        ),
        VideoQualityOption(
          quality: '2K',
          format: 'mp4',
          fileSize: '58 MB',
          videoUrl: 'https://example.com/stream/2k.m4v',
          audioUrl: 'https://example.com/stream/audio.m4a',
          fps: 60,
          bitrate: '8000k',
        ),
        VideoQualityOption(
          quality: '4K',
          format: 'mp4',
          fileSize: '92 MB',
          videoUrl: 'https://example.com/stream/4k.m4v',
          audioUrl: 'https://example.com/stream/audio.m4a',
          fps: 60,
          bitrate: '12000k',
        ),
      ];

      logger.i('Found ${qualities.length} video quality options');
      return qualities;
    } catch (e) {
      logger.e('Error fetching video qualities: $e');
      rethrow;
    }
  }

  /// Get available audio quality options
  Future<List<AudioQualityOption>> getAudioQualities(String videoUrl) async {
    try {
      logger.i('Fetching audio qualities for: $videoUrl');

      final audioQualities = [
        AudioQualityOption(
          format: 'MP3',
          bitrate: '128 kbps',
          fileSize: '2.8 MB',
          audioUrl: 'https://example.com/stream/audio_128.mp3',
        ),
        AudioQualityOption(
          format: 'MP3',
          bitrate: '192 kbps',
          fileSize: '4.2 MB',
          audioUrl: 'https://example.com/stream/audio_192.mp3',
        ),
        AudioQualityOption(
          format: 'MP3',
          bitrate: '320 kbps',
          fileSize: '7.1 MB',
          audioUrl: 'https://example.com/stream/audio_320.mp3',
        ),
        AudioQualityOption(
          format: 'M4A',
          bitrate: '128 kbps',
          fileSize: '2.6 MB',
          audioUrl: 'https://example.com/stream/audio_128.m4a',
        ),
        AudioQualityOption(
          format: 'M4A',
          bitrate: '256 kbps',
          fileSize: '5.2 MB',
          audioUrl: 'https://example.com/stream/audio_256.m4a',
        ),
      ];

      logger.i('Found ${audioQualities.length} audio quality options');
      return audioQualities;
    } catch (e) {
      logger.e('Error fetching audio qualities: $e');
      rethrow;
    }
  }

  /// Extract YouTube video ID from various URL formats
  String? _extractVideoId(String url) {
    try {
      // Handle youtube.com/watch?v=xxx
      if (url.contains('watch?v=')) {
        return url.split('watch?v=')[1].split('&')[0];
      }
      // Handle youtu.be/xxx
      if (url.contains('youtu.be/')) {
        return url.split('youtu.be/')[1].split('?')[0];
      }
      // Handle direct video ID
      if (url.length == 11) {
        return url;
      }
      return null;
    } catch (e) {
      logger.e('Error extracting video ID: $e');
      return null;
    }
  }
}
