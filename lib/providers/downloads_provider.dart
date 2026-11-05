import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  }) => DownloadEntry(
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
        progress: ((json['progress'] as num?)?.toDouble() ?? 0).clamp(0, 100).toDouble(),
        savedPath: json['savedPath'] as String? ?? '',
        isAudioOnly: json['isAudioOnly'] as bool? ?? false,
        status: json['status'] as String? ?? 'pending',
      );
}

class DownloadsProvider extends ChangeNotifier {
  DownloadsProvider({Future<Directory> Function()? downloadsDirectoryResolver})
      : _downloadsDirectoryResolver =
            downloadsDirectoryResolver ?? _defaultDownloadsDirectory {
    _serviceSubscription = _downloadService.statusStream.listen(_syncFromService);
  }

  final Future<Directory> Function() _downloadsDirectoryResolver;
  final List<DownloadEntry> _items = [];
  final Set<String> _selectedIds = {};
  final BackgroundDownloadService _downloadService = BackgroundDownloadService();

  StreamSubscription<Map<String, AppDownloadTask>>? _serviceSubscription;
  late final Future<File> _storageFile = _createStorageFile();
  Future<void> _saveQueue = Future<void>.value();
  bool _initialized = false;

  static Future<Directory> _defaultDownloadsDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/TubeArena/Downloads');
  }

  Future<File> _createStorageFile() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/TubeArena');
    await directory.create(recursive: true);
    return File('${directory.path}/downloads.json');
  }

  List<DownloadEntry> get items => List.unmodifiable(_items);
  List<String> get selectedIds => List.unmodifiable(_selectedIds);
  bool get hasSelection => _selectedIds.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final file = await _storageFile;
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          for (final value in decoded) {
            if (value is! Map<String, dynamic>) continue;
            try {
              final entry = DownloadEntry.fromJson(value);
              _items.removeWhere((item) => item.id == entry.id);
              _items.add(entry);
            } catch (error) {
              // One malformed history row must not hide all other downloads.
              debugPrint('Skipping invalid download history entry: $error');
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Could not restore download history: $error');
    }
    _initialized = true;
    _syncFromService(_downloadService.getActiveTasks());
    notifyListeners();
  }

  void _syncFromService(Map<String, AppDownloadTask> tasks) {
    if (!_initialized) return;
    var changed = false;
    for (final task in tasks.values) {
      final index = _items.indexWhere((item) => item.id == task.id);
      final current = index < 0 ? null : _items[index];
      final updated = DownloadEntry(
        id: task.id,
        title: task.title,
        url: task.isAudioOnly ? task.audioUrl : task.videoUrl,
        size: current?.size ?? 'Unknown',
        format: '${task.quality} ${task.outputFormat.isEmpty ? task.format : task.outputFormat}'.trim(),
        progress: task.progress.clamp(0, 100).toDouble(),
        savedPath: task.savePath,
        isAudioOnly: task.isAudioOnly,
        status: task.status.name,
      );
      if (current == null) {
        _items.insert(0, updated);
      } else if (current.progress != updated.progress ||
          current.status != updated.status ||
          current.savedPath != updated.savedPath) {
        _items[index] = updated;
      } else {
        continue;
      }
      changed = true;
    }
    if (changed) {
      notifyListeners();
      _persist();
    }
  }

  void addDownload(DownloadEntry item) {
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index < 0) {
      _items.insert(0, item);
    } else {
      _items[index] = item;
    }
    notifyListeners();
    _persist();
  }

  void toggleSelection(String id) {
    if (!_items.any((item) => item.id == id)) return;
    if (!_selectedIds.add(id)) _selectedIds.remove(id);
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }

  /// Removes history records only. Use deleteSelectedFiles to delete media too.
  void removeSelected() {
    _items.removeWhere((item) => _selectedIds.contains(item.id));
    _selectedIds.clear();
    notifyListeners();
    _persist();
  }

  Future<bool> pauseDownload(String id) => _downloadService.pauseDownload(id);
  Future<bool> resumeDownload(String id) => _downloadService.resumeDownload(id);
  Future<bool> cancelDownload(String id) => _downloadService.cancelDownload(id);
  Future<bool> retryDownload(String id) => _downloadService.retryDownload(id);

  Future<bool> deleteFileFor(DownloadEntry item) async {
    try {
      if ((item.status == 'pending' ||
              item.status == 'downloading' ||
              item.status == 'paused') &&
          _downloadService.getActiveTasks().containsKey(item.id)) {
        if (!await _downloadService.cancelDownload(item.id)) return false;
      }
      final path = item.savedPath.trim();
      if (path.isEmpty) return false;
      final file = File(path);
      if (await file.exists()) {
        final root = await _downloadsDirectoryResolver();
        await root.create(recursive: true);
        final expectedRoot = await root.resolveSymbolicLinks();
        final resolvedFile = await file.resolveSymbolicLinks();
        final prefix = '$expectedRoot${Platform.pathSeparator}';
        if (!resolvedFile.startsWith(prefix)) return false;
        await file.delete();
      }
      await _downloadService.forgetTask(item.id);
      _items.removeWhere((entry) => entry.id == item.id);
      _selectedIds.remove(item.id);
      notifyListeners();
      await _persist();
      return true;
    } catch (error) {
      debugPrint('Could not safely delete download: $error');
      return false;
    }
  }

  Future<int> deleteSelectedFiles() async {
    final selected = _items
        .where((item) => _selectedIds.contains(item.id))
        .toList(growable: false);
    var deleted = 0;
    for (final item in selected) {
      if (await deleteFileFor(item)) deleted++;
    }
    _selectedIds.removeWhere((id) => !_items.any((item) => item.id == id));
    notifyListeners();
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
        debugPrint('Could not persist download history: $error');
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
