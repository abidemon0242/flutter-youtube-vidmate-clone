import 'dart:async';
import 'dart:io';

import 'package:xml/xml.dart';

import '../models/video_model.dart';

class YouTubeRssException implements Exception {
  const YouTubeRssException(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef RssTextLoader = Future<String> Function(Uri uri);

class YouTubeChannelRssService {
  YouTubeChannelRssService({RssTextLoader? loader}) : _loader = loader ?? _load;
  final RssTextLoader _loader;

  static const _atom = 'http://www.w3.org/2005/Atom';
  static const _youtube = 'http://www.youtube.com/xml/schemas/2015';

  String channelIdFromInput(String input) {
    final uri = Uri.tryParse(
      input.trim().startsWith('http') ? input.trim() : 'https://${input.trim()}',
    );
    if (uri == null ||
        !{'youtube.com', 'www.youtube.com', 'm.youtube.com'}.contains(uri.host.toLowerCase())) {
      throw const YouTubeRssException(
        'Enter a YouTube channel URL or its public channel RSS URL.',
      );
    }
    final rssId = uri.queryParameters['channel_id'];
    final pathParts = uri.pathSegments;
    final pathId = pathParts.length >= 2 && pathParts.first == 'channel'
        ? pathParts[1]
        : null;
    final id = rssId ?? pathId;
    if (id == null || !RegExp(r'^UC[A-Za-z0-9_-]{22}$').hasMatch(id)) {
      throw const YouTubeRssException(
        'This channel link does not expose a channel ID. Use its /channel/UC… URL or the channel RSS URL.',
      );
    }
    return id;
  }

  Future<List<VideoModel>> fetchChannel(String input) async {
    final channelId = channelIdFromInput(input);
    final uri = Uri.https('www.youtube.com', '/feeds/videos.xml', {
      'channel_id': channelId,
    });
    final xml = await _loader(uri);
    XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException {
      throw const YouTubeRssException('YouTube returned an invalid channel feed.');
    }
    final feedTitle = document
        .findAllElements('title', namespace: _atom)
        .firstOrNull
        ?.innerText
        .trim();
    final author = document
        .findAllElements('author', namespace: _atom)
        .firstOrNull;
    final channelName = author
            ?.findElements('name', namespace: _atom)
            .firstOrNull
            ?.innerText
            .trim() ??
        feedTitle ??
        'YouTube channel';
    final videos = <VideoModel>[];
    for (final entry in document.findAllElements('entry', namespace: _atom)) {
      final id = entry
          .findElements('videoId', namespace: _youtube)
          .firstOrNull
          ?.innerText
          .trim();
      if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) continue;
      final title = entry
          .findElements('title', namespace: _atom)
          .firstOrNull
          ?.innerText
          .trim();
      final published = entry
          .findElements('published', namespace: _atom)
          .firstOrNull
          ?.innerText;
      videos.add(VideoModel(
        id: id,
        title: title?.isNotEmpty == true ? title! : 'YouTube video',
        channelName: channelName,
        views: published == null ? 'Recent upload' : _relativeDate(published),
        duration: '—',
        thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
        channelAvatar: '',
        isVerified: false,
        category: 'Subscriptions',
        playbackUrl: 'https://www.youtube.com/watch?v=$id',
      ));
    }
    return videos;
  }

  String _relativeDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Recent upload';
    final age = DateTime.now().difference(date);
    if (age.inDays <= 0) return 'Today';
    if (age.inDays == 1) return '1 day ago';
    if (age.inDays < 7) return '${age.inDays} days ago';
    return '${(age.inDays / 7).floor()} weeks ago';
  }

  static Future<String> _load(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/atom+xml, application/xml, text/xml');
      request.headers.set(HttpHeaders.userAgentHeader, 'TubeArena/1.0');
      final response = await request.close().timeout(const Duration(seconds: 18));
      final body = await response.transform(const SystemEncoding().decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw YouTubeRssException('Channel feed request failed (HTTP ${response.statusCode}).');
      }
      return body;
    } on SocketException {
      throw const YouTubeRssException('Network unavailable. Check your connection.');
    } on TimeoutException {
      throw const YouTubeRssException('Channel feed request timed out. Please retry.');
    } finally {
      client.close(force: true);
    }
  }
}
