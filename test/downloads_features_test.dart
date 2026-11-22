import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tube_arena/core/theme/app_theme.dart';
import 'package:tube_arena/providers/downloads_provider.dart';
import 'package:tube_arena/services/batch_download.dart';
import 'package:tube_arena/services/device_storage_service.dart';
import 'package:tube_arena/services/download_notification_service.dart';
import 'package:tube_arena/services/local_file_manager_service.dart';
import 'package:tube_arena/services/network_monitor.dart';
import 'package:tube_arena/services/youtube_extraction_service.dart';
import 'package:tube_arena/ui/screens/downloads_screen.dart';

class _Source implements DownloadSource {
  _Source(this.payloads);
  final Map<int, List<int>> payloads;
  final List<int> starts = [];
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<int> sizeOf(String videoId, int tag) async => payloads[tag]!.length;

  @override
  Future<SourceStream> open(String videoId, int tag, {int start = 0}) async {
    if (fail) throw Exception('network down');
    starts.add(start);
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

class _Network implements NetworkMonitor {
  _Network(this.onWifi);
  bool onWifi;
  final _controller = StreamController<bool>.broadcast();

  void set(bool value) {
    onWifi = value;
    _controller.add(value);
  }

  @override
  Future<bool> isOnWifi() async => onWifi;

  @override
  Stream<bool> get onWifiChanged => _controller.stream;
}

class _Notifier implements DownloadNotifier {
  final List<DownloadProgressInfo> progress = [];
  final List<({String title, bool success, String? message})> results = [];
  int stops = 0;

  @override
  Future<void> showProgress(DownloadProgressInfo info) async => progress.add(info);

  @override
  Future<void> stopProgress() async => stops++;

  @override
  Future<void> showResult({required String id, required String title, required bool success, String? message}) async =>
      results.add((title: title, success: success, message: message));
}

const _muxed = DownloadOption(
  kind: DownloadKind.video,
  label: '360p',
  container: 'mp4',
  videoTag: 18,
  audioTag: null,
  sizeBytes: 0,
);

Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

void main() {
  group('audio output options', () {
    test('format and quality survive persistence and have distinct task keys', () {
      const mp3 = DownloadOption(
        kind: DownloadKind.audio,
        label: 'MP3 · 320 kbps',
        container: 'mp3',
        videoTag: null,
        audioTag: 140,
        sizeBytes: 1200000,
        audioOutputBitrate: '320 kbps',
        audioSourceBitrateKbps: 128,
      );
      final restored = DownloadOption.fromJson(mp3.toJson());
      expect(restored.transcodesAudio, isTrue);
      expect(restored.container, 'mp3');
      expect(restored.audioOutputBitrate, '320 kbps');
      expect(restored.audioSourceBitrateKbps, 128);
      expect(restored.key, mp3.key);

      const m4a = DownloadOption(
        kind: DownloadKind.audio,
        label: 'M4A · Best available',
        container: 'm4a',
        videoTag: null,
        audioTag: 140,
        sizeBytes: 1200000,
        audioOutputBitrate: 'Best available',
        audioSourceBitrateKbps: 128,
      );
      expect(m4a.key, isNot(mp3.key));
    });
  });

  late Directory root;
  late Directory tubeArena;
  late Directory downloads;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('tube_arena_features');
    tubeArena = Directory('${root.path}/TubeArena');
    downloads = Directory('${tubeArena.path}/Downloads');
  });

  final created = <DownloadsProvider>[];

