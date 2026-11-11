import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';

class MediaResolutionOption {
  const MediaResolutionOption({
    required this.url,
    required this.width,
    required this.height,
    required this.bandwidth,
    required this.estimatedBytes,
    this.audioUrl,
  });

  final String url;
  final String? audioUrl;
  final int width;
  final int height;
  final int bandwidth;
  final int? estimatedBytes;

  String get label =>
      width > 0 && height > 0 ? '${height}p' : 'Original quality';

  String get sizeLabel {
    final bytes = estimatedBytes;
    if (bytes == null || bytes <= 0) return 'Size unavailable';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB approx.';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB approx.';
  }
}

class HlsResolutionService {
  HlsResolutionService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  static bool isSupportedManifestUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !_isYouTubeHost(uri.host) &&
        uri.path.toLowerCase().endsWith('.m3u8');
  }

  static bool _isYouTubeHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'youtube.com' ||
        normalized.endsWith('.youtube.com') ||
        normalized == 'youtu.be' ||
        normalized.endsWith('.youtu.be');
  }

  Future<List<MediaResolutionOption>> discover(String manifestUrl) async {
    if (!isSupportedManifestUrl(manifestUrl)) {
      throw const FormatException(
        'Enter a direct HLS .m3u8 manifest URL from a source you may download.',
      );
    }
    final masterUri = Uri.parse(manifestUrl);
    final body = await _getText(masterUri);
    final variants = parseMasterPlaylist(masterUri, body);
    if (variants.isEmpty) {
      throw const FormatException(
        'This HLS playlist does not expose multiple selectable resolutions.',
      );
    }

    final resolved = <MediaResolutionOption>[];
    for (final variant in variants.take(12)) {
      int? durationSeconds;
      try {
        final mediaPlaylist = await _getText(Uri.parse(variant.url));
        if (!isFiniteMediaPlaylist(mediaPlaylist)) {
          throw const FormatException(
            'Live HLS playlists are not supported. Use a completed video playlist.',
          );
        }
        durationSeconds = _playlistDurationSeconds(mediaPlaylist);
      } catch (_) {
        // Resolution remains selectable even when the server hides size metadata.
      }
      final estimatedBytes = durationSeconds == null || variant.bandwidth <= 0
          ? null
          : (variant.bandwidth * durationSeconds / 8).round();
      resolved.add(
        MediaResolutionOption(
          url: variant.url,
          audioUrl: variant.audioUrl,
          width: variant.width,
          height: variant.height,
          bandwidth: variant.bandwidth,
          estimatedBytes: estimatedBytes,
        ),
      );
    }
    resolved.sort((a, b) {
      final byHeight = a.height.compareTo(b.height);
      return byHeight != 0 ? byHeight : a.bandwidth.compareTo(b.bandwidth);
    });
    return List.unmodifiable(resolved);
  }

  Future<String> _getText(Uri uri) async {
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 12));
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    final response = await request.close().timeout(const Duration(seconds: 18));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Media server returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    final bytes = await response.fold<List<int>>(<int>[], (all, chunk) {
      if (all.length + chunk.length > 2 * 1024 * 1024) {
        throw const FormatException('Playlist manifest is unexpectedly large.');
      }
      return all..addAll(chunk);
    });
    return String.fromCharCodes(bytes);
  }

  static List<MediaResolutionOption> parseMasterPlaylist(
    Uri masterUri,
    String source,
  ) {
    final lines = source.split(RegExp(r'\r?\n'));
    final audioGroups = <String, String>{};
    for (final line in lines) {
      if (!line.startsWith('#EXT-X-MEDIA:') ||
          !_attribute(line, 'TYPE').contains('AUDIO')) {
        continue;
      }
      final group = _attribute(line, 'GROUP-ID');
      final audioPath = _attribute(line, 'URI');
      if (group.isNotEmpty && audioPath.isNotEmpty) {
        audioGroups[group] = masterUri.resolve(audioPath).toString();
      }
    }

    final variants = <MediaResolutionOption>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      var next = index + 1;
      while (next < lines.length &&
          (lines[next].trim().isEmpty || lines[next].trim().startsWith('#'))) {
        next++;
      }
      if (next >= lines.length) continue;
      final relativeUrl = lines[next].trim();
      final resolution = _attribute(line, 'RESOLUTION');
      final dimensions = RegExp(r'^(\d+)x(\d+)$').firstMatch(resolution);
      final width = int.tryParse(dimensions?.group(1) ?? '') ?? 0;
      final height = int.tryParse(dimensions?.group(2) ?? '') ?? 0;
      final bandwidth =
          int.tryParse(_attribute(line, 'AVERAGE-BANDWIDTH')) ??
          int.tryParse(_attribute(line, 'BANDWIDTH')) ??
          0;
      final audioGroup = _attribute(line, 'AUDIO');
      variants.add(
        MediaResolutionOption(
          url: masterUri.resolve(relativeUrl).toString(),
          audioUrl: audioGroups[audioGroup],
          width: width,
          height: height,
          bandwidth: bandwidth,
          estimatedBytes: null,
        ),
      );
      index = next;
    }
    return variants;
  }

  static String _attribute(String line, String name) {
    final match = RegExp(
      '(?:^|[, :])' + RegExp.escape(name) + r'=(?:"([^"]*)"|([^,]*))',
    ).firstMatch(line);
    return (match?.group(1) ?? match?.group(2) ?? '').trim();
  }

  static bool isFiniteMediaPlaylist(String source) => source
      .split(RegExp(r'\r?\n'))
      .any((line) => line.trim() == '#EXT-X-ENDLIST');

  static int? _playlistDurationSeconds(String source) {
    var total = 0.0;
    for (final line in source.split(RegExp(r'\r?\n'))) {
      if (!line.startsWith('#EXTINF:')) continue;
      final raw = line.substring('#EXTINF:'.length).split(',').first;
      total += double.tryParse(raw) ?? 0;
    }
    return total > 0 ? total.ceil() : null;
  }

  Future<bool> download({
    required MediaResolutionOption option,
    required String outputPath,
    required String format,
  }) async {
    final normalizedFormat = format.toLowerCase();
    if (normalizedFormat != 'mp4' && normalizedFormat != 'mkv') return false;
    final output = File(outputPath);
    if (await output.exists()) return false;
    await output.parent.create(recursive: true);

    final args = <String>['-y', '-i', option.url];
    if (option.audioUrl != null) {
      args.addAll(['-i', option.audioUrl!]);
    }
    args.addAll(['-map', '0:v:0']);
    if (option.audioUrl != null) {
      args.addAll(['-map', '1:a:0']);
    } else {
      args.addAll(['-map', '0:a?']);
    }
    args.addAll(['-c', 'copy']);
    if (normalizedFormat == 'mp4') {
      args.addAll(['-movflags', '+faststart']);
    }
    args.add(outputPath);

    try {
      final session = await FFmpegKit.executeWithArguments(args);
      final code = await session.getReturnCode();
      if (ReturnCode.isSuccess(code) && await output.exists()) {
        return (await output.length()) > 0;
      }
    } catch (_) {
      // The caller records a failed item and presents a retryable error.
    }
    if (await output.exists()) await output.delete();
    return false;
  }

  void close() => _client.close(force: true);
}
