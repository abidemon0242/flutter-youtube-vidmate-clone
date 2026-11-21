import 'package:logger/logger.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/video_model.dart';

/// What a download produces.
enum DownloadKind { video, audio }

/// One choice in the download sheet.
///
/// Options are identified by [key] (stream itags), never by URL, because
/// YouTube stream URLs expire after a few hours. URLs are always re-resolved
/// from a fresh manifest right before bytes are fetched.
class DownloadOption {
  const DownloadOption({
    required this.kind,
    required this.label,
    required this.container,
    required this.videoTag,
    required this.audioTag,
    required this.sizeBytes,
    this.detail = '',
  });

  final DownloadKind kind;

  /// "1080p60", "720p", "Audio 128 kbps" ...
  final String label;

  /// Real container of the final file: mp4, webm, mkv or m4a.
  final String container;

  /// Itag of the video (or muxed) stream; null for audio-only.
  final int? videoTag;

  /// Itag of the separate audio stream; null when the video stream is muxed.
  final int? audioTag;

  final int sizeBytes;
  final String detail;

  /// True when video and audio are separate streams that must be merged.
  bool get needsMerge => videoTag != null && audioTag != null;

  String get key => '${kind.name}-${videoTag ?? 0}-${audioTag ?? 0}';

  String get extension => '.$container';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'label': label,
    'container': container,
    'videoTag': videoTag,
    'audioTag': audioTag,
    'sizeBytes': sizeBytes,
    'detail': detail,
  };

  factory DownloadOption.fromJson(Map<String, dynamic> json) => DownloadOption(
    kind: DownloadKind.values.byName(json['kind'] as String),
    label: json['label'] as String,
    container: json['container'] as String,
    videoTag: json['videoTag'] as int?,
    audioTag: json['audioTag'] as int?,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    detail: json['detail'] as String? ?? '',
  );
}

class DownloadOptions {
  const DownloadOptions({required this.video, required this.audio});
  final List<DownloadOption> video;
  final List<DownloadOption> audio;

  bool get isEmpty => video.isEmpty && audio.isEmpty;

  /// Sensible default for batch downloads: 720p or the closest lower quality.
  DownloadOption? get recommended {
    if (video.isEmpty) return audio.isEmpty ? null : audio.first;
    for (final option in video) {
      if (_height(option.label) <= 720) return option;
    }
    return video.last;
  }
}

int _height(String label) => int.tryParse(RegExp(r'^(\d+)').firstMatch(label)?.group(1) ?? '') ?? 0;

/// Thrown with a message that is safe to show to users.
class YoutubeServiceException implements Exception {
  const YoutubeServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Wraps youtube_explode_dart: search, metadata, stream selection and the
/// chunked byte streams used by downloads.
class YoutubeExtractionService {
  YoutubeExtractionService({YoutubeHttpClient? httpClient}) : _http = httpClient ?? YoutubeHttpClient() {
    _youtube = YoutubeExplode(httpClient: _http);
  }

  final YoutubeHttpClient _http;
  late final YoutubeExplode _youtube;
  final _logger = Logger();
  final Map<String, ({StreamManifest manifest, DateTime fetchedAt})> _manifestCache = {};

  /// Manifests (and their URLs) are reused for a short time only.
  static const _manifestTtl = Duration(minutes: 30);

  void dispose() => _youtube.close();

  // ---------------------------------------------------------------- search

  Future<List<VideoModel>> search(String query, {String category = 'All'}) async {
    try {
      final results = await _youtube.search.search(query);
      return results.map((video) => _toModel(video, category)).toList();
    } on Exception catch (error) {
      _logger.w('YouTube search failed: $error');
      throw YoutubeServiceException(_friendly(error));
    }
  }

  Future<VideoModel> getVideo(String urlOrId) async {
    final id = extractVideoId(urlOrId);
    if (id == null) throw const YoutubeServiceException('That is not a valid YouTube link.');
    try {
      return _toModel(await _youtube.videos.get(id), 'All');
    } on Exception catch (error) {
      throw YoutubeServiceException(_friendly(error));
    }
  }

