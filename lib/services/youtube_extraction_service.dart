import 'package:logger/logger.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
  YoutubeExtractionService() : _youtube = YoutubeExplode();

  final YoutubeExplode _youtube;
  final logger = Logger();

  Future<void> dispose() async {
    await _youtube.close();
  }

  Future<Map<String, dynamic>> extractVideoMetadata(String videoUrl) async {
    try {
      final videoId = _extractVideoId(videoUrl);
      if (videoId == null || videoId.isEmpty) {
        throw Exception('Invalid YouTube URL');
      }

      logger.i('Extracting metadata from YouTube video: $videoId');

      final video = await _youtube.videos.get(videoId);
      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.isNotEmpty
          ? manifest.audioOnly.withHighestBitrate()
          : null;

      final thumbnail = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
      final duration = video.duration ?? Duration.zero;

      final metadata = {
        'videoId': videoId,
        'title': video.title,
        'author': video.author,
        'duration': _formatDuration(duration),
        'durationSeconds': duration.inSeconds,
        'thumbnail': thumbnail,
        'thumbnailUrl': thumbnail,
        'audioUrl': audioStream?.url.toString() ?? '',
        'description': video.description,
      };

      logger.i('Metadata extracted successfully for $videoId');
      return metadata;
    } catch (e) {
      logger.e('Error extracting metadata: $e');
      rethrow;
    }
  }

  Future<List<VideoQualityOption>> getVideoQualities(String videoUrl) async {
    try {
      final videoId = _extractVideoId(videoUrl);
      if (videoId == null || videoId.isEmpty) {
        throw Exception('Invalid YouTube URL');
      }

      logger.i('Fetching video qualities for: $videoId');

      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      final audioFallbackUrl = manifest.audioOnly.isNotEmpty
          ? manifest.audioOnly.withHighestBitrate().url.toString()
          : '';

      final preferredQualities = ['360p', '480p', '720p', '1080p'];
      final videoStreams = manifest.video.withAudioOnly.toList();
      final available = <VideoQualityOption>[];
      final seen = <String>{};

      for (final qualityLabel in preferredQualities) {
        final match = videoStreams.where((stream) {
          final label = (stream.qualityLabel ?? '').trim();
          return label == qualityLabel;
        }).toList();

        if (match.isEmpty) {
          continue;
        }

        final stream = match.first;
        final normalizedQuality = stream.qualityLabel ?? qualityLabel;

        if (seen.contains(normalizedQuality)) {
          continue;
        }
        seen.add(normalizedQuality);

        available.add(
          VideoQualityOption(
            quality: normalizedQuality,
            format: (stream.container.name ?? 'mp4').toUpperCase(),
            fileSize: _formatBytes(stream.size.totalBytes),
            videoUrl: stream.url.toString(),
            audioUrl: audioFallbackUrl,
            fps: stream.fps ?? 0,
            bitrate: _formatBitrate(stream.bitrate),
          ),
        );
      }

      if (available.isEmpty) {
        for (final stream in videoStreams) {
          final normalizedQuality = (stream.qualityLabel ?? 'Unknown').trim();
          if (normalizedQuality.isEmpty || seen.contains(normalizedQuality)) {
            continue;
          }

          seen.add(normalizedQuality);
          available.add(
            VideoQualityOption(
              quality: normalizedQuality,
              format: (stream.container.name ?? 'mp4').toUpperCase(),
              fileSize: _formatBytes(stream.size.totalBytes),
              videoUrl: stream.url.toString(),
              audioUrl: audioFallbackUrl,
              fps: stream.fps ?? 0,
              bitrate: _formatBitrate(stream.bitrate),
            ),
          );
        }
      }

      logger.i('Found ${available.length} real video quality options');
      return available;
    } catch (e) {
      logger.e('Error fetching video qualities: $e');
      rethrow;
    }
  }

  Future<List<AudioQualityOption>> getAudioQualities(String videoUrl) async {
    try {
      final videoId = _extractVideoId(videoUrl);
      if (videoId == null || videoId.isEmpty) {
        throw Exception('Invalid YouTube URL');
      }

      logger.i('Fetching audio qualities for: $videoId');

      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly.toList();
      if (audioStreams.isEmpty) {
        return const [];
      }

      final sortedStreams = [...audioStreams]
        ..sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));

      final audioQualities = <AudioQualityOption>[];
      final seen = <String>{};

      for (final stream in sortedStreams) {
        final bitrateLabel = _formatBitrate(stream.bitrate);
        final key = 'MP3-$bitrateLabel';
        if (seen.contains(key)) {
          continue;
        }

        seen.add(key);
        audioQualities.add(
          AudioQualityOption(
            format: 'MP3',
            bitrate: bitrateLabel,
            fileSize: _formatBytes(stream.size.totalBytes),
            audioUrl: stream.url.toString(),
          ),
        );

        if (audioQualities.length >= 5) {
          break;
        }
      }

      logger.i('Found ${audioQualities.length} real audio quality options');
      return audioQualities;
    } catch (e) {
      logger.e('Error fetching audio qualities: $e');
      rethrow;
    }
  }

  String? _extractVideoId(String url) {
    try {
      if (url.isEmpty) {
        return null;
      }

      final trimmed = url.trim();
      if (trimmed.length == 11 && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(trimmed)) {
        return trimmed;
      }

      final normalized = trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
      final uri = Uri.tryParse(normalized);
      if (uri == null) {
        return null;
      }

      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.firstOrNull;
      }

      final videoId = uri.queryParameters['v'];
      if (videoId != null && videoId.isNotEmpty) {
        return videoId;
      }

      final segments = uri.pathSegments;
      if (segments.length >= 2 && (segments[0] == 'shorts' || segments[0] == 'embed')) {
        return segments[1];
      }

      return null;
    } catch (e) {
      logger.e('Error extracting video ID: $e');
      return null;
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return 'Unknown';
    }

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < suffixes.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final text = value >= 10 || unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text ${suffixes[unitIndex]}';
  }

  String _formatBitrate(int? bitrate) {
    if (bitrate == null || bitrate <= 0) {
      return 'Unknown';
    }

    final kbps = (bitrate / 1000).round();
    return '$kbps kbps';
  }
}
