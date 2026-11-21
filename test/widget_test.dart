import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tube_arena/core/theme/app_theme.dart';
import 'package:tube_arena/models/video_model.dart';
import 'package:tube_arena/providers/downloads_provider.dart';
import 'package:tube_arena/providers/theme_controller.dart';
import 'package:tube_arena/services/ad_blocker_service.dart';
import 'package:tube_arena/services/youtube_extraction_service.dart';
import 'package:tube_arena/ui/widgets/theme_mode_button.dart';

/// Serves fixed byte payloads per itag. When [gate] is set, every stream
/// waits for it before finishing, so tests can pause mid-download.
class FakeSource implements DownloadSource {
  FakeSource(this.payloads);
  final Map<int, List<int>> payloads;
  final List<({int tag, int start})> opens = [];
  Completer<void>? gate;

  @override
  Future<int> sizeOf(String videoId, int tag) async => payloads[tag]!.length;

  @override
  Future<SourceStream> open(String videoId, int tag, {int start = 0}) async {
    opens.add((tag: tag, start: start));
    final data = payloads[tag]!.sublist(start);
    final half = data.length ~/ 2;
    final currentGate = gate;
    Stream<List<int>> bytes() async* {
      yield data.sublist(0, half);
      if (currentGate != null) await currentGate.future;
      yield data.sublist(half);
    }

    return SourceStream(totalBytes: payloads[tag]!.length, bytes: bytes());
  }
}

const muxed = DownloadOption(
  kind: DownloadKind.video,
  label: '360p',
  container: 'mp4',
  videoTag: 18,
  audioTag: null,
  sizeBytes: 0,
);

const split = DownloadOption(
  kind: DownloadKind.video,
  label: '1080p',
  container: 'mp4',
  videoTag: 137,
  audioTag: 140,
  sizeBytes: 0,
);