  VideoModel _toModel(Video video, String category) => VideoModel(
    id: video.id.value,
    youtubeId: video.id.value,
    title: video.title,
    channelName: video.author,
    views: _formatViews(video.engagement.viewCount),
    duration: video.duration == null ? (video.isLive ? 'LIVE' : '') : formatDuration(video.duration!),
    thumbnailUrl: video.thumbnails.highResUrl,
    category: category,
    published: video.uploadDateRaw ?? '',
  );

  // -------------------------------------------------------------- streams

  Future<StreamManifest> manifest(String videoId, {bool fresh = false}) async {
    final cached = _manifestCache[videoId];
    if (!fresh && cached != null && DateTime.now().difference(cached.fetchedAt) < _manifestTtl) {
      return cached.manifest;
    }
    try {
      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      _manifestCache[videoId] = (manifest: manifest, fetchedAt: DateTime.now());
      return manifest;
    } on Exception catch (error) {
      _logger.w('Manifest failed for $videoId: $error');
      throw YoutubeServiceException(_friendly(error));
    }
  }

  /// A progressive (video+audio) URL for in-app playback, or null.
  Future<Uri?> playbackUrl(String videoId) async {
    final m = await manifest(videoId);
    if (m.muxed.isNotEmpty) return m.muxed.withHighestBitrate().url;
    if (m.hls.isNotEmpty) return m.hls.first.url;
    return null;
  }

  Future<DownloadOptions> getDownloadOptions(String videoId) async => buildDownloadOptions(await manifest(videoId));

  /// Looks up a stream by itag in a fresh-enough manifest.
  Future<StreamInfo> streamForTag(String videoId, int tag, {bool fresh = false}) async {
    final m = await manifest(videoId, fresh: fresh);
    for (final stream in m.streams) {
      if (stream.tag == tag) return stream;
    }
    if (!fresh) return streamForTag(videoId, tag, fresh: true);
    throw const YoutubeServiceException('This quality is no longer available for this video.');
  }

  /// Byte stream starting at [start], fetched in ranges so YouTube does not
  /// throttle it, and re-resolving expired URLs automatically.
  Stream<List<int>> openStream(StreamInfo info, {int start = 0}) =>
      _http.getStream(info, start: start, streamClient: _youtube.videos.streamsClient);

  // --------------------------------------------------------------- helpers

  static String? extractVideoId(String url) {
    final trimmed = url.trim();
    final idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
    if (idPattern.hasMatch(trimmed)) return trimmed;
    final uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.userInfo.isNotEmpty) {
      return null;
    }
    final host = uri.host.toLowerCase();
    const hosts = {'youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com', 'youtu.be', 'www.youtu.be'};
    if (!hosts.contains(host)) return null;
    String? candidate;
    if (host.endsWith('youtu.be')) {
      candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else {
      candidate = uri.queryParameters['v'];
      final segments = uri.pathSegments;
      if ((candidate == null || candidate.isEmpty) &&
          segments.length >= 2 &&
          const {'shorts', 'embed', 'live', 'v'}.contains(segments[0])) {
        candidate = segments[1];
      }
    }
    return candidate != null && idPattern.hasMatch(candidate) ? candidate : null;
  }

  static String formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String _formatViews(int views) {
    if (views <= 0) return '';
    if (views >= 1000000000) return '${(views / 1e9).toStringAsFixed(1)}B views';
    if (views >= 1000000) return '${(views / 1e6).toStringAsFixed(1)}M views';
    if (views >= 1000) return '${(views / 1e3).toStringAsFixed(0)}K views';
    return '$views views';
  }

  static String _friendly(Object error) {
    if (error is YoutubeServiceException) return error.message;
    if (error is RequestLimitExceededException) {
      return 'YouTube is limiting requests from this network. Try again in a few minutes.';
    }
    if (error is VideoUnavailableException) return 'This video is unavailable or private.';
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'No internet connection.';
    }
    return 'Could not reach YouTube. Please try again.';
  }
}

