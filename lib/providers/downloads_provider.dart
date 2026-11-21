import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ffmpeg_merge_service.dart';
import '../services/network_monitor.dart';
import '../services/youtube_extraction_service.dart';

enum DownloadStatus { queued, downloading, paused, merging, completed, failed, canceled }

/// One download in the Downloads list. Persisted to `downloads.json`.
class DownloadEntry {
  DownloadEntry({
    required this.id,
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.option,
    required this.savedPath,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String videoId;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final DownloadOption option;

  /// Final file path. Only exists on disk once [status] is completed. Changes
  /// when the file is moved to another Library folder.
  String savedPath;
  final DateTime createdAt;

  DownloadStatus status;
  int receivedBytes;
  int totalBytes;
  String? error;

  double get progress => totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1).toDouble();
  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading || status == DownloadStatus.merging;
  bool get canResume =>
      status == DownloadStatus.paused || status == DownloadStatus.failed || status == DownloadStatus.canceled;

  String get videoPartPath => '$savedPath.video.part';
  String get audioPartPath => '$savedPath.audio.part';
  String get singlePartPath => '$savedPath.part';
  List<String> get partPaths => [videoPartPath, audioPartPath, singlePartPath];

  Map<String, dynamic> toJson() => {
    'id': id,
    'videoId': videoId,
    'title': title,
    'channelName': channelName,
    'thumbnailUrl': thumbnailUrl,
    'option': option.toJson(),
    'savedPath': savedPath,
    'status': status.name,
    'receivedBytes': receivedBytes,
    'totalBytes': totalBytes,
    'error': error,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
    id: json['id'] as String,
    videoId: json['videoId'] as String,
    title: json['title'] as String,
    channelName: json['channelName'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    option: DownloadOption.fromJson(Map<String, dynamic>.from(json['option'] as Map)),
    savedPath: json['savedPath'] as String,
    status: DownloadStatus.values.asNameMap()[json['status']] ?? DownloadStatus.failed,
    receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
    totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
    error: json['error'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

/// A ranged byte stream for one YouTube stream (itag).
class SourceStream {
  const SourceStream({required this.totalBytes, required this.bytes});
  final int totalBytes;
  final Stream<List<int>> bytes;
}

/// Where download bytes come from. Abstracted so tests can use fake data.
abstract class DownloadSource {
  Future<int> sizeOf(String videoId, int tag);
  Future<SourceStream> open(String videoId, int tag, {int start = 0});
}

class YoutubeDownloadSource implements DownloadSource {
  YoutubeDownloadSource(this._youtube);
  final YoutubeExtractionService _youtube;

  @override
  Future<int> sizeOf(String videoId, int tag) async => (await _youtube.streamForTag(videoId, tag)).size.totalBytes;

  @override
  Future<SourceStream> open(String videoId, int tag, {int start = 0}) async {
    final info = await _youtube.streamForTag(videoId, tag);
    return SourceStream(
      totalBytes: info.size.totalBytes,
      bytes: _youtube.openStream(info, start: start),
    );
  }
}

typedef MergeFunction = Future<bool> Function(String videoPath, String audioPath, String outputPath);

/// Returns the free bytes on the volume holding [path], or null when unknown.
typedef FreeSpaceResolver = Future<int?> Function(String path);

/// A download could not be started. [message] is safe to show to users.
class DownloadException implements Exception {
  const DownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _Cancelled implements Exception {}

/// Bytes kept free on top of the download itself, so the phone never fills up.
const downloadSpaceReserve = 50 * 1024 * 1024;

/// Bytes needed on disk to download [streamBytes]. Merged downloads need room
/// for the parts and the combined file at the same time.
int estimateRequiredBytes(int streamBytes, {required bool needsMerge}) =>
    streamBytes <= 0 ? 0 : (needsMerge ? streamBytes * 2 : streamBytes) + downloadSpaceReserve;

String formatByteCount(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value >= 10 || unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} ${units[unit]}';
}

/// Owns the download queue: start, progress, pause/resume, retry, cancel,
/// merge, persistence and deletion. Downloads run while the app process is
/// alive; anything interrupted is shown as paused and resumes from the bytes
/// already on disk.
class DownloadsProvider extends ChangeNotifier {
  DownloadsProvider({
    DownloadSource? source,
    MergeFunction? merge,
    Future<Directory> Function()? downloadsDirectoryResolver,
    FreeSpaceResolver? freeSpace,
    NetworkMonitor? network,
    this.maxConcurrent = 2,
  }) : _source = source,
       _merge =
           merge ?? ((v, a, o) => FFmpegMergeService().mergeVideoAndAudio(videoPath: v, audioPath: a, outputPath: o)),
       _downloadsDirectoryResolver = downloadsDirectoryResolver ?? defaultDownloadsDirectory,
       _freeSpace = freeSpace,
       _network = network {
    _networkSubscription = network?.onWifiChanged.listen(_onWifiChanged);
  }

  static const wifiOnlyPreferenceKey = 'download_wifi_only';

  static Future<Directory> defaultDownloadsDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/TubeArena/Downloads');
  }

  DownloadSource? _source;
  final MergeFunction _merge;
  final Future<Directory> Function() _downloadsDirectoryResolver;
  final FreeSpaceResolver? _freeSpace;
  final NetworkMonitor? _network;
  StreamSubscription<bool>? _networkSubscription;
  final int maxConcurrent;

  bool _wifiOnly = false;
  bool? _onWifi;

  final List<DownloadEntry> _items = [];
  final Set<String> _selectedIds = {};
  final Map<String, StreamSubscription<List<int>>> _subscriptions = {};
  final Set<String> _running = {};
  final Set<String> _stopRequested = {};
  final Map<String, Completer<void>> _finished = {};
  bool _loaded = false;
  Future<void>? _loading;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  set source(DownloadSource value) => _source = value;

  /// When true, downloads only run on Wi-Fi (or another unmetered network).
  bool get wifiOnly => _wifiOnly;

  /// True when queued downloads are held back until Wi-Fi is available.
  bool get waitingForWifi => _wifiOnly && _onWifi == false;

  Future<void> setWifiOnly(bool value) async {
    if (_wifiOnly == value) return;
    _wifiOnly = value;
    if (value) await _refreshWifi();
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(wifiOnlyPreferenceKey, value);
    } catch (error) {
      debugPrint('Could not save the Wi-Fi setting: $error');
    }
    if (waitingForWifi) {
      await _holdForWifi();
    } else {
      _pump();
    }
  }

  Future<void> _refreshWifi() async {
    final network = _network;
    if (network == null) return;
    try {
      _onWifi = await network.isOnWifi();
    } catch (_) {
      _onWifi = null;
    }
  }

  Future<void> _onWifiChanged(bool onWifi) async {
    if (_onWifi == onWifi) return;
    _onWifi = onWifi;
    notifyListeners();
    if (waitingForWifi) {
      await _holdForWifi();
    } else {
      _pump();
    }
  }

  // Wi-Fi was lost: running downloads go back to the queue and continue from
  // the bytes already saved once Wi-Fi returns.
  Future<void> _holdForWifi() async {
    for (final entry in _items.where((e) => e.status == DownloadStatus.downloading).toList()) {
      await _stop(entry, DownloadStatus.queued);
    }
  }

  List<DownloadEntry> get items => List.unmodifiable(_items);
  List<String> get selectedIds => List.unmodifiable(_selectedIds.toList());
  bool get hasSelection => _selectedIds.isNotEmpty;
  bool isSelected(String id) => _selectedIds.contains(id);

  DownloadEntry? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  // ------------------------------------------------------------ persistence

  Future<File> _stateFile() async {
    final dir = await _downloadsDirectoryResolver();
    return File('${dir.parent.path}/downloads.json');
  }

  /// Loads the saved list. Downloads interrupted by the app closing are
  /// marked paused so the user can resume them.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _wifiOnly = prefs.getBool(wifiOnlyPreferenceKey) ?? _wifiOnly;
    } catch (error) {
      debugPrint('Could not read download settings: $error');
    }
    await _refreshWifi();
    try {
      final file = await _stateFile();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          for (final raw in decoded) {
            try {
              final entry = DownloadEntry.fromJson(Map<String, dynamic>.from(raw as Map));
              if (entry.isActive) entry.status = DownloadStatus.paused;
              if (entry.status == DownloadStatus.completed && !await File(entry.savedPath).exists()) {
                entry
                  ..status = DownloadStatus.failed
                  ..error = 'File was removed from the device.';
              }
              if (_items.every((e) => e.id != entry.id)) _items.add(entry);
            } catch (error) {
              debugPrint('Skipping unreadable download record: $error');
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Could not load downloads: $error');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _saveChain = Future<void>.value();

  // Saves run one at a time so concurrent writes never race on the temp file.
  Future<void> _save() => _saveChain = _saveChain.then((_) => _writeState());

  Future<void> _writeState() async {
    try {
      final file = await _stateFile();
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(_items.map((e) => e.toJson()).toList()));
      await tmp.rename(file.path);
    } catch (error) {
      debugPrint('Could not save downloads: $error');
    }
  }

  void _changed({bool persist = true, bool throttle = false}) {
    if (throttle) {
      final now = DateTime.now();
      if (now.difference(_lastNotify) < const Duration(milliseconds: 250)) return;
      _lastNotify = now;
    }
    notifyListeners();
    if (persist) unawaited(_save());
  }

  // ---------------------------------------------------------------- actions

  /// Queues a download. Returns the existing entry instead of duplicating
  /// one that is already downloading or finished.
  Future<DownloadEntry> start({
    required String videoId,
    required String title,
    required String channelName,
    required String thumbnailUrl,
    required DownloadOption option,
  }) async {
    if (!_loaded) await load();
    final id = '$videoId-${option.key}';
    final existing = byId(id);
    if (existing != null) {
      if (existing.canResume) await resume(existing.id);
      return existing;
    }
    final directory = await _downloadsDirectoryResolver();
    await directory.create(recursive: true);
    await _ensureSpace(directory.path, option.sizeBytes, needsMerge: option.needsMerge);
    // Another start() for the same item may have finished while we awaited.
    final raced = byId(id);
    if (raced != null) return raced;
    // From here on everything is synchronous, so concurrent starts (batch
    // downloads) can never pick the same file name.
    final entry = DownloadEntry(
      id: id,
      videoId: videoId,
      title: title,
      channelName: channelName,
      thumbnailUrl: thumbnailUrl,
      option: option,
      savedPath: _uniquePath(directory, '${safeFileName(title)} (${option.label})', option.extension),
      totalBytes: option.sizeBytes,
    );
    _items.insert(0, entry);
    _changed();
    _pump();
    return entry;
  }

  /// Throws a [DownloadException] when the device clearly lacks room for
  /// [streamBytes]. Unknown sizes or free space never block a download.
  Future<void> _ensureSpace(String directory, int streamBytes, {required bool needsMerge}) async {
    final resolver = _freeSpace;
    final needed = estimateRequiredBytes(streamBytes, needsMerge: needsMerge);
    if (resolver == null || needed <= 0) return;
    int? free;
    try {
      free = await resolver(directory);
    } catch (_) {
      free = null;
    }
    if (free != null && free < needed) {
      throw DownloadException(
        'Not enough storage. This download needs about ${formatByteCount(needed)} '
        'but only ${formatByteCount(free)} is free.',
      );
    }
  }

  /// Keeps a download record in sync after its file was moved inside the
  /// Library. A record that was marked missing is restored when the file exists.
  void updatePath(String oldPath, String newPath) {
    var changed = false;
    for (final entry in _items) {
      if (entry.savedPath != oldPath) continue;
      entry.savedPath = newPath;
      if (entry.status == DownloadStatus.failed && entry.error == 'File was removed from the device.') {
        if (File(newPath).existsSync()) {
          entry
            ..status = DownloadStatus.completed
            ..error = null;
        }
      }
      changed = true;
    }
    if (changed) _changed();
  }

  Future<void> pause(String id) async {
    final entry = byId(id);
    if (entry == null || !entry.isActive || entry.status == DownloadStatus.merging) return;
    await _stop(entry, DownloadStatus.paused);
  }

  Future<void> resume(String id) async {
    final entry = byId(id);
    if (entry == null || !entry.canResume) return;
    entry
      ..status = DownloadStatus.queued
      ..error = null;
    _changed();
    _pump();
  }

  Future<void> retry(String id) => resume(id);

  /// Stops the download and deletes partial data. The record stays so it can
  /// be restarted or removed.
  Future<void> cancel(String id) async {
    final entry = byId(id);
    if (entry == null) return;
    await _stop(entry, DownloadStatus.canceled);
    await _deleteParts(entry);
    entry.receivedBytes = 0;
    _changed();
  }

  Future<void> _stop(DownloadEntry entry, DownloadStatus status) async {
    if (_running.contains(entry.id)) {
      _stopRequested.add(entry.id);
      // Never await cancel(): on a stalled connection it may not return.
      unawaited(_subscriptions.remove(entry.id)?.cancel());
      entry.status = status;
      _changed();
      // Wait for the worker to close its file before the caller touches it.
      await _finished[entry.id]?.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    }
    entry.status = status;
    _changed();
  }

  // ------------------------------------------------------------- execution

  void _pump() {
    if (_source == null || waitingForWifi) return;
    for (final entry in _items.reversed) {
      if (_running.length >= maxConcurrent) break;
      if (entry.status == DownloadStatus.queued && !_running.contains(entry.id)) {
        unawaited(_run(entry));
      }
    }
  }

  Future<void> _run(DownloadEntry entry) async {
    final source = _source!;
    _running.add(entry.id);
    _stopRequested.remove(entry.id);
    final finished = _finished[entry.id] = Completer<void>();
    entry
      ..status = DownloadStatus.downloading
      ..error = null;
    _changed();
    try {
      final option = entry.option;
      final parts = <({int tag, String path})>[
        if (option.needsMerge) ...[
          (tag: option.videoTag!, path: entry.videoPartPath),
          (tag: option.audioTag!, path: entry.audioPartPath),
        ] else
          (tag: (option.videoTag ?? option.audioTag)!, path: entry.singlePartPath),
      ];

      // Real sizes from a fresh manifest, so progress is accurate.
      final sizes = <int>[];
      for (final part in parts) {
        sizes.add(await source.sizeOf(entry.videoId, part.tag));
      }
      final total = sizes.fold<int>(0, (a, b) => a + b);
      if (total > 0) entry.totalBytes = total;
      if (entry.receivedBytes == 0) {
        await _ensureSpace(File(entry.savedPath).parent.path, total, needsMerge: option.needsMerge);
      }

      var doneBefore = 0;
      for (var i = 0; i < parts.length; i++) {
        await _downloadPart(entry, parts[i].tag, parts[i].path, sizes[i], doneBefore);
        doneBefore += sizes[i];
      }

      if (option.needsMerge) {
        entry.status = DownloadStatus.merging;
        _changed();
        final ok = await _merge(entry.videoPartPath, entry.audioPartPath, entry.savedPath);
        if (!ok) throw Exception('Could not combine video and audio.');
        await _deleteParts(entry);
      } else {
        final out = File(entry.savedPath);
        if (await out.exists()) await out.delete();
        await File(entry.singlePartPath).rename(entry.savedPath);
      }
      entry
        ..status = DownloadStatus.completed
        ..receivedBytes = entry.totalBytes;
    } on _Cancelled {
      // Status was already set by pause()/cancel().
    } catch (error) {
      if (!_stopRequested.contains(entry.id)) {
        entry
          ..status = DownloadStatus.failed
          ..error = switch (error) {
            YoutubeServiceException(:final message) => message,
            DownloadException(:final message) => message,
            _ => 'Download failed. Tap retry.',
          };
        debugPrint('Download ${entry.id} failed: $error');
      }
    } finally {
      _running.remove(entry.id);
      _stopRequested.remove(entry.id);
      _subscriptions.remove(entry.id);
      if (identical(_finished[entry.id], finished)) _finished.remove(entry.id);
      finished.complete();
      _changed();
      _pump();
    }
  }

  Future<void> _downloadPart(DownloadEntry entry, int tag, String path, int size, int doneBefore) async {
    final file = File(path);
    var have = await file.exists() ? await file.length() : 0;
    if (size > 0 && have > size) {
      await file.delete();
      have = 0;
    }
    entry.receivedBytes = doneBefore + have;
    if (size > 0 && have == size) return;
    if (_stopRequested.contains(entry.id)) throw _Cancelled();

    final stream = await _source!.open(entry.videoId, tag, start: have);
    final sink = file.openWrite(mode: FileMode.append);
    final completer = Completer<void>();
    final subscription = stream.bytes.listen(
      (chunk) {
        sink.add(chunk);
        have += chunk.length;
        entry.receivedBytes = doneBefore + have;
        _changed(persist: false, throttle: true);
      },
      onError: (Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );
    _subscriptions[entry.id] = subscription;
    try {
      // cancel() on the subscription never calls onDone, so also watch for stop requests.
      while (!completer.isCompleted) {
        if (_stopRequested.contains(entry.id)) {
          unawaited(subscription.cancel());
          throw _Cancelled();
        }
        await Future.any([completer.future, Future<void>.delayed(const Duration(milliseconds: 200))]);
      }
      await completer.future;
    } finally {
      await sink.flush();
      await sink.close();
    }
    final expected = size > 0 ? size : stream.totalBytes;
    if (expected > 0 && have < expected) throw Exception('Connection lost before the download finished.');
  }

  // ------------------------------------------------------------- selection

  void toggleSelection(String id) {
    if (byId(id) == null) return;
    if (!_selectedIds.add(id)) _selectedIds.remove(id);
    notifyListeners();
  }

  void selectAll() {
    _selectedIds
      ..clear()
      ..addAll(_items.map((e) => e.id));
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }

  /// Removes selected records without deleting their files.
  void removeSelected() {
    for (final id in _selectedIds.toList()) {
      final entry = byId(id);
      if (entry != null && entry.isActive) unawaited(cancel(id));
    }
    _items.removeWhere((item) => _selectedIds.contains(item.id));
    _selectedIds.clear();
    _changed();
  }

  /// Removes a record from the list. With [deleteFile], also deletes its file
  /// (only inside the managed downloads folder) and any partial data. The
  /// record is removed even when there is no file left to delete.
  Future<bool> remove(DownloadEntry item, {bool deleteFile = true}) async {
    if (item.isActive) await _stop(item, DownloadStatus.canceled);
    var fileDeleted = false;
    if (deleteFile) {
      await _deleteParts(item);
      fileDeleted = await _deleteManaged(item.savedPath);
    }
    _items.removeWhere((entry) => entry.id == item.id);
    _selectedIds.remove(item.id);
    _changed();
    return fileDeleted;
  }

  /// Called when a file was deleted outside this screen (e.g. from the
  /// Library), so the entry no longer claims to be a completed download.
  void markFileRemoved(String path) {
    var changed = false;
    for (final entry in _items) {
      if (entry.status == DownloadStatus.completed && entry.savedPath == path) {
        entry
          ..status = DownloadStatus.failed
          ..error = 'File was removed from the device.';
        changed = true;
      }
    }
    if (changed) _changed();
  }

  /// Back-compat: deletes the file and record. Returns false if the file is
  /// outside the managed folder (in which case nothing is removed).
  Future<bool> deleteFileFor(DownloadEntry item) async {
    final path = item.savedPath.trim();
    if (path.isEmpty) return false;
    final file = File(path);
    if (await file.exists() && !await _isManaged(file)) return false;
    await remove(item);
    return true;
  }

  Future<int> deleteSelectedFiles() async {
    final selected = _items.where((item) => _selectedIds.contains(item.id)).toList(growable: false);
    var removed = 0;
    for (final item in selected) {
      if (await deleteFileFor(item)) removed++;
    }
    _selectedIds.removeWhere((id) => byId(id) == null);
    _changed();
    return removed;
  }

  // Anything under the TubeArena folder (Downloads and the user's own Library
  // folders) is managed, so moved files can still be deleted from here.
  Future<bool> _isManaged(File file) async {
    try {
      final root = await (await _downloadsDirectoryResolver()).parent.resolveSymbolicLinks();
      final resolved = await file.resolveSymbolicLinks();
      return resolved.startsWith('$root${Platform.pathSeparator}');
    } catch (_) {
      return false;
    }
  }

  Future<bool> _deleteManaged(String path) async {
    try {
      final file = File(path);
      if (!await file.exists() || !await _isManaged(file)) return false;
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteParts(DownloadEntry entry) async {
    for (final path in entry.partPaths) {
      await _deleteManaged(path);
    }
  }

  String _uniquePath(Directory dir, String base, String extension) {
    bool taken(String path) => File(path).existsSync() || _items.any((e) => e.savedPath == path);
    var candidate = '${dir.path}/$base$extension';
    var n = 2;
    while (taken(candidate)) {
      candidate = '${dir.path}/$base ($n)$extension';
      n++;
    }
    return candidate;
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }
}

/// Makes a title safe as a file name while keeping non-Latin letters
/// (Bangla, Hindi, Arabic, emoji...). Only characters that Android or other
/// file systems reject are replaced.
String safeFileName(String title, {int maxLength = 80}) {
  var name = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  final runes = name.runes.toList();
  if (runes.length > maxLength) name = String.fromCharCodes(runes.take(maxLength)).trim();
  return name.isEmpty ? 'download' : name;
}
