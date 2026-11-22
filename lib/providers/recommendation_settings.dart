import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent, device-local recommendation and channel preferences.
/// Channel names are used as a fallback identity until a source provides
/// stable channel IDs; they are normalized to avoid case-only duplicates.
class RecommendationSettings extends ChangeNotifier {
  RecommendationSettings._(this._prefs);

  static const categories = <String>[
    'Study', 'Funny', 'Romantic', 'Technology', 'Gaming', 'Music', 'Science', 'Sports',
  ];

  static const subtopics = <String, List<String>>{
    'Study': ['Mathematics', 'Chemistry', 'Physics', 'Biology', 'English', 'Exam preparation', 'Study music', 'Documentaries'],
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
  static const _defaultKey = 'recommendation_default_section_v1';
  static const _personalizationKey = 'recommendation_personalization_v1';

  final SharedPreferences _prefs;
  List<String> _interests = ['Study', 'Technology', 'Science'];
  List<String> _hiddenChannels = [];
  List<String> _subscriptions = [];
  List<String> _moreFeedback = [];
  List<String> _lessFeedback = [];
  Map<String, List<String>> _subtopics = {};
  String _defaultSection = 'Recommended';
  bool _personalization = true;

  List<String> get interests => List.unmodifiable(_interests);
  List<String> get hiddenChannels => List.unmodifiable(_hiddenChannels);
  List<String> get subscriptions => List.unmodifiable(_subscriptions);
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
  bool isSubscribed(String channel) => _subscriptions.any((item) => _normalize(item) == _normalize(channel));

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

  Future<void> toggleSubscription(String channel) async {
    if (channel.trim().isEmpty) return;
    if (isSubscribed(channel)) {
      _subscriptions.removeWhere((item) => _normalize(item) == _normalize(channel));
    } else {
      _subscriptions.add(channel.trim());
    }
    await _prefs.setStringList(_subscriptionsKey, _subscriptions);
    notifyListeners();
  }

  Future<void> recordMore(String videoId) async {
    _moreFeedback.remove(videoId);
    if (!_moreFeedback.contains(videoId)) _moreFeedback.add(videoId);
    await _prefs.setStringList(_moreKey, _moreFeedback);
    notifyListeners();
  }

  Future<void> recordLess(String videoId) async {
    _lessFeedback.remove(videoId);
    if (!_lessFeedback.contains(videoId)) _lessFeedback.add(videoId);
    await _prefs.setStringList(_lessKey, _lessFeedback);
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
