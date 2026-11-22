import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tube_arena/providers/downloads_provider.dart';
import 'package:tube_arena/services/youtube_extraction_service.dart';

class _ShortSource implements DownloadSource {
  @override
  Future<int> sizeOf(String videoId, int tag) async => 4;

  @override
  Future<SourceStream> open(String videoId, int tag, {int start = 0}) async {
    final bytes = [1, 2, 3, 4].skip(start).toList();
    return SourceStream(totalBytes: 4, bytes: Stream.value(bytes));
  }
}

const _video = DownloadOption(
  kind: DownloadKind.video,
  label: '360p',
  container: 'mp4',
  videoTag: 137,
  audioTag: 140,
  sizeBytes: 4,
);

const _audio = DownloadOption(
  kind: DownloadKind.audio,
  label: 'Audio',
  container: 'm4a',
  videoTag: null,
  audioTag: 140,
  sizeBytes: 4,
);

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory downloadsDirectory;
  late DownloadsProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('tube_arena_shorts');
    downloadsDirectory = Directory('${root.path}/TubeArena/Downloads');
    provider = DownloadsProvider(
      source: _ShortSource(),
      downloadsDirectoryResolver: () async => downloadsDirectory,
      merge: (video, audio, output) async {
        final videoBytes = await File(video).readAsBytes();
        final audioBytes = await File(audio).readAsBytes();
        await File(output).writeAsBytes([...videoBytes, ...audioBytes]);
        return true;
      },
    );
    await provider.load();
  });

  tearDown(() async {
    await provider.flushSaves();
    provider.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<DownloadEntry> start(String id, {bool isShort = false, DownloadOption option = _video}) => provider.start(
    videoId: id,
    title: 'Short $id',
    channelName: 'Channel',
    thumbnailUrl: '',
    option: option,
    isShort: isShort,
  );

  test('default Shorts limit is 1,000 and custom values persist', () async {
    expect(provider.shortsLimit, DownloadsProvider.defaultShortsLimit);
    await provider.setShortsLimit(12345);
    expect(provider.shortsLimit, 12345);
    final restored = DownloadsProvider(
      source: _ShortSource(),
      downloadsDirectoryResolver: () async => downloadsDirectory,
    );
    await restored.load();
    expect(restored.shortsLimit, 12345);
    await restored.setShortsLimit(null);
    expect(restored.shortsLimit, isNull);
    restored.dispose();

    final unlimited = DownloadsProvider(
      source: _ShortSource(),
      downloadsDirectoryResolver: () async => downloadsDirectory,
    );
    await unlimited.load();
    expect(unlimited.shortsLimit, isNull);
    unlimited.dispose();
  });

  test('video, audio, and Shorts are written to separate folders', () async {
    final regular = await start('regular');
    final audio = await start('audio', option: _audio);
    final short = await start('short', isShort: true);

    expect(regular.savedPath, contains('/Videos/'));
    expect(audio.savedPath, contains('/Audio/'));
    expect(short.savedPath, contains('/Shorts/'));
    expect(regular.audioPartPath, contains('/Audio/.'));
    expect(short.audioPartPath, contains('/Audio/.'));

    await _waitFor(() => [regular, audio, short].every((entry) => entry.status == DownloadStatus.completed));
  });

  test('oldest unprotected Short is replaced; protected Shorts are never evicted', () async {
    await provider.setShortsLimit(1);
    final first = await start('first', isShort: true);
    await _waitFor(() => first.status == DownloadStatus.completed);
    final originalPath = first.savedPath;

    await provider.setShortProtected(first.id, true);
    expect(first.isProtected, isTrue);
    expect(first.savedPath, contains('/Important Shorts/'));

    await expectLater(start('blocked', isShort: true), throwsA(isA<DownloadException>()));
    expect(await File(first.savedPath).exists(), isTrue);

    await provider.setShortProtected(first.id, false);
    expect(first.isProtected, isFalse);
    expect(first.savedPath, contains('/Shorts/'));
    final unprotectedPath = first.savedPath;

    final second = await start('second', isShort: true);
    expect(provider.byId(first.id), isNotNull, reason: 'The old Short stays safe until the replacement finishes.');
    await _waitFor(() => second.status == DownloadStatus.completed);
    await _waitFor(() => provider.byId(first.id) == null);
    expect(provider.byId(first.id), isNull);
    expect(await File(unprotectedPath).exists(), isFalse);
    expect(await File(originalPath).exists(), isFalse);
    expect(provider.downloadedShorts.map((entry) => entry.id), contains(second.id));
  });

  test('Shorts protection survives app restart', () async {
    final important = await start('keep', isShort: true);
    await _waitFor(() => important.status == DownloadStatus.completed);
    await provider.setShortProtected(important.id, true);
    await provider.flushSaves();

    final restored = DownloadsProvider(
      source: _ShortSource(),
      downloadsDirectoryResolver: () async => downloadsDirectory,
    );
    await restored.load();
    final saved = restored.byId(important.id);
    expect(saved, isNotNull);
    expect(saved!.isShort, isTrue);
    expect(saved.isProtected, isTrue);
    expect(saved.savedPath, contains('/Important Shorts/'));
    expect(await File(saved.savedPath).exists(), isTrue);
    restored.dispose();
  });

  test('unlimited disables count-based replacement', () async {
    await provider.setShortsLimit(null);
    final first = await start('one', isShort: true);
    await _waitFor(() => first.status == DownloadStatus.completed);
    final second = await start('two', isShort: true);
    await _waitFor(() => second.status == DownloadStatus.completed);
    expect(provider.downloadedShorts.length, 2);
    expect(await File(first.savedPath).exists(), isTrue);
  });
}
