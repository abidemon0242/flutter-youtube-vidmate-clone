import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/services/home_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomeLibraryService library;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    library = HomeLibraryService();
  });

  VideoModel video(String id, {String category = 'Tech'}) => VideoModel(
    id: id,
    youtubeId: id,
    title: 'Video $id',
    channelName: 'Channel $id',
    category: category,
    duration: '02:30',
    thumbnailUrl: 'https://example.com/$id.jpg',
  );

  test('Watch Later persists videos and supports removal', () async {
    final item = video('abcdefghijk');
    await library.setSaved(item, true);

    expect((await library.watchLater()).single.id, item.id);
    expect(await library.isSaved(item), isTrue);

    await library.setSaved(item, false);
    expect(await library.watchLater(), isEmpty);
    expect(await library.isSaved(item), isFalse);
  });

  test('history is newest first and does not duplicate a video', () async {
    final first = video('abcdefghijk');
    final second = video('lmnopqrstuv');

    await library.addToHistory(first);
    await library.addToHistory(second);
    await library.addToHistory(first);

    expect((await library.history()).map((item) => item.id).toList(), [
      first.id,
      second.id,
    ]);
  });

  test('history ignores non-YouTube sample videos', () async {
    const sample = VideoModel(
      id: 'sample',
      title: 'Sample',
      channelName: 'Tube Arena',
      playbackUrl: VideoModel.samplePlaybackUrl,
    );

    await library.addToHistory(sample);

    expect(await library.history(), isEmpty);
  });

  test('migrates bookmarks from the previous preference format', () async {
    const legacyId = 'abcdefghijk';
    final item = video(legacyId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('saved_video_$legacyId', true);

    expect(await library.isSaved(item), isTrue);
    expect((await library.watchLater()).single.id, item.id);
  });

  test('video model JSON round trip preserves playback metadata', () {
    final item = video('abcdefghijk', category: 'Gaming');
    final restored = VideoModel.fromJson(item.toJson());

    expect(restored.id, item.id);
    expect(restored.youtubeId, item.youtubeId);
    expect(restored.title, item.title);
    expect(restored.category, 'Gaming');
    expect(restored.thumbnailUrl, item.thumbnailUrl);
  });
}