/// Pure stream-selection logic, kept separate so it can be unit tested.
///
/// For each resolution the best stream is chosen by preferring, in order:
/// a muxed stream, an MP4 (H.264) video-only stream, then any other stream.
/// MP4 video is paired with M4A audio so the result stays a real .mp4; other
/// pairs are written to .mkv (or .webm for WebM+WebM) without re-encoding.
DownloadOptions buildDownloadOptions(StreamManifest manifest) {
  final audioOnly = manifest.audioOnly.toList()..sort((a, b) => b.bitrate.compareTo(a.bitrate));
  AudioOnlyStreamInfo? bestAudio(String container) {
    for (final a in audioOnly) {
      if (a.container.name == container) return a;
    }
    return null;
  }

  final bestM4a = bestAudio('mp4');
  final bestWebm = bestAudio('webm');
  final anyAudio = audioOnly.isEmpty ? null : audioOnly.first;

  int score(VideoStreamInfo s) {
    if (s is MuxedStreamInfo) return 3;
    if (s.container.name == 'mp4' && s.videoCodec.startsWith('avc')) return 2;
    if (s.container.name == 'mp4') return 1;
    return 0;
  }

  final byLabel = <String, VideoStreamInfo>{};
  for (final stream in manifest.video) {
    final label = stream.qualityLabel.trim();
    if (label.isEmpty) continue;
    final current = byLabel[label];
    if (current == null ||
        score(stream) > score(current) ||
        (score(stream) == score(current) && stream.bitrate.compareTo(current.bitrate) > 0)) {
      byLabel[label] = stream;
    }
  }

  final videoOptions = <DownloadOption>[];
  for (final stream in byLabel.values) {
    if (stream is MuxedStreamInfo) {
      videoOptions.add(
        DownloadOption(
          kind: DownloadKind.video,
          label: stream.qualityLabel,
          container: stream.container.name == 'webm' ? 'webm' : 'mp4',
          videoTag: stream.tag,
          audioTag: null,
          sizeBytes: stream.size.totalBytes,
          detail: 'Video + audio',
        ),
      );
      continue;
    }
    final isMp4 = stream.container.name == 'mp4';
    final audio = isMp4 ? (bestM4a ?? anyAudio) : (bestWebm ?? anyAudio);
    if (audio == null) continue; // video without any audio track is not offered
    final String container;
    if (isMp4 && audio.container.name == 'mp4') {
      container = 'mp4';
    } else if (!isMp4 && audio.container.name == 'webm') {
      container = 'webm';
    } else {
      container = 'mkv';
    }
    videoOptions.add(
      DownloadOption(
        kind: DownloadKind.video,
        label: stream.qualityLabel,
        container: container,
        videoTag: stream.tag,
        audioTag: audio.tag,
        sizeBytes: stream.size.totalBytes + audio.size.totalBytes,
        detail: container.toUpperCase(),
      ),
    );
  }
  videoOptions.sort((a, b) {
    final byHeight = _height(b.label).compareTo(_height(a.label));
    return byHeight != 0 ? byHeight : b.label.compareTo(a.label);
  });

  final audioOptions = <DownloadOption>[];
  final seen = <String>{};
  for (final audio in audioOnly) {
    final container = audio.container.name == 'mp4' ? 'm4a' : audio.container.name;
    final kbps = (audio.bitrate.bitsPerSecond / 1000).round();
    if (!seen.add('$container-$kbps')) continue;
    audioOptions.add(
      DownloadOption(
        kind: DownloadKind.audio,
        label: 'Audio $kbps kbps',
        container: container,
        videoTag: null,
        audioTag: audio.tag,
        sizeBytes: audio.size.totalBytes,
        detail: container == 'm4a' ? 'M4A (AAC)' : '${container.toUpperCase()} (${audio.audioCodec})',
      ),
    );
    if (audioOptions.length >= 4) break;
  }
  return DownloadOptions(video: videoOptions, audio: audioOptions);
}