  tearDown(() async {
    for (final provider in created) {
      await provider.flushSaves();
    }
    created.clear();
    // A download task may still be finishing a write; retry briefly.
    for (var attempt = 0; attempt < 20 && await root.exists(); attempt++) {
      try {
        await root.delete(recursive: true);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  DownloadsProvider makeProvider(_Source source, {FreeSpaceResolver? freeSpace, NetworkMonitor? network}) {
    final provider = DownloadsProvider(
      source: source,
      downloadsDirectoryResolver: () async => downloads,
      freeSpace: freeSpace,
      network: network,
      merge: (video, audio, output) async {
        await File(output).writeAsBytes([...await File(video).readAsBytes(), ...await File(audio).readAsBytes()]);
        return true;
      },
    );
    created.add(provider);
    return provider;
  }

  Future<DownloadEntry> start(DownloadsProvider provider, {DownloadOption option = _muxed, String title = 'Video'}) =>
      provider.start(videoId: 'abcdefghijk', title: title, channelName: 'Channel', thumbnailUrl: '', option: option);

  group('move to folder', () {
    test('moved downloads stay in sync and can still be deleted from Downloads', () async {
      final files = LocalFileManagerService.withBaseDirectory(tubeArena);
      final provider = makeProvider(_Source({18: List.filled(100, 1)}));
      final entry = await start(provider);
      await _waitFor(() => entry.status == DownloadStatus.completed);

      final oldPath = entry.savedPath;
      final newPath = await files.moveFileTo(oldPath, 'Music videos');
      expect(newPath, isNotNull);
      expect(newPath, endsWith('/Music videos/${oldPath.split('/').last}'));
      expect(await File(oldPath).exists(), isFalse);
      provider.updatePath(oldPath, newPath!);
      expect(entry.savedPath, newPath);
      expect((await files.getFilesInFolder('Music videos')).single.path, newPath);

      expect(await provider.remove(entry), isTrue);
      expect(await File(newPath).exists(), isFalse);
    });

    test('updatePath is persisted', () async {
      final files = LocalFileManagerService.withBaseDirectory(tubeArena);
      final provider = makeProvider(_Source({18: List.filled(100, 1)}));
      final entry = await start(provider);
      await _waitFor(() => entry.status == DownloadStatus.completed);
      final newPath = (await files.moveFileTo(entry.savedPath, 'Keep'))!;
      provider.updatePath(entry.savedPath, newPath);
      await provider.flushSaves();

      final reloaded = makeProvider(_Source({18: List.filled(100, 1)}));
      await reloaded.load();
      expect(reloaded.items.single.savedPath, newPath);
      expect(reloaded.items.single.status, DownloadStatus.completed);
    });

    test('updatePath restores an entry that was marked missing', () async {
      final provider = makeProvider(_Source({18: List.filled(10, 1)}));
      final entry = await start(provider);
      await _waitFor(() => entry.status == DownloadStatus.completed);
      final moved = File('${tubeArena.path}/Other/x.mp4');
      await moved.parent.create(recursive: true);
      await File(entry.savedPath).rename(moved.path);
      provider.markFileRemoved(entry.savedPath);
      expect(entry.status, DownloadStatus.failed);
      provider.updatePath(entry.savedPath, moved.path);
      expect(entry.status, DownloadStatus.completed);
      expect(entry.error, isNull);
    });

    test('moveFileTo renames on collision and refuses files outside the library', () async {
      final files = LocalFileManagerService.withBaseDirectory(tubeArena);
      await files.initialize();
      await Directory('${tubeArena.path}/Target').create(recursive: true);
      File('${tubeArena.path}/Target/a.mp4').writeAsStringSync('existing');
      final source = File('${downloads.path}/a.mp4')..writeAsStringSync('new');
      final moved = await files.moveFileTo(source.path, 'Target');
      expect(moved, endsWith('/Target/a (2).mp4'));
      expect(File(moved!).readAsStringSync(), 'new');

      expect(await files.moveFileTo(moved, 'Target'), isNull, reason: 'already in that folder');
      final outside = File('${root.path}/outside.mp4')..writeAsStringSync('x');
      expect(await files.moveFileTo(outside.path, 'Target'), isNull);
      expect(await files.moveFileTo(moved, '../escape'), isNull);
      expect(await outside.exists(), isTrue);
    });
  });

  group('free space', () {
    test('estimate counts source, merged output, transcode output, and reserve once', () {
      expect(estimateRequiredBytes(0, needsMerge: true), 0);
      expect(estimateRequiredBytes(100, needsMerge: false), 100 + downloadSpaceReserve);
      expect(estimateRequiredBytes(100, needsMerge: true), 200 + downloadSpaceReserve);
      expect(
        estimateRequiredBytes(100, needsMerge: false, estimatedOutputBytes: 1600),
        1700 + downloadSpaceReserve,
      );
    });

    test('audio output estimates reflect selected formats without double counting', () {
      const wav = DownloadOption(
        kind: DownloadKind.audio,
        label: 'WAV · Lossless',
        container: 'wav',
        videoTag: null,
        audioTag: 140,
        sizeBytes: 100,
        audioOutputBitrate: 'Lossless',
        audioSourceBitrateKbps: 128,
      );
      const mp3 = DownloadOption(
        kind: DownloadKind.audio,
        label: 'MP3 · 256 kbps',
        container: 'mp3',
        videoTag: null,
        audioTag: 140,
        sizeBytes: 100,
        audioOutputBitrate: '256 kbps',
        audioSourceBitrateKbps: 128,
      );
      expect(estimateAudioOutputBytes(wav), 1600);
      expect(estimateAudioOutputBytes(mp3), 200);
    });

    test('refuses to start when the option clearly does not fit', () async {
      const mb = 1024 * 1024;
      final provider = makeProvider(_Source({18: List.filled(10, 1)}), freeSpace: (_) async => 150 * mb);
      const big = DownloadOption(
        kind: DownloadKind.video,
        label: '1080p',
        container: 'mp4',
        videoTag: 137,
        audioTag: 140,
        sizeBytes: 100 * mb,
      );
      await expectLater(
        start(provider, option: big),
        throwsA(isA<DownloadException>().having((e) => e.message, 'message', contains('Not enough storage'))),
      );
      expect(provider.items, isEmpty);
    });

    test('fails the download when real stream sizes do not fit', () async {
      final provider = makeProvider(_Source({18: List.filled(1000, 1)}), freeSpace: (_) async => 1000);
      final entry = await start(provider);
      await _waitFor(() => entry.status == DownloadStatus.failed);
      expect(entry.error, contains('Not enough storage'));
    });

    test('unknown free space never blocks', () async {
      final provider = makeProvider(_Source({18: List.filled(100, 1)}), freeSpace: (_) async => null);
      final entry = await start(provider);
      await _waitFor(() => entry.status == DownloadStatus.completed);
    });
  });

  group('Wi-Fi only', () {
    test('queued downloads wait for Wi-Fi and start when it returns', () async {
      final network = _Network(false);
      final provider = makeProvider(_Source({18: List.filled(100, 1)}), network: network);
      await provider.load();
      await provider.setWifiOnly(true);
      final entry = await start(provider);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(entry.status, DownloadStatus.queued);
      expect(provider.waitingForWifi, isTrue);

      network.set(true);
      await _waitFor(() => entry.status == DownloadStatus.completed);
      expect(provider.waitingForWifi, isFalse);
    });

    test('losing Wi-Fi requeues a running download, which resumes from saved bytes', () async {
      final network = _Network(true);
      final source = _Source({18: List.generate(1000, (i) => i % 256)})..gate = Completer<void>();
      final provider = makeProvider(source, network: network);
      await provider.load();
      await provider.setWifiOnly(true);
      final entry = await start(provider);
      await _waitFor(() => entry.receivedBytes == 500);

      network.set(false);
      await _waitFor(() => entry.status == DownloadStatus.queued);
      source.gate = null;
      network.set(true);
      await _waitFor(() => entry.status == DownloadStatus.completed);
      expect(source.starts.last, 500);
      expect(await File(entry.savedPath).readAsBytes(), List.generate(1000, (i) => i % 256));
    });

    test('turning the setting off releases waiting downloads', () async {
      final provider = makeProvider(_Source({18: List.filled(100, 1)}), network: _Network(false));
      await provider.setWifiOnly(true);
      final entry = await start(provider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(entry.status, DownloadStatus.queued);
      await provider.setWifiOnly(false);
      await _waitFor(() => entry.status == DownloadStatus.completed);
    });

    test('the setting is remembered', () async {
      final provider = makeProvider(
        _Source({
          18: [1],
        }),
      );
      await provider.setWifiOnly(true);
      final reloaded = makeProvider(
        _Source({
          18: [1],
        }),
      );
      await reloaded.load();
      expect(reloaded.wifiOnly, isTrue);
    });

    testWidgets('Downloads screen menu toggles Wi-Fi only', (tester) async {
      final provider = DownloadsProvider(downloadsDirectoryResolver: () async => Directory.systemTemp);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(theme: AppTheme.lightTheme, home: const DownloadsScreen()),
        ),
      );
      await tester.tap(find.byTooltip('Download settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download on Wi-Fi only'));
      await tester.pumpAndSettle();
      expect(provider.wifiOnly, isTrue);
    });
  });

  group('notifications', () {
    test('shows progress while downloading, then a completion notice', () async {
      final notifier = _Notifier();
      final source = _Source({18: List.filled(1000, 1)})..gate = Completer<void>();
      final provider = makeProvider(source);
      final controller = DownloadNotificationController(provider, notifier, minInterval: Duration.zero);
      final entry = await start(provider, title: 'My video');
      await _waitFor(() => entry.receivedBytes == 500);
      expect(notifier.progress.last.title, 'My video');
      expect(notifier.progress.last.percent, 50);

      source.gate!.complete();
      await _waitFor(() => entry.status == DownloadStatus.completed);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.results.single.success, isTrue);
      expect(notifier.results.single.title, 'My video');
      expect(notifier.stops, 1);
      controller.dispose();
    });

    test('reports failures', () async {
      final notifier = _Notifier();
      final provider = makeProvider(_Source({18: List.filled(10, 1)})..fail = true);
      final controller = DownloadNotificationController(provider, notifier);
      final entry = await start(provider);
      await _waitFor(() => entry.status == DownloadStatus.failed);
      expect(notifier.results.single.success, isFalse);
      expect(notifier.stops, 1);
      controller.dispose();
    });

    test('progressInfo summarises several downloads', () {
      DownloadEntry entry(String id, DownloadStatus status, int got, int total) => DownloadEntry(
        id: id,
        videoId: id,
        title: id,
        channelName: '',
        thumbnailUrl: '',
        option: _muxed,
        savedPath: '/x/$id.mp4',
        status: status,
        receivedBytes: got,
        totalBytes: total,
      );
      expect(DownloadNotificationController.progressInfo([entry('a', DownloadStatus.completed, 1, 1)]), isNull);
      final info = DownloadNotificationController.progressInfo([
        entry('a', DownloadStatus.downloading, 25, 100),
        entry('b', DownloadStatus.queued, 0, 100),
      ])!;
      expect(info.title, 'Downloading 2 files');
      expect(info.percent, 12);
      final waiting = DownloadNotificationController.progressInfo([
        entry('a', DownloadStatus.queued, 0, 100),
      ], waitingForWifi: true)!;
      expect(waiting.text, 'Waiting for Wi-Fi');
      expect(waiting.percent, -1);

      const audioOption = DownloadOption(
        kind: DownloadKind.audio,
        label: 'MP3 · 192 kbps',
        container: 'mp3',
        videoTag: null,
        audioTag: 140,
        sizeBytes: 100,
        audioOutputBitrate: '192 kbps',
        audioSourceBitrateKbps: 128,
      );
      final converting = DownloadEntry(
        id: 'audio',
        videoId: 'audio',
        title: 'Audio',
        channelName: '',
        thumbnailUrl: '',
        option: audioOption,
        savedPath: '/x/audio.mp3',
        status: DownloadStatus.merging,
      );
      expect(
        DownloadNotificationController.progressInfo([converting])!.text,
        'Converting audio format...',
      );
      final mergingVideo = DownloadEntry(
        id: 'video',
        videoId: 'video',
        title: 'Video',
        channelName: '',
        thumbnailUrl: '',
        option: _muxed,
        savedPath: '/x/video.mp4',
        status: DownloadStatus.merging,
      );
      expect(
        DownloadNotificationController.progressInfo([mergingVideo])!.text,
        'Combining video and audio...',
      );
    });
  });

  group('batch download', () {
    test('concurrent starts with the same title get distinct files', () async {
      final provider = makeProvider(_Source({18: List.filled(10, 1)}));
      final entries = await Future.wait([
        for (var i = 0; i < 3; i++)
          provider.start(videoId: 'video$i', title: 'Same', channelName: '', thumbnailUrl: '', option: _muxed),
      ]);
      expect(entries.map((e) => e.savedPath).toSet(), hasLength(3));
      await _waitFor(() => entries.every((e) => e.status == DownloadStatus.completed));
    });

    test('runs with limited concurrency and collects failures', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final progress = <int>[];
      final result = await runBatch<int>(List.generate(10, (i) => i), (i) async {
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        inFlight--;
        if (i.isOdd) throw const YoutubeServiceException('Video unavailable');
      }, onProgress: (done, total) => progress.add(done));
      expect(maxInFlight, 3);
      expect(progress.first, 0);
      expect(progress.last, 10);
      expect(result.succeeded, 5);
      expect(result.failures.map((f) => f.item), unorderedEquals([1, 3, 5, 7, 9]));
      expect(result.failures.first.reason, 'Video unavailable');

      final summary = batchSummary<int>(result, (i) => 'Video $i', skipped: 1);
      expect(summary, startsWith('Started 5 download(s). 5 failed: '));
      expect(summary, contains('and 3 more'));
      expect(summary, endsWith('1 sample video(s) skipped.'));
    });

    test('progress label', () {
      expect(batchProgressLabel(0, 10), 'Preparing 1 of 10');
      expect(batchProgressLabel(2, 10), 'Preparing 3 of 10');
      expect(batchProgressLabel(10, 10), 'Preparing 10 of 10');
    });

    test('empty batch', () async {
      final result = await runBatch<int>([], (_) async {});
      expect(result.succeeded, 0);
      expect(result.failures, isEmpty);
    });
  });

  group('save to phone helpers', () {
    test('MIME types and audio detection', () {
      expect(isAudioFile('/a/b/song.m4a'), isTrue);
      expect(isAudioFile('/a/b/song.weba'), isTrue);
      expect(isAudioFile('/a/b/clip.mp4'), isFalse);
      expect(mimeTypeFor('song.weba'), 'audio/webm');
      expect(mimeTypeFor('clip.mp4'), 'video/mp4');
      expect(mimeTypeFor('clip.mkv'), 'video/x-matroska');
      expect(mimeTypeFor('song.m4a'), 'audio/mp4');
      expect(mimeTypeFor('song.webm', audio: true), 'audio/webm');
      expect(mimeTypeFor('clip.webm'), 'video/webm');
      expect(savedToPhoneMessage(PublicCollection.music), contains('Music/Tube Arena'));
    });

    test('isUnmetered', () {
      expect(isUnmetered(const []), isFalse);
    });
  });
}
