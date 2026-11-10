import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/video_model.dart';

class InvidiousCatalogException implements Exception {
  const InvidiousCatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}

typedef CatalogTextLoader = Future<String> Function(Uri uri);

/// Reads public video metadata from community-maintained Invidious instances.
///
/// This service never requests video stream URLs or attempts to extract
/// downloadable media. It supports public search, trending, playlist metadata,
/// and resolving public YouTube channel/playlist URLs.
class InvidiousCatalogService {
  InvidiousCatalogService({CatalogTextLoader? loader, List<Uri>? instanceUris})
    : _loader = loader ?? _load,
      _providedInstances = instanceUris;

  final CatalogTextLoader _loader;
  final List<Uri>? _providedInstances;

  static final Uri _registryUri = Uri.https(
    'api.invidious.io',
    '/instances.json',
    {'sort_by': 'type,users'},
  );

  static final List<Uri> _fallbackInstances = [
    Uri.https('yt.chocolatemoo53.com', ''),
  ];

  Future<List<Uri>> _instances() async {
    if (_providedInstances != null) return _providedInstances;
    try {
      final decoded = jsonDecode(await _loader(_registryUri));
      if (decoded is List) {
        final instances = <Uri>[];
        for (final item in decoded) {
          if (item is! List || item.length < 2 || item[1] is! Map) continue;
          final metadata = item[1] as Map;
          if (metadata['type'] != 'https' || metadata['api'] != true) {
            continue;
          }
          if (metadata['monitor'] is Map &&
              (metadata['monitor'] as Map)['down'] == true) {
            continue;
          }
          final uri = Uri.tryParse(metadata['uri'] as String? ?? '');
          if (uri == null ||
              uri.scheme != 'https' ||
              uri.host.isEmpty ||
              uri.userInfo.isNotEmpty) {
            continue;
          }
          instances.add(uri);
        }
        if (instances.isNotEmpty) return instances;
      }
    } catch (_) {
      // Fall back to the last known API-enabled public instance.
    }
    return _fallbackInstances;
  }

