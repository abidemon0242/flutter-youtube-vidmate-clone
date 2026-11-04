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
    // close() is synchronous in youtube_explode_dart 2.x.
    _youtube.close();
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

      return {
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
      final available = <VideoQualityOption>[];
      final seen = <String>{};

      // Adaptive video-only streams provide the higher resolutions. Pair each
      // with an audio-only stream in the same container so FFmpeg can mux them
      // without silently changing the requested output format.
      final videoOnly = manifest.videoOnly.toList()
        ..sort((a, b) {
          final height = b.videoResolution.height.compareTo(a.videoResolution.height);
          if (height != 0) return height;
          return b.bitrate.compareTo(a.bitrate);
        });

      for (final stream in videoOnly) {
        final quality = stream.qualityLabel.trim();
        final format = stream.container.name.toUpperCase();
        if (quality.isEmpty) continue;

        final compatibleAudio = manifest.audioOnly
            .where((audio) => audio.container == stream.container)
            .toList()
          ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
        if (compatibleAudio.isEmpty) continue;
        final audio = compatibleAudio.first;
        final key = '$format-$quality';
        if (!seen.add(key)) continue;

        final videoBytes = stream.size.totalBytes;
        final audioBytes = audio.size.totalBytes;
        available.add(VideoQualityOption(
          quality: quality,
          format: format,
          fileSize: _formatBytes(videoBytes + audioBytes),
          videoUrl: stream.url.toString(),
          audioUrl: audio.url.toString(),
          fps: stream.framerate.framesPerSecond.toInt(),
          bitrate: _formatBitrate(stream.bitrate),
        ));
      }

      // Retain muxed streams as a fallback for resolutions that have no
      // compatible adaptive audio/video pair.
      final muxedStreams = manifest.muxed.toList()
        ..sort((a, b) {
          final height = b.videoResolution.height.compareTo(a.videoResolution.height);
          if (height != 0) return height;
          return b.bitrate.compareTo(a.bitrate);
        });
      for (final stream in muxedStreams) {
        final quality = stream.qualityLabel.trim();
        final format = stream.container.name.toUpperCase();
        if (quality.isEmpty || !seen.add('$format-$quality')) continue;
        available.add(VideoQualityOption(
          quality: quality,
          format: format,
          fileSize: _formatBytes(stream.size.totalBytes),
          videoUrl: stream.url.toString(),
          audioUrl: '',
          fps: stream.framerate.framesPerSecond.toInt(),
          bitrate: _formatBitrate(stream.bitrate),
        ));
      }

      available.sort((a, b) {
        final aHeight = int.tryParse(RegExp(r'(\d+)p').firstMatch(a.quality)?.group(1) ?? '') ?? 0;
        final bHeight = int.tryParse(RegExp(r'(\d+)p').firstMatch(b.quality)?.group(1) ?? '') ?? 0;
        if (aHeight != bHeight) return bHeight.compareTo(aHeight);
        return b.fps.compareTo(a.fps);
      });
      logger.i('Found ${available.length} compatible video quality options');
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
      if (audioStreams.isEmpty) return const [];

      final sortedStreams = [...audioStreams]
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      final options = <AudioQualityOption>[];
      final seen = <String>{};

      for (final stream in sortedStreams) {
        final bitrateLabel = _formatBitrate(stream.bitrate);
        final format = stream.container.name.toUpperCase();
        if (!seen.add('$format-$bitrateLabel')) continue;

        options.add(AudioQualityOption(
          format: format,
          bitrate: bitrateLabel,
          fileSize: _formatBytes(stream.size.totalBytes),
          audioUrl: stream.url.toString(),
        ));
        if (options.length >= 5) break;
      }

      logger.i('Found ${options.length} real audio quality options');
      return options;
    } catch (e) {
      logger.e('Error fetching audio qualities: $e');
      rethrow;
    }
  }

  String? _extractVideoId(String url) {
    final trimmed = url.trim();
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;
    final normalized = trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.userInfo.isNotEmpty) return null;
    final host = uri.host.toLowerCase();
    const hosts = {'youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com', 'youtu.be', 'www.youtu.be'};
    if (!hosts.contains(host)) return null;
    String? candidate;
    if (host == 'youtu.be' || host == 'www.youtu.be') {
      candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else {
      candidate = uri.queryParameters['v'];
      if (candidate == null || candidate.isEmpty) {
        final segments = uri.pathSegments;
        if (segments.length >= 2 && {'shorts', 'embed', 'live'}.contains(segments[0])) candidate = segments[1];
      }
    }
    return candidate != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate) ? candidate : null;
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
    if (bytes == null || bytes <= 0) return 'Unknown';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < suffixes.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final formatted = value >= 10 || unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$formatted ${suffixes[unitIndex]}';
  }

  String _formatBitrate(Bitrate bitrate) {
    final bitsPerSecond = bitrate.bitsPerSecond;
    if (bitsPerSecond <= 0) return 'Unknown';
    return '${(bitsPerSecond / 1000).round()} kbps';
  }
}