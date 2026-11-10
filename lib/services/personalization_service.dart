import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_model.dart';
import 'youtube_rss_service.dart';
import 'invidious_catalog_service.dart';

class ActivityRecord {
  const ActivityRecord(
    this.type,
    this.time, {
    this.title = '',
    this.category = '',
    this.query = '',
    this.seconds = 0,
  });
  final String type, title, category, query;
  final DateTime time;
  final int seconds;
  Map<String, dynamic> toJson() => {
    'type': type,
    'time': time.toUtc().toIso8601String(),
    'title': title,
    'category': category,
    'query': query,
    'seconds': seconds,
  };
  factory ActivityRecord.fromJson(Map<String, dynamic> j) => ActivityRecord(
    j['type'] as String? ?? 'unknown',
    DateTime.tryParse(j['time'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    title: j['title'] as String? ?? '',
    category: j['category'] as String? ?? '',
    query: j['query'] as String? ?? '',
    seconds: (j['seconds'] as num?)?.toInt() ?? 0,
  );
}

class ImportedPlaylist {
  const ImportedPlaylist(this.id, this.title, this.channel, this.videos);
  final String id, title, channel;
  final List<VideoModel> videos;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channel': channel,
    'videos': videos
        .map(
          (v) => {
            'id': v.id,
            'title': v.title,
            'channelName': v.channelName,
            'views': v.views,
            'duration': v.duration,
            'thumbnailUrl': v.thumbnailUrl,
            'channelAvatar': v.channelAvatar,
            'isVerified': v.isVerified,
            'category': v.category,
            'playbackUrl': v.playbackUrl,
          },
        )
        .toList(),
  };
  factory ImportedPlaylist.fromJson(Map<String, dynamic> j) => ImportedPlaylist(
    j['id'] as String,
    j['title'] as String? ?? 'Playlist',
    j['channel'] as String? ?? '',
    (j['videos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (v) => VideoModel(
            id: v['id'] as String,
            title: v['title'] as String? ?? 'Video',
            channelName: v['channelName'] as String? ?? '',
            views: v['views'] as String? ?? '',
            duration: v['duration'] as String? ?? '—',
            thumbnailUrl: v['thumbnailUrl'] as String? ?? '',
            channelAvatar: v['channelAvatar'] as String? ?? '',
            isVerified: v['isVerified'] as bool? ?? false,
            category: 'Imported playlist',
            playbackUrl:
                v['playbackUrl'] as String? ??
                'https://www.youtube.com/watch?v=' + (v['id'] as String),
          ),
        )
        .toList(),
  );
}

class PlaylistImportException implements Exception {
  const PlaylistImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PersonalizationService extends ChangeNotifier {
  PersonalizationService({
    Future<Directory> Function()? directoryResolver,
    YouTubeChannelRssService? rssService,
    InvidiousCatalogService? catalogService,
  }) : _directoryResolver =
           directoryResolver ?? getApplicationDocumentsDirectory,
       _rssService = rssService ?? YouTubeChannelRssService(),
       _catalogService = catalogService ?? InvidiousCatalogService();
  final Future<Directory> Function() _directoryResolver;
  final YouTubeChannelRssService _rssService;
  final InvidiousCatalogService _catalogService;
  final List<ActivityRecord> _events = [];
  final List<ImportedPlaylist> _playlists = [];
  bool _ready = false;
  bool _consentDecided = false;
  bool _personalizationEnabled = false;
  Future<void> _queue = Future<void>.value();
  List<ActivityRecord> get activity => List.unmodifiable(_events);
  List<ImportedPlaylist> get playlists => List.unmodifiable(_playlists);
  int get activityCount => _events.length;
  bool get consentDecided => _consentDecided;
  bool get personalizationEnabled => _personalizationEnabled;
  Future<File> _file() async {
    final d = await _directoryResolver();
    final folder = Directory(d.path + '/TubeArena');
    await folder.create(recursive: true);
    return File(folder.path + '/personalization.json');
  }

  Future<void> initialize() async {
    if (_ready) return;
    try {
      final f = await _file();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString());
        if (j is Map<String, dynamic>) {
          _consentDecided = j['consentDecided'] as bool? ?? false;
          _personalizationEnabled =
              j['personalizationEnabled'] as bool? ?? false;
          if (j['activity'] is List)
            _events.addAll(
              (j['activity'] as List).whereType<Map<String, dynamic>>().map(
                ActivityRecord.fromJson,
              ),
            );
          if (j['playlists'] is List)
            _playlists.addAll(
              (j['playlists'] as List).whereType<Map<String, dynamic>>().map(
                ImportedPlaylist.fromJson,
              ),
            );
        }
      }
    } catch (e) {
      debugPrint('Personalization restore: $e');
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> record({
    required String type,
    VideoModel? video,
    String query = '',
    int seconds = 0,
  }) async {
    if (!_ready) await initialize();
    if (!_personalizationEnabled) return;
    if (type == 'search' && query.trim().isEmpty) return;
    _events.insert(
      0,
      ActivityRecord(
        type,
        DateTime.now(),
        title: video?.title ?? '',
        category: video?.category ?? '',
        query: query.trim(),
        seconds: seconds.clamp(0, 86400),
      ),
    );
    if (_events.length > 2000) _events.removeRange(2000, _events.length);
    notifyListeners();
    await _persist();
  }

  Future<ImportedPlaylist> addChannelFeed(String input) async {
    if (!_ready) await initialize();
    try {
      String channelId;
      try {
        channelId = _rssService.channelIdFromInput(input);
      } on YouTubeRssException {
        channelId = await _catalogService.resolveChannelId(input);
      }
      final videos = await _rssService.fetchChannel(
        'https://www.youtube.com/channel/$channelId',
      );
      if (videos.isEmpty) {
        throw const PlaylistImportException(
          'No recent public uploads were found for this channel.',
        );
      }
      final channelName = videos.first.channelName;
      final channel = ImportedPlaylist(
        channelId,
        channelName,
        channelName,
        videos,
      );
      _playlists.removeWhere((item) => item.id == channelId);
      _playlists.insert(0, channel);
      await _persist();
      notifyListeners();
      await record(
        type: 'playlist_import',
        query: channel.title,
        video: channel.videos.first,
      );
      return channel;
    } on YouTubeRssException catch (error) {
      throw PlaylistImportException(error.message);
    } on InvidiousCatalogException catch (error) {
      throw PlaylistImportException(error.message);
    }
  }

  Future<List<VideoModel>> refreshChannelFeeds() async {
    if (!_ready) await initialize();
    final refreshed = <ImportedPlaylist>[];
    for (final channel in _playlists) {
      try {
        if (channel.id.startsWith('playlist:')) {
          final playlistId = channel.id.substring('playlist:'.length);
          final latest = await _catalogService.fetchPlaylist(playlistId);
          refreshed.add(
            ImportedPlaylist(
              channel.id,
              latest.title,
              latest.channel,
              latest.videos.isEmpty ? channel.videos : latest.videos,
            ),
          );
        } else if (RegExp(r'^UC[A-Za-z0-9_-]{22}$').hasMatch(channel.id)) {
          final videos = await _rssService.fetchChannel(
            'https://www.youtube.com/channel/' + channel.id,
          );
          refreshed.add(
            ImportedPlaylist(
              channel.id,
              videos.isEmpty ? channel.title : videos.first.channelName,
              videos.isEmpty ? channel.channel : videos.first.channelName,
              videos.isEmpty ? channel.videos : videos,
            ),
          );
        } else {
          refreshed.add(channel);
        }
      } on YouTubeRssException catch (error) {
        debugPrint(
          'Channel feed refresh failed for ' +
              channel.id +
              ': ' +
              error.message,
        );
        refreshed.add(channel);
      } on InvidiousCatalogException catch (error) {
        debugPrint(
          'Playlist refresh failed for ' + channel.id + ': ' + error.toString(),
        );
        refreshed.add(channel);
      }
    }
    _playlists
      ..clear()
      ..addAll(refreshed);
    await _persist();
    notifyListeners();
    return _playlists.expand((channel) => channel.videos).toList();
  }

  Future<ImportedPlaylist> importPlaylist(String input) async {
    if (!_ready) await initialize();
    try {
      final resolved = await _catalogService.resolveYoutubeUrl(input);
      final playlistId = resolved.playlistId;
      if (playlistId == null) {
        throw const PlaylistImportException(
          'This URL is not a public YouTube playlist. Include a playlist link containing list=…',
        );
      }
      final imported = await _catalogService.fetchPlaylist(playlistId);
      if (imported.videos.isEmpty) {
        throw const PlaylistImportException(
          'No public videos were returned for this playlist.',
        );
      }
      final playlist = ImportedPlaylist(
        'playlist:$playlistId',
        imported.title,
        imported.channel,
        imported.videos,
      );
      _playlists.removeWhere((item) => item.id == playlist.id);
      _playlists.insert(0, playlist);
      await _persist();
      notifyListeners();
      await record(
        type: 'playlist_import',
        query: playlist.title,
        video: playlist.videos.first,
      );
      return playlist;
    } on InvidiousCatalogException catch (error) {
      throw PlaylistImportException(error.message);
    }
  }

  String get recommendationQuery {
    final weighted =
        interestProfile.entries
            .where(
              (entry) => !entry.key.startsWith('category:') && entry.value > 0,
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    if (weighted.isNotEmpty) {
      return weighted.take(3).map((entry) => entry.key).join(' ');
    }
    final titles = _playlists
        .expand((playlist) => playlist.videos)
        .take(12)
        .map((video) => video.title)
        .join(' ');
    final terms = _tokens(titles.toLowerCase()).take(3);
    return terms.join(' ');
  }

  Map<String, double> get interestProfile {
    if (!_personalizationEnabled) return const {};
    final out = <String, double>{}, now = DateTime.now();
    for (final e in _events) {
      final days = now.difference(e.time).inDays,
          recency = days <= 1
              ? 1.0
              : days <= 7
              ? 0.8
              : days <= 30
              ? 0.55
              : 0.25;
      final weight =
          (switch (e.type) {
            'like' => 4.0,
            'unlike' => -4.0,
            'watch' => e.seconds >= 120 ? 2.8 : 1.5,
            'open' => .7,
            'save' => 3.0,
            'unsave' => -3.0,
            'search' => 1.7,
            'playlist_import' => 2.0,
            'skip' => -1.2,
            'dislike' => -3.5,
            _ => 0.0,
          }) *
          recency;
      for (final t in _tokens(
        (e.title + ' ' + e.category + ' ' + e.query).toLowerCase(),
      )) {
        out[t] = (out[t] ?? 0) + weight;
      }
      if (e.category.isNotEmpty) {
        final k = 'category:' + e.category.toLowerCase();
        out[k] = (out[k] ?? 0) + weight;
      }
    }
    for (final p in _playlists)
      for (final v in p.videos)
        for (final t in _tokens(v.title.toLowerCase())) {
          out[t] = (out[t] ?? 0) + .65;
        }
    return Map.unmodifiable(out);
  }

  List<VideoModel> rankVideos(List<VideoModel> list) {
    final profile = interestProfile;
    if (profile.isEmpty) return List.unmodifiable(list);
    final ranked = list.map((v) {
      var score = 0.0;
      for (final t in _tokens(
        (v.title + ' ' + v.channelName + ' ' + v.category).toLowerCase(),
      ))
        score += profile[t] ?? 0;
      score += profile['category:' + v.category.toLowerCase()] ?? 0;
      return (video: v, score: score);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
    return ranked.map((x) => x.video).toList(growable: false);
  }

  Set<String> _tokens(String s) {
    const stop = {
      'the',
      'and',
      'for',
      'with',
      'from',
      'that',
      'this',
      'your',
      'you',
      'how',
      'what',
      'when',
      'where',
      'why',
      'are',
      'was',
      'into',
      'about',
      'video',
      'videos',
      'youtube',
      'official',
      'full',
      'new',
      'best',
      'top',
      'এবং',
      'কেন',
      'কী',
      'কিভাবে',
      'করে',
      'থেকে',
      'জন্য',
      'আমার',
      'আপনার',
      'ভিডিও',
    };
    return s
        .split(RegExp(r'[^a-z0-9\u0980-\u09FF]+'))
        .where((x) => x.length >= 2 && !stop.contains(x))
        .toSet();
  }

  Future<void> setConsent(bool enabled) async {
    _consentDecided = true;
    _personalizationEnabled = enabled;
    if (!enabled) {
      _events.clear();
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearActivity() async {
    _events.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    _queue = _queue.then((_) async {
      try {
        final f = await _file();
        await f.writeAsString(
          jsonEncode({
            'consentDecided': _consentDecided,
            'personalizationEnabled': _personalizationEnabled,
            'activity': _events.map((e) => e.toJson()).toList(),
            'playlists': _playlists.map((p) => p.toJson()).toList(),
          }),
          flush: true,
        );
      } catch (e) {
        debugPrint('Personalization save: $e');
      }
    });
    return _queue;
  }
}