  Future<List<VideoModel>> searchVideos(
    String query, {
    String region = 'BD',
    int page = 1,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final decoded = await _requestJson('/api/v1/search', {
      'q': term,
      'type': 'video',
      'page': '$page',
      'region': region,
    });
    if (decoded is! List) {
      throw const InvidiousCatalogException(
        'The public catalog returned an unexpected search response.',
      );
    }
    return _videosFromList(decoded, category: 'Search');
  }

  Future<List<VideoModel>> fetchTrending({
    String region = 'BD',
    String type = 'default',
  }) async {
    final decoded = await _requestJson('/api/v1/trending', {
      'region': region,
      'type': type,
    });
    if (decoded is! List) {
      throw const InvidiousCatalogException(
        'The public catalog returned an unexpected trending response.',
      );
    }
    return _videosFromList(decoded, category: 'Trending');
  }

  /// Resolves only YouTube URLs to a public channel ID or playlist ID.
  Future<({String? channelId, String? playlistId})> resolveYoutubeUrl(
    String input,
  ) async {
    final uri = _youtubeUri(input);
    if (uri == null) {
      throw const InvidiousCatalogException(
        'Enter a valid public YouTube channel or playlist URL.',
      );
    }
    final directPlaylist = uri.queryParameters['list'];
    if (directPlaylist != null && _validPlaylistId(directPlaylist)) {
      return (channelId: null, playlistId: directPlaylist);
    }
    final parts = uri.pathSegments;
    if (parts.length >= 2 &&
        parts.first == 'channel' &&
        _validChannelId(parts[1])) {
      return (channelId: parts[1], playlistId: null);
    }

    final decoded = await _requestJson('/api/v1/resolveurl', {
      'url': uri.toString(),
    });
    if (decoded is! Map) {
      throw const InvidiousCatalogException(
        'The public catalog could not resolve this YouTube URL.',
      );
    }
    final channel =
        decoded['ucid'] as String? ?? decoded['browseId'] as String?;
    final playlist = decoded['playlistId'] as String?;
    return (
      channelId: channel != null && _validChannelId(channel) ? channel : null,
      playlistId: playlist != null && _validPlaylistId(playlist)
          ? playlist
          : null,
    );
  }

  Future<String> resolveChannelId(String input) async {
    final resolved = await resolveYoutubeUrl(input);
    if (resolved.channelId == null) {
      throw const InvidiousCatalogException(
        'This link did not resolve to a public YouTube channel. Use a channel URL or @handle URL.',
      );
    }
    return resolved.channelId!;
  }

  Future<ImportedCatalogPlaylist> fetchPlaylist(
    String playlistId, {
    int page = 1,
  }) async {
    if (!_validPlaylistId(playlistId)) {
      throw const InvidiousCatalogException('The playlist ID is not valid.');
    }
    final decoded = await _requestJson('/api/v1/playlists/$playlistId', {
      'page': '$page',
    });
    if (decoded is! Map || decoded['videos'] is! List) {
      throw const InvidiousCatalogException(
        'This playlist is unavailable or its response is unsupported.',
      );
    }
    final videos = _videosFromList(
      decoded['videos'] as List,
      category: 'Imported playlist',
    );
    return ImportedCatalogPlaylist(
      id: playlistId,
      title: decoded['title'] as String? ?? 'YouTube playlist',
      channel: decoded['author'] as String? ?? '',
      videos: videos,
      totalCount: (decoded['videoCount'] as num?)?.toInt() ?? videos.length,
    );
  }

  Uri? _youtubeUri(String input) {
    final raw = input.trim();
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        !{
          'youtube.com',
          'www.youtube.com',
          'm.youtube.com',
          'music.youtube.com',
          'youtu.be',
          'www.youtu.be',
        }.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.replace(scheme: 'https');
  }

  bool _validChannelId(String value) =>
      RegExp(r'^UC[A-Za-z0-9_-]{22}$').hasMatch(value);

  bool _validPlaylistId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{10,128}$').hasMatch(value);

  List<VideoModel> _videosFromList(
    List<dynamic> items, {
    required String category,
  }) {
    final videos = <VideoModel>[];
    final seen = <String>{};
    for (final item in items) {
      if (item is! Map) continue;
      if (item['type'] != null && item['type'] != 'video') continue;
      final id = item['videoId'] as String?;
      final title = item['title'] as String?;
      if (id == null ||
          !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ||
          title == null ||
          title.trim().isEmpty ||
          !seen.add(id)) {
        continue;
      }
      final thumbnails = item['videoThumbnails'];
      String thumbnail = 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
      if (thumbnails is List) {
        for (final candidate in thumbnails) {
          if (candidate is Map && candidate['url'] is String) {
            final url = Uri.tryParse(candidate['url'] as String);
            if (url != null && url.scheme == 'https' && url.host.isNotEmpty) {
              thumbnail = url.toString();
              break;
            }
          }
        }
      }
      final views =
          item['viewCountText'] as String? ?? _formatViews(item['viewCount']);
      final durationSeconds = (item['lengthSeconds'] as num?)?.toInt() ?? 0;
      videos.add(
        VideoModel(
          id: id,
          title: title.trim(),
          channelName: item['author'] as String? ?? 'YouTube creator',
          views: views,
          duration: durationSeconds > 0
              ? _formatDuration(durationSeconds)
              : (item['liveNow'] == true ? 'LIVE' : '—'),
          thumbnailUrl: thumbnail,
          channelAvatar: '',
          isVerified: item['authorVerified'] == true,
          category: category,
          playbackUrl: 'https://www.youtube.com/watch?v=$id',
        ),
      );
    }
    return List.unmodifiable(videos);
  }

  String _formatViews(Object? value) {
    if (value is num) return '${value.toString()} views';
    return 'View count unavailable';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remaining = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  Future<dynamic> _requestJson(String path, Map<String, String> query) async {
    final instances = await _instances();
    Object? lastError;
    for (final base in instances) {
      try {
        final uri = base.replace(
          path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path',
          queryParameters: query,
        );
        return jsonDecode(await _loader(uri));
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError is InvidiousCatalogException) throw lastError;
    throw InvidiousCatalogException(
      'No public catalog instance is responding. Try again later. (${lastError ?? 'No instance available'})',
    );
  }

  static Future<String> _load(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'TubeArena/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InvidiousCatalogException(
          'Catalog request failed (HTTP ${response.statusCode}).',
        );
      }
      return body;
    } on SocketException {
      throw const InvidiousCatalogException(
        'Network unavailable. Check your connection.',
      );
    } on TimeoutException {
      throw const InvidiousCatalogException(
        'The public catalog request timed out.',
      );
    } finally {
      client.close(force: true);
    }
  }
}

class ImportedCatalogPlaylist {
  const ImportedCatalogPlaylist({
    required this.id,
    required this.title,
    required this.channel,
    required this.videos,
    required this.totalCount,
  });

  final String id;
  final String title;
  final String channel;
  final List<VideoModel> videos;
  final int totalCount;
}
