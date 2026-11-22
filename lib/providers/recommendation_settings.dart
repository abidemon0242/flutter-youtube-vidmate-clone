import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_model.dart';

/// Persistent, device-local recommendation and channel preferences.
/// Channel names are used as a fallback identity until a source provides
/// stable channel IDs; they are normalized to avoid case-only duplicates.
class RecommendationSettings extends ChangeNotifier {
  RecommendationSettings._(this._prefs);

  static const categories = <String>[
    'Study',
    'Funny',
    'Romantic',
    'Technology',
    'Gaming',
    'Music',
    'Science',
    'Sports',
  ];

  static const subtopics = <String, List<String>>{
    'Study': [
      'Mathematics',
      'Chemistry',
      'Physics',
      'Biology',
      'English',
      'Exam preparation',
      'Study music',
      'Documentaries',
    ],
    'Funny': ['Comedy', 'Memes', 'Funny animals', 'Sketches', 'Pranks'],
    'Romantic': ['Romantic films', 'Love stories', 'Romantic music'],
    'Technology': ['Artificial intelligence', 'Robotics', 'Smartphones', 'Programming', 'Cybersecurity'],
    'Gaming': ['Gameplay', 'Game tutorials', 'Esports', 'Game reviews'],
    'Music': ['Instrumental', 'Classical', 'Pop', 'Lo-fi', 'Live performances'],
    'Science': ['Space', 'Nature', 'Experiments', 'Discoveries'],
    'Sports': ['Football', 'Cricket', 'Basketball', 'Sports analysis'],
  };

  static const _interestsKey = 'recommendation_interests_v1';
  static const _subtopicsKey = 'recommendation_subtopics_v1';
  static const _hiddenKey = 'recommendation_hidden_channels_v1';
  static const _subscriptionsKey = 'recommendation_subscriptions_v1';
  static const _moreKey = 'recommendation_more_feedback_v1';
  static const _lessKey = 'recommendation_less_feedback_v1';
  static const _moreSignalsKey = 'recommendation_more_signals_v1';
  static const _lessSignalsKey = 'recommendation_less_signals_v1';
  static const _defaultKey = 'recommendation_default_section_v1';
  static const _personalizationKey = 'recommendation_personalization_v1';

  final SharedPreferences _prefs;
  List<String> _interests = ['Study', 'Technology', 'Science'];
  List<String> _hiddenChannels = [];
  List<String> _subscriptions = [];
  List<String> _moreFeedback = [];
  List<String> _lessFeedback = [];
  List<Map<String, String>> _moreSignals = [];
  List<Map<String, String>> _lessSignals = [];
  final Map<String, List<String>> _subtopics = {};
  String _defaultSection = 'Recommended';
  bool _personalization = true;

  List<String> get interests => List.unmodifiable(_interests);
  List<String> get hiddenChannels => List.unmodifiable(_hiddenChannels);
  String _subscriptionName(String record) {
    final separator = record.indexOf('::');
    return separator < 0 ? record : record.substring(separator + 2);
  }

  String? _subscriptionId(String record) {
    final separator = record.indexOf('::');
    if (separator <= 0) return null;
    return record.substring(0, separator);
  }

  List<String> get subscriptions => List.unmodifiable(_subscriptions.map(_subscriptionName));
  Map<String, String> get subscriptionsById {
    final result = <String, String>{};
    for (final record in _subscriptions) {
      final id = _subscriptionId(record);
      if (id != null) result[id] = _subscriptionName(record);
    }
    return Map.unmodifiable(result);
  }

  List<String> get legacySubscriptions =>
      List.unmodifiable(_subscriptions.where((record) => _subscriptionId(record) == null).map(_subscriptionName));
  String get defaultSection => _defaultSection;
  bool get personalization => _personalization;
  List<String> selectedSubtopics(String category) => List.unmodifiable(_subtopics[category] ?? const []);