Future<void> waitFor(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

void main() {
  late Directory root;
  late Directory downloads;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tube_arena_test');
    downloads = Directory('${root.path}/TubeArena/Downloads');
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (await root.exists()) await root.delete(recursive: true);
  });

  DownloadsProvider makeProvider(FakeSource source, {List<String>? merges}) => DownloadsProvider(
    source: source,
    downloadsDirectoryResolver: () async => downloads,
    merge: (video, audio, output) async {
      merges?.add(output);
      final bytes = [...await File(video).readAsBytes(), ...await File(audio).readAsBytes()];
      await File(output).writeAsBytes(bytes);
      return true;
    },
  );

  Future<DownloadEntry> startDownload(
    DownloadsProvider provider,
    DownloadOption option, {
    String title = 'Test video',
  }) => provider.start(videoId: 'abcdefghijk', title: title, channelName: 'Channel', thumbnailUrl: '', option: option);

  group('DownloadsProvider', () {
    test('downloads a single stream to completion', () async {
      final provider = makeProvider(FakeSource({18: List.generate(1000, (i) => i % 256)}));
      final entry = await startDownload(provider, muxed);
      await waitFor(() => entry.status == DownloadStatus.completed);
      expect(entry.progress, 1);
      expect(await File(entry.savedPath).length(), 1000);
      expect(entry.savedPath.endsWith('.mp4'), isTrue);
      expect(await File(entry.singlePartPath).exists(), isFalse);
    });

    test('merges separate video and audio streams', () async {
      final merges = <String>[];
      final provider = makeProvider(FakeSource({137: List.filled(600, 1), 140: List.filled(400, 2)}), merges: merges);
      final entry = await startDownload(provider, split);
      await waitFor(() => entry.status == DownloadStatus.completed);
      expect(merges, [entry.savedPath]);
      expect(await File(entry.savedPath).length(), 1000);
      expect(await File(entry.videoPartPath).exists(), isFalse);
      expect(await File(entry.audioPartPath).exists(), isFalse);
    });

    test('does not create duplicate entries for the same video and quality', () async {
      final provider = makeProvider(FakeSource({18: List.filled(100, 0)}));
      final first = await startDownload(provider, muxed);
      final second = await startDownload(provider, muxed);
      expect(identical(first, second), isTrue);
      expect(provider.items, hasLength(1));
      await waitFor(() => first.status == DownloadStatus.completed);
    });

    test('pause keeps partial data and resume continues from it', () async {
      final source = FakeSource({18: List.generate(1000, (i) => i % 256)})..gate = Completer<void>();
      final provider = makeProvider(source);
      final entry = await startDownload(provider, muxed);
      await waitFor(() => entry.receivedBytes == 500);
      await provider.pause(entry.id);
      expect(entry.status, DownloadStatus.paused);
      await waitFor(() => File(entry.singlePartPath).existsSync());

      source.gate = null;
      await provider.resume(entry.id);
      await waitFor(() => entry.status == DownloadStatus.completed);
      expect(source.opens.last.start, 500);
      expect(await File(entry.savedPath).readAsBytes(), List.generate(1000, (i) => i % 256));
    });

    test('cancel removes partial data', () async {
      final source = FakeSource({18: List.filled(1000, 7)})..gate = Completer<void>();
      final provider = makeProvider(source);
      final entry = await startDownload(provider, muxed);
      await waitFor(() => entry.receivedBytes == 500);
      await provider.cancel(entry.id);
      expect(entry.status, DownloadStatus.canceled);
      expect(await File(entry.singlePartPath).exists(), isFalse);
    });

    test('persists the list and restores interrupted downloads as paused', () async {
      final source = FakeSource({18: List.filled(1000, 7)})..gate = Completer<void>();
      final provider = makeProvider(source);
      final entry = await startDownload(provider, muxed);
      await waitFor(() => entry.receivedBytes == 500);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final reloaded = makeProvider(FakeSource({18: List.filled(1000, 7)}));
      await reloaded.load();
      expect(reloaded.items, hasLength(1));
      expect(reloaded.items.single.status, DownloadStatus.paused);
      expect(reloaded.items.single.title, 'Test video');
      await provider.cancel(entry.id);
    });

    test('marks completed downloads whose file is gone', () async {
      final provider = makeProvider(FakeSource({18: List.filled(100, 1)}));
      final entry = await startDownload(provider, muxed);
      await waitFor(() => entry.status == DownloadStatus.completed);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await File(entry.savedPath).delete();

      final reloaded = makeProvider(FakeSource({18: List.filled(100, 1)}));
      await reloaded.load();
      expect(reloaded.items.single.status, DownloadStatus.failed);
    });

    test('markFileRemoved flags the completed entry for a deleted file', () async {
      final provider = makeProvider(FakeSource({18: List.filled(100, 1)}));
      final entry = await startDownload(provider, muxed);
      await waitFor(() => entry.status == DownloadStatus.completed);
      await File(entry.savedPath).delete();
      provider.markFileRemoved(entry.savedPath);
      expect(entry.status, DownloadStatus.failed);
      expect(entry.error, 'File was removed from the device.');
    });

    test('remove with deleteFile deletes the file; without it keeps the file', () async {
      final provider = makeProvider(FakeSource({18: List.filled(100, 1)}));
      final entry = await startDownload(provider, muxed);
      await waitFor(() => entry.status == DownloadStatus.completed);

      await provider.remove(entry, deleteFile: false);
      expect(provider.items, isEmpty);
      expect(await File(entry.savedPath).exists(), isTrue);

      final again = await startDownload(provider, muxed);
      await waitFor(() => again.status == DownloadStatus.completed);
      expect(await provider.remove(again), isTrue);
      expect(await File(again.savedPath).exists(), isFalse);
    });

    test('never deletes files outside the managed downloads folder', () async {
      final provider = makeProvider(FakeSource({18: List.filled(10, 1)}));
      final outside = File('${root.path}/outside.mp4')..writeAsStringSync('keep me');
      final entry = DownloadEntry(
        id: 'x',
        videoId: 'abcdefghijk',
        title: 'x',
        channelName: '',
        thumbnailUrl: '',
        option: muxed,
        savedPath: outside.path,
      );
      expect(await provider.deleteFileFor(entry), isFalse);
      expect(await outside.exists(), isTrue);
    });

    test('selection helpers', () async {
      final provider = makeProvider(FakeSource({18: List.filled(10, 1), 22: List.filled(10, 1)}));
      final entry = await startDownload(provider, muxed);
      await startDownload(provider, muxed, title: 'other');
      expect(provider.items, hasLength(1));
      await waitFor(() => entry.status == DownloadStatus.completed);
      provider.selectAll();
      expect(provider.selectedIds, hasLength(1));
      provider.clearSelection();
      expect(provider.hasSelection, isFalse);
    });
  });

  group('helpers', () {
    test('safeFileName keeps Bangla and other Unicode text', () {
      expect(safeFileName('আমার সোনার বাংলা'), 'আমার সোনার বাংলা');
      expect(safeFileName('a/b:c*?"<>|d'), isNot(contains('/')));
      expect(safeFileName('   '), isNotEmpty);
    });

    test('extractVideoId handles common link formats', () {
      expect(YoutubeExtractionService.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(YoutubeExtractionService.extractVideoId('https://youtu.be/dQw4w9WgXcQ?t=10'), 'dQw4w9WgXcQ');
      expect(YoutubeExtractionService.extractVideoId('https://youtube.com/shorts/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(YoutubeExtractionService.extractVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(YoutubeExtractionService.extractVideoId('not a link'), isNull);
    });

    test('formatDuration', () {
      expect(YoutubeExtractionService.formatDuration(const Duration(minutes: 3, seconds: 5)), '03:05');
      expect(YoutubeExtractionService.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });

    test('sample videos have a playable URL', () {
      expect(Uri.parse(VideoModel.samplePlaybackUrl).isAbsolute, isTrue);
      expect(VideoModel.local(path: '/x/y.mp4', title: 'y').isLocal, isTrue);
    });

    test('ad blocker blocks ad hosts but not normal ones', () {
      final blocker = AdBlockerService();
      expect(blocker.isAdDomain('https://doubleclick.net/x'), isTrue);
      expect(blocker.isAdDomain('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isFalse);
      expect(blocker.isAdDomain('notaurl'), isFalse);
      expect(blocker.isAdDomain('https://www.youtube.com/api/stats/ads?ver=2'), isTrue);
      expect(blocker.isAdDomain('https://www.facebook.com/tr?id=1'), isTrue);
    });

    test('ad blocker avoids false positives', () {
      final blocker = AdBlockerService();
      expect(blocker.isAdDomain('https://yastatic.yandex.net/lib.js'), isFalse);
      expect(blocker.isAdDomain('https://segment.com/docs'), isFalse);
      expect(blocker.isAdDomain('https://example.com/blog/adsense-tips'), isFalse);
      expect(blocker.isAdDomain('https://example.com/trip?ref=facebook.com/tr'), isFalse);
      expect(blocker.shouldBlockRequest('https://example.com/analytics/report', 'GET'), isFalse);
      expect(blocker.shouldBlockRequest('https://example.com/metrics', 'GET'), isFalse);
      expect(blocker.shouldBlockRequest('https://github.com/issue-tracker', 'GET'), isFalse);
      expect(blocker.shouldBlockRequest('https://shop.example/pixel.gif?u=1', 'GET'), isTrue);
    });
  });

  group('theme', () {
    test('defaults to the device setting', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await ThemeController.load()).mode, ThemeMode.system);
    });

    test('remembers the chosen theme', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await ThemeController.load();
      await controller.setMode(ThemeMode.light);
      expect((await ThemeController.load()).mode, ThemeMode.light);
      await controller.toggle(Brightness.light);
      expect(controller.mode, ThemeMode.dark);
      expect((await ThemeController.load()).mode, ThemeMode.dark);
    });

    test('ignores an unknown saved value', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'purple'});
      expect((await ThemeController.load()).mode, ThemeMode.system);
    });

    test('light and dark themes have matching brightness', () {
      expect(AppTheme.lightTheme.colorScheme.brightness, Brightness.light);
      expect(AppTheme.darkTheme.colorScheme.brightness, Brightness.dark);
      expect(AppTheme.lightTheme.colorScheme.onSurface, isNot(AppTheme.darkTheme.colorScheme.onSurface));
    });

    testWidgets('theme menu switches the app between light and dark', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController(initial: ThemeMode.light);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: context.watch<ThemeController>().mode,
              home: Scaffold(appBar: AppBar(actions: const [ThemeModeButton()])),
            ),
          ),
        ),
      );
      BuildContext scaffold() => tester.element(find.byType(Scaffold));
      expect(Theme.of(scaffold()).brightness, Brightness.light);

      await tester.tap(find.byType(ThemeModeButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(controller.mode, ThemeMode.dark);
      expect(Theme.of(scaffold()).brightness, Brightness.dark);
    });
  });
}
