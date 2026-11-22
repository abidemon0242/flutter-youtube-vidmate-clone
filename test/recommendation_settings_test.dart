import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tube_arena/providers/recommendation_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('interests and category subtopics persist', () async {
    var settings = await RecommendationSettings.load();
    await settings.setInterest('Study', true);
    await settings.setSubtopic('Study', 'Chemistry', true);

    settings = await RecommendationSettings.load();
    expect(settings.interests, contains('Study'));
    expect(settings.selectedSubtopics('Study'), contains('Chemistry'));
    expect(settings.queryFor('Study'), contains('Chemistry'));
  });

  test('hidden channels are case-insensitive and reversible', () async {
    var settings = await RecommendationSettings.load();
    await settings.hideChannel('Example Channel');
    expect(settings.isHidden('example channel'), isTrue);

    await settings.restoreChannel('EXAMPLE CHANNEL');
    expect(settings.isHidden('Example Channel'), isFalse);
  });

  test('subscriptions persist independently from hidden channels', () async {
    var settings = await RecommendationSettings.load();
    await settings.toggleSubscription('Creator');
    await settings.hideChannel('Creator');

    settings = await RecommendationSettings.load();
    expect(settings.isSubscribed('Creator'), isTrue);
    expect(settings.isHidden('Creator'), isTrue);
    await settings.toggleSubscription('Creator');
    expect(settings.isSubscribed('Creator'), isFalse);
  });

  test('more and less recommendation feedback persists', () async {
    var settings = await RecommendationSettings.load();
    await settings.recordMore('video-1');
    await settings.recordLess('video-2');

    settings = await RecommendationSettings.load();
    expect(settings.prefersMore('video-1'), isTrue);
    expect(settings.prefersLess('video-2'), isTrue);
    await settings.resetPersonalization();
    expect(settings.prefersMore('video-1'), isFalse);
    expect(settings.prefersLess('video-2'), isFalse);
  });
  test('more and less feedback are mutually exclusive', () async {
    final settings = await RecommendationSettings.load();
    await settings.recordMore('video-1');
    await settings.recordLess('video-1');
    expect(settings.prefersMore('video-1'), isFalse);
    expect(settings.prefersLess('video-1'), isTrue);

    await settings.recordMore('video-1');
    expect(settings.prefersMore('video-1'), isTrue);
    expect(settings.prefersLess('video-1'), isFalse);
  });

  test('personalization off ignores selected subtopics', () async {
    final settings = await RecommendationSettings.load();
    await settings.setSubtopic('Study', 'Chemistry', true);
    await settings.setPersonalization(false);
    expect(settings.queryFor('Study'), 'Study');
  });
}
