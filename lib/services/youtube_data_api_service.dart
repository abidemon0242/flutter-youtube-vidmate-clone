import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/video_model.dart';

class YouTubeApiException implements Exception {
  const YouTubeApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Official YouTube Data API v3 client for search and the regional
/// most-popular chart. The API key is a public client identifier: restrict it
/// in Google Cloud to this Android package and the YouTube Data API.
class YouTubeDataApiService {
  YouTubeDataApiService({String? apiKey, HttpClient Function()? clientFactory})
      : _apiKey = apiKey ?? const String.fromEnvironment('YOUTUBE_DATA_API_KEY'),
        _clientFactory = clientFactory ?? HttpClient.new;

  final String _apiKey;
  final HttpClient Function() _clientFactory;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<List<VideoModel>> getMostPopular({
    String category = 'All',
    String regionCode = 'BD',
  }) async {
    _requireKey();
    if (category == 'Live' || category == 'Design' || category == 'Tutorials') {
      final query = switch (category) {
        'Live' => 'live stream',
        'Design' => 'graphic design',
        _ => 'educational tutorials',
      };
      return searchVideos(query, eventType: category == 'Live' ? 'live' : null);
    }

    const categoryIds = <String, String>{
      'Music': '10',
      'Movies': '1',
      'Tech': '28',
      'News': '25',
      'Gaming': '20',
      'Tutorials': '27',
    };
    final params = <String, String>{
      'part': 'snippet,contentDetails,statistics',
      'chart': 'mostPopular',
      'regionCode': regionCode,
      'maxResults': '25',
    };
    final categoryId = categoryIds[category];
    if (categoryId != null) params['videoCategoryId'] = categoryId;
    final data = await _get('videos', params);
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_videoFromPopular)
        .whereType<VideoModel>()
        .toList(growable: false);
  }

  Future<List<VideoModel>> searchVideos(
    String query, {
    String? eventType,
    String regionCode = 'BD',
  }) async {
    _requireKey();
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final params = <String, String>{
      'part': 'snippet',
      'type': 'video',
      'q': normalized,
      'regionCode': regionCode,
      'maxResults': '25',
      'safeSearch': 'moderate',
    };
    if (eventType != null) params['eventType'] = eventType;
    final data = await _get('search', params);
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_videoFromSearch)
        .whereType<VideoModel>()
        .toList(growable: false);
  }

  void _requireKey() {
    if (!isConfigured) {
      throw const YouTubeApiException(
        'YouTube Data API key is not configured. Add a restricted key with --dart-define=YOUTUBE_DATA_API_KEY=YOUR_KEY.',
      );
    }
  }

  Future<Map<String, dynamic>> _get(
    String resource,
    Map<String, String> parameters,
  ) async {
    final uri = Uri.https(
      'youtube.googleapis.com',
      '/youtube/v3/$resource',
      {...parameters, 'key': _apiKey},
    );
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 25));
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'YouTube API returned HTTP ${response.statusCode}.';
        if (decoded is Map<String, dynamic>) {
          final error = decoded['error'];
          if (error is Map<String, dynamic>) {
            message = error['message'] as String? ?? message;
          }
        }
        throw YouTubeApiException(message);
      }
      if (decoded is! Map<String, dynamic>) {
        throw const YouTubeApiException('Unexpected response from YouTube.');
      }
      return decoded;
    } on SocketException {
      throw const YouTubeApiException('Network unavailable. Check your connection.');
    } on TimeoutException {
      throw const YouTubeApiException('YouTube request timed out. Please retry.');
    } finally {
      client.close(force: true);
    }
  }

  VideoModel? _videoFromPopular(Map<String, dynamic> item) {
    final id = item['id'];
    final snippet = item['snippet'];
    if (id is! String || snippet is! Map<String, dynamic>) return null;
    final statistics = item['statistics'] as Map<String, dynamic>? ?? const {};
    final details = item['contentDetails'] as Map<String, dynamic>? ?? const {};
    return _makeVideo(
      id: id,
      snippet: snippet,
      views: _formatViews(statistics['viewCount']),
      duration: _formatIsoDuration(details['duration'] as String?),
    );
  }

  VideoModel? _videoFromSearch(Map<String, dynamic> item) {
    final idData = item['id'];
    final snippet = item['snippet'];
    if (idData is! Map<String, dynamic> ||
        snippet is! Map<String, dynamic>) return null;
    final id = idData['videoId'];
    if (id is! String || id.isEmpty) return null;
    return _makeVideo(
      id: id,
      snippet: snippet,
      views: 'YouTube',
      duration: '—',
    );
  }

  VideoModel? _makeVideo({
    required String id,
    required Map<String, dynamic> snippet,
    required String views,
    required String duration,
  }) {
    final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? const {};
    final thumbnail = (thumbnails['high'] ??
            thumbnails['medium'] ??
            thumbnails['default']) as Map<String, dynamic>? ??
        const {};
    final channel = snippet['channelTitle'] as String? ?? 'YouTube channel';
    final title = snippet['title'] as String? ?? 'Untitled video';
    return VideoModel(
      id: id,
      title: title,
      channelName: channel,
      views: views,
      duration: duration,
      thumbnailUrl: thumbnail['url'] as String? ??
          'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      channelAvatar: '',
      isVerified: false,
      category: 'YouTube',
      playbackUrl: 'https://www.youtube.com/watch?v=$id',
    );
  }

  String _formatViews(dynamic raw) {
    final count = int.tryParse(raw?.toString() ?? '');
    if (count == null) return 'Views unavailable';
    if (count >= 1000000000) return '${(count / 1000000000).toStringAsFixed(1)}B views';
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M views';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K views';
    return '$count views';
  }

  String _formatIsoDuration(String? value) {
    if (value == null) return '—';
    final match = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$').firstMatch(value);
    if (match == null) return '—';
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    final totalMinutes = hours * 60 + minutes;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${totalMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
