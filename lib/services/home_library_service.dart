import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_model.dart';

/// Local-only personalization data. No account or YouTube API key is required.
class HomeLibraryService {
  static const _savedKey = 'home_watch_later_v1';
  static const _historyKey = 'home_watch_history_v1';
  static const historyLimit = 100;

  Future<List<VideoModel>> watchLater() => _read(_savedKey);

  Future<List<VideoModel>> history() => _read(_historyKey);

  Future<void> addToHistory(VideoModel video) async {
    final items = await history();
    items.removeWhere((item) => item.id == video.id);
    items.insert(0, video);
    await _write(_historyKey, items.take(historyLimit).toList());
  }

  Future<bool> isSaved(VideoModel video) async {
    final items = await watchLater();
    if (items.any((item) => item.id == video.id)) return true;
    // Migrate bookmarks created by the earlier per-video preference format.
    final legacyKey = 'saved_video_${video.youtubeId ?? video.id}';
    final legacySaved = (await SharedPreferences.getInstance()).getBool(legacyKey) ?? false;
    if (legacySaved) await setSaved(video, true);
    return legacySaved;
  }

  Future<void> setSaved(VideoModel video, bool saved) async {
    final items = await watchLater();
    items.removeWhere((item) => item.id == video.id);
    if (saved) items.insert(0, video);
    await _write(_savedKey, items);
    await (await SharedPreferences.getInstance()).setBool('saved_video_${video.youtubeId ?? video.id}', saved);
  }

  Future<void> removeSaved(VideoModel video) async {
    final items = await watchLater();
    items.removeWhere((item) => item.id == video.id);
    await _write(_savedKey, items);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<List<VideoModel>> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().map(VideoModel.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(String key, List<VideoModel> videos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(videos.map((video) => video.toJson()).toList()));
  }
}
