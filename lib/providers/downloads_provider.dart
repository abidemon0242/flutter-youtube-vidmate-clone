import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/background_download_service.dart';

class DownloadEntry {
  DownloadEntry({
    required this.id,
    required this.title,
    required this.url,
    required this.size,
    required this.format,
    required this.progress,
    required this.savedPath,
    this.isAudioOnly = false,
    this.status = 'pending',
  });

  final String id;
  final String title;
  final String url;
  final String size;
  final String format;
  final double progress;
  final String savedPath;
  final bool isAudioOnly;
  final String status;

  DownloadEntry copyWith({
    String? id,
    String? title,
    String? url,
    String? size,
    String? format,
    double? progress,
    String? savedPath,
    bool? isAudioOnly,
    String? status,
  }) {
    return DownloadEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      size: size ?? this.size,
      format: format ?? this.format,
      progress: progress ?? this.progress,
      savedPath: savedPath ?? this.savedPath,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'size': size,
        'format': format,
        'progress': progress,
        'savedPath': savedPath,
        'isAudioOnly': isAudioOnly,
        'status': status,
      };

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Download',
        url: json['url'] as String? ?? '',
        size: json['size'] as String? ?? 'Unknown',
        format: json['format'] as String? ?? '',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        savedPath: json['savedPath'] as String? ?? '',
        isAudioOnly: json['isAudioOnly'] as bool? ?? false,
        status: json['status'] as String? ?? 'pending',
      );
}

class DownloadsProvider extends ChangeNotifier {
  DownloadsProvider() {
    _serviceSubscription =
        _downloadService.statusStream.listen(_syncFromService);
  }

  final List<DownloadEntry> _items = [];
  final Set<String> _selectedIds = {};
  final BackgroundDownloadService _downloadService =
      BackgroundDownloadService();

  late final Future<File> _storageFile = _createStorageFile();
  StreamSubscription<Map<String, AppDownloadTask>>? _serviceSubscription;
  bool _initialized = false;
  Future<void> _saveQueue = Future<void>.value();

  List<DownloadEntry> get items => List.unmodifiable(_items);
  List<String> get selectedIds => List.unmodifiable(_selectedIds.toList());
  bool get hasSelection => _selectedIds.isNotEmpty;

  Future<File> _createStorageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory('${directory.path}/TubeArena');
    await folder.create(recursive: true);
    return File('${folder.path}/downloads.json');
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final file = await _storageFile;
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final entry = DownloadEntry.fromJson(item);
              _items.removeWhere((existing) => existing.id == entry.id);
              _items.add(entry);
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Could not restore download list: $error');
    }

    _initialized = true;
    _syncFromService(_downloadService.getActiveTasks());
    notifyListeners();
  }

  void _syncFromService(Map<String, AppDownloadTask> tasks) {
    if (!_initialized) return;
    var changed = false;

    for (final task in tasks.values) {
      final index = _items.indexWhere((entry) => entry.id == task.id);
      final existing = index >= 0 ? _items[index] : null;
      final updated = DownloadEntry(
        id: task.id,
        title: task.title,
        url: task.isAudioOnly ? task.audioUrl : task.videoUrl,
        size: existing?.size ?? 'Unknown',
        format: '${task.quality} ${task.format}'.trim(),
        progress: task.progress,
        savedPath: task.savePath,
        isAudioOnly: task.isAudioOnly,
        status: task.status.name,
      );

      if (index >= 0) {
        _items[index] = updated;
      } else {
        _items.insert(0, updated);
      }
      changed = true;
    }

    if (changed) {
      notifyListeners();
      _persist();
    }
  }

  void addDownload(DownloadEntry item) {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.insert(0, item);
    }
    notifyListeners();
    _persist();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  Future<bool> pauseDownload(String id) =>
      _downloadService.pauseDownload(id);

  Future<bool> resumeDownload(String id) =>
      _downloadService.resumeDownload(id);

  Future<bool> cancelDownload(String id) =>
      _downloadService.cancelDownload(id);

  Future<int> removeSelected() async {
    final ids = List<String>.from(_selectedIds);
    var removed = 0;
    for (final id in ids) {
      final index = _items.indexWhere((item) => item.id == id);
      if (index < 0) continue;
      final item = _items[index];
      if (item.status == 'pending' ||
          item.status == 'downloading' ||
          item.status == 'paused') {
        final cancelled = await _downloadService.cancelDownload(id);
        if (!cancelled) continue;
      }
      final path = item.savedPath;
      if (path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (error) {
            debugPrint('Could not delete download file: $error');
          }
        }
      }
      await _downloadService.forgetTask(id);
      _items.removeWhere((entry) => entry.id == id);
      removed++;
    }
    _selectedIds.clear();
    notifyListeners();
    await _persist();
    return removed;
  }

  Future<bool> deleteFileFor(DownloadEntry item) async {
    if (item.status == 'pending' ||
        item.status == 'downloading' ||
        item.status == 'paused') {
      final cancelled = await _downloadService.cancelDownload(item.id);
      if (!cancelled) return false;
    }
    var deleted = true;
    if (item.savedPath.isNotEmpty) {
      final file = File(item.savedPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (error) {
          debugPrint('Could not delete download file: $error');
          deleted = false;
        }
      }
    }
    await _downloadService.forgetTask(item.id);
    _items.removeWhere((entry) => entry.id == item.id);
    _selectedIds.remove(item.id);
    notifyListeners();
    await _persist();
    return deleted;
  }

  Future<void> _persist() {
    _saveQueue = _saveQueue.then((_) async {
      try {
        final file = await _storageFile;
        await file.writeAsString(
          jsonEncode(_items.map((item) => item.toJson()).toList()),
          flush: true,
        );
      } catch (error) {
        debugPrint('Could not save download list: $error');
      }
    });
    return _saveQueue;
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }
}