  static Future<RecommendationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = RecommendationSettings._(prefs);
    settings._interests = prefs.getStringList(_interestsKey) ?? settings._interests;
    settings._hiddenChannels = prefs.getStringList(_hiddenKey) ?? [];
    settings._subscriptions = prefs.getStringList(_subscriptionsKey) ?? [];
    settings._moreFeedback = prefs.getStringList(_moreKey) ?? [];
    settings._lessFeedback = prefs.getStringList(_lessKey) ?? [];
    settings._moreSignals = _decodeSignals(prefs.getStringList(_moreSignalsKey));
    settings._lessSignals = _decodeSignals(prefs.getStringList(_lessSignalsKey));
    settings._defaultSection = prefs.getString(_defaultKey) ?? 'Recommended';
    settings._personalization = prefs.getBool(_personalizationKey) ?? true;
    final raw = prefs.getStringList(_subtopicsKey) ?? [];
    for (final entry in raw) {
      final split = entry.split('::');
      if (split.length == 2) {
        settings._subtopics.putIfAbsent(split.first, () => []).add(split.last);
      }
    }
    return settings;
  }

  Future<void> setInterest(String value, bool enabled) async {
    if (enabled && !_interests.contains(value)) _interests.add(value);
    if (!enabled) _interests.remove(value);
    await _prefs.setStringList(_interestsKey, _interests);
    notifyListeners();
  }

  Future<void> setSubtopic(String category, String value, bool enabled) async {
    final values = _subtopics.putIfAbsent(category, () => []);
    if (enabled && !values.contains(value)) values.add(value);
    if (!enabled) values.remove(value);
    final serialized = <String>[];
    for (final entry in _subtopics.entries) {
      serialized.addAll(entry.value.map((value) => '${entry.key}::$value'));
    }
    await _prefs.setStringList(_subtopicsKey, serialized);
    notifyListeners();
  }

  Future<void> setDefaultSection(String value) async {
    _defaultSection = value;
    await _prefs.setString(_defaultKey, value);
    notifyListeners();
  }

  Future<void> setPersonalization(bool value) async {
    _personalization = value;
    await _prefs.setBool(_personalizationKey, value);
    notifyListeners();
  }

  String _normalize(String value) => value.trim().toLowerCase();

  bool isHidden(String channel) => _hiddenChannels.any((item) => _normalize(item) == _normalize(channel));
  bool isSubscribed(String channel, {String? channelId}) => _subscriptions.any((record) {
    final id = _subscriptionId(record);
    if (channelId != null && channelId.isNotEmpty && id != null) return id == channelId;
    return _normalize(_subscriptionName(record)) == _normalize(channel);
  });

  Future<void> hideChannel(String channel) async {
    if (channel.trim().isEmpty || isHidden(channel)) return;
    _hiddenChannels.add(channel.trim());
    await _prefs.setStringList(_hiddenKey, _hiddenChannels);
    notifyListeners();
  }

  Future<void> restoreChannel(String channel) async {
    _hiddenChannels.removeWhere((item) => _normalize(item) == _normalize(channel));
    await _prefs.setStringList(_hiddenKey, _hiddenChannels);
    notifyListeners();
  }

  Future<void> toggleSubscription(String channel, {String? channelId}) async {
    if (channel.trim().isEmpty) return;
    final stableId = channelId?.trim();
    final existingIndex = _subscriptions.indexWhere((record) {
      final id = _subscriptionId(record);
      if (stableId != null && stableId.isNotEmpty && id != null) return id == stableId;
      return _normalize(_subscriptionName(record)) == _normalize(channel);
    });
    if (existingIndex >= 0) {
      _subscriptions.removeAt(existingIndex);
    } else {
      _subscriptions.add(stableId == null || stableId.isEmpty ? channel.trim() : '$stableId::${channel.trim()}');
    }
    await _prefs.setStringList(_subscriptionsKey, _subscriptions);
    notifyListeners();
  }

  static List<Map<String, String>> _decodeSignals(List<String>? raw) {
    if (raw == null) return [];
    final result = <Map<String, String>>[];
    for (final item in raw) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(item) as Map);
        result.add(decoded.map((key, value) => MapEntry(key, value.toString())));
      } catch (_) {
        // Ignore malformed recommendation metadata without losing saved IDs.
      }
    }
    return result;
  }

  static Map<String, String> _signalFor(VideoModel video) {
    final keywords = video.title
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 3)
        .toSet()
        .take(12)
        .join(' ');
    return {
      'id': video.id,
      'channelId': video.channelId ?? '',
      'channel': video.channelName.trim().toLowerCase(),
      'category': video.category.trim().toLowerCase(),
      'keywords': keywords,
    };
  }

  Future<void> _saveSignals() async {
    await _prefs.setStringList(_moreSignalsKey, _moreSignals.map(jsonEncode).toList());
    await _prefs.setStringList(_lessSignalsKey, _lessSignals.map(jsonEncode).toList());
  }

  void _rememberSignal(List<Map<String, String>> signals, VideoModel video) {
    signals.removeWhere((signal) => signal['id'] == video.id);
    signals.add(_signalFor(video));
    if (signals.length > 20) signals.removeRange(0, signals.length - 20);
  }

  /// Records topic and channel details so future feeds can rank related videos.
  Future<void> recordMoreFor(VideoModel video) async {
    await recordMore(video.id);
    _rememberSignal(_moreSignals, video);
    _lessSignals.removeWhere((signal) => signal['id'] == video.id);
    await _saveSignals();
    notifyListeners();
  }

  Future<void> recordLessFor(VideoModel video) async {
    await recordLess(video.id);
    _rememberSignal(_lessSignals, video);
    _moreSignals.removeWhere((signal) => signal['id'] == video.id);
    await _saveSignals();
    notifyListeners();
  }

  int feedbackScore(VideoModel video) {
    var score = prefersMore(video.id) ? 2 : (prefersLess(video.id) ? -1 : 0);
    score += _similarityScore(video, _moreSignals, 1);
    score += _similarityScore(video, _lessSignals, -1);
    return score;
  }

  int _similarityScore(VideoModel video, List<Map<String, String>> signals, int direction) {
    final candidate = _signalFor(video);
    final candidateWords = candidate['keywords']!.split(' ').where((word) => word.isNotEmpty).toSet();
    var total = 0;
    for (final signal in signals) {
      if (signal['id'] == video.id) continue;
      var strength = 0;
      final channelId = candidate['channelId']!;
      if (channelId.isNotEmpty && channelId == signal['channelId']) {
        strength += 4;
      } else if (candidate['channel']!.isNotEmpty && candidate['channel'] == signal['channel']) {
        strength += 3;
      }
      if (candidate['category']!.isNotEmpty && candidate['category'] == signal['category']) strength++;
      final words = signal['keywords']!.split(' ').where((word) => word.isNotEmpty).toSet();
      final overlap = candidateWords.intersection(words).length;
      strength += (overlap > 3 ? 3 : overlap) * 2;
      total += strength * direction;
    }
    return total;
  }

  Future<void> recordMore(String videoId) async {
    _lessFeedback.remove(videoId);
    _moreFeedback.remove(videoId);
    _moreFeedback.add(videoId);
    await _prefs.setStringList(_moreKey, _moreFeedback);
    await _prefs.setStringList(_lessKey, _lessFeedback);
    _lessSignals.removeWhere((signal) => signal['id'] == videoId);
    await _saveSignals();
    notifyListeners();
  }

  Future<void> recordLess(String videoId) async {
    _moreFeedback.remove(videoId);
    _lessFeedback.remove(videoId);
    _lessFeedback.add(videoId);
    await _prefs.setStringList(_lessKey, _lessFeedback);
    await _prefs.setStringList(_moreKey, _moreFeedback);
    _moreSignals.removeWhere((signal) => signal['id'] == videoId);
    await _saveSignals();
    notifyListeners();
  }

  bool prefersMore(String videoId) => _moreFeedback.contains(videoId);
  bool prefersLess(String videoId) => _lessFeedback.contains(videoId);

  Future<void> resetPersonalization() async {
    _moreFeedback.clear();
    _lessFeedback.clear();
    _subtopics.clear();
    await _prefs.remove(_moreKey);
    await _prefs.remove(_lessKey);
    _moreSignals.clear();
    _lessSignals.clear();
    await _prefs.remove(_moreSignalsKey);
    await _prefs.remove(_lessSignalsKey);
    await _prefs.remove(_subtopicsKey);
    notifyListeners();
  }

  String queryFor(String category) {
    if (!_personalization) return category;
    final topics = _subtopics[category] ?? const <String>[];
    if (topics.isNotEmpty) return topics.join(' ');
    return category;
  }
}
