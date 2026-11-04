import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart' as fd;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class AppDownloadTask {
  AppDownloadTask({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.audioUrl,
    required this.savePath,
    required this.quality,
    required this.format,
    required this.isAudioOnly,
    this.taskId,
    this.status = DownloadStatus.pending,
    this.progress = 0,
  });

  final String id;
  final String title;
  final String videoUrl;
  final String audioUrl;
  final String savePath;
  final String quality;
  final String format;
  final bool isAudioOnly;
  String? taskId;
  DownloadStatus status;
  double progress;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'videoUrl': videoUrl,
        'audioUrl': audioUrl,
        'savePath': savePath,
        'quality': quality,
        'format': format,
        'isAudioOnly': isAudioOnly,
        'taskId': taskId,
        'status': status.name,
        'progress': progress,
      };

  factory AppDownloadTask.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'pending';
    return AppDownloadTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Download',
      videoUrl: json['videoUrl'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      savePath: json['savePath'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      format: json['format'] as String? ?? '',
      isAudioOnly: json['isAudioOnly'] as bool? ?? false,
      taskId: json['taskId'] as String?,
      status: DownloadStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => DownloadStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
    );
  }
}

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class BackgroundDownloadService {
  static const String _portName = 'tube_arena_download_callback';
  static final BackgroundDownloadService _instance =
      BackgroundDownloadService._internal();

  final Logger logger = Logger();
  final Map<String, AppDownloadTask> _activeTasks = {};
  final StreamController<Map<String, AppDownloadTask>> _statusStreamController =
      StreamController<Map<String, AppDownloadTask>>.broadcast();

  ReceivePort? _receivePort;
  bool _initialized = false;
  String? _metadataPath;

  factory BackgroundDownloadService() => _instance;

  BackgroundDownloadService._internal();

  @pragma('vm:entry-point')
  static void downloadCallback(
    String taskId,
    int status,
    int progress,
  ) {
    final sendPort = IsolateNameServer.lookupPortByName(_portName);
    sendPort?.send([taskId, status, progress]);
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final documents = await getApplicationDocumentsDirectory();
      _metadataPath = '${documents.path}/TubeArena/download_tasks.json';
      await Directory('${documents.path}/TubeArena').create(recursive: true);

      await fd.FlutterDownloader.initialize(
        debug: false,
        ignoreSsl: false,
      );

      _receivePort = ReceivePort();
      IsolateNameServer.removePortNameMapping(_portName);
      IsolateNameServer.registerPortWithName(_receivePort!.sendPort, _portName);
      _receivePort!.listen(_handleCallback);
      await fd.FlutterDownloader.registerCallback(downloadCallback);

      await _restoreMetadata();
      await _restorePluginTasks();
      _initialized = true;
      _notifyListeners();
      logger.i('Background download service initialized and restored');
    } catch (error, stackTrace) {
      IsolateNameServer.removePortNameMapping(_portName);
      _receivePort?.close();
      _receivePort = null;
      _initialized = false;
      logger.e('Error initializing download service', error: error, stackTrace: stackTrace);
    }
  }

  void _handleCallback(dynamic message) {
    if (message is! List || message.length != 3) return;
    final taskId = message[0] as String;
    final statusIndex = message[1] as int;
    final progress = message[2] as int;

    final task = _activeTasks.values.cast<AppDownloadTask?>().firstWhere(
      (item) => item?.taskId == taskId,
      orElse: () => null,
    );
    if (task == null) return;

    task.progress = progress.toDouble();
    if (statusIndex >= 0 && statusIndex < fd.DownloadTaskStatus.values.length) {
      task.status = _mapStatus(fd.DownloadTaskStatus.values[statusIndex]);
    }
    _persistMetadata();
    _notifyListeners();
  }

  DownloadStatus _mapStatus(fd.DownloadTaskStatus status) {
    if (status == fd.DownloadTaskStatus.running) return DownloadStatus.downloading;
    if (status == fd.DownloadTaskStatus.paused) return DownloadStatus.paused;
    if (status == fd.DownloadTaskStatus.complete) return DownloadStatus.completed;
    if (status == fd.DownloadTaskStatus.failed) return DownloadStatus.failed;
    if (status == fd.DownloadTaskStatus.canceled) return DownloadStatus.cancelled;
    return DownloadStatus.pending;
  }

  Future<void> _restorePreferences() async {\n    final path = _preferencesPath;\n    if (path == null) return;\n    try {\n      final file = File(path);\n      if (await file.exists()) {\n        final decoded = jsonDecode(await file.readAsString());\n        if (decoded is Map<String, dynamic>) {\n          _wifiOnly = decoded['wifiOnly'] as bool? ?? false;\n        }\n      }\n    } catch (error) {\n      logger.w('Could not restore download preferences: $error');\n    }\n  }\n\n  Future<void> _persistPreferences() async {\n    final path = _preferencesPath;\n    if (path == null) return;\n    try {\n      await File(path).writeAsString(jsonEncode({'wifiOnly': _wifiOnly}), flush: true);\n    } catch (error) {\n      logger.w('Could not save download preferences: $error');\n    }\n  }\n\n  Future<void> setWifiOnly(bool enabled) async {\n    _wifiOnly = enabled;\n    await _persistPreferences();\n    final current = await _connectivity.checkConnectivity();\n    await _applyNetworkPolicy(current);\n    _notifyListeners();\n  }\n\n  Future<bool> _hasWifiConnection() async {\n    final results = await _connectivity.checkConnectivity();\n    return results.contains(ConnectivityResult.wifi) ||\n        results.contains(ConnectivityResult.ethernet);\n  }\n\n  Future<void> _applyNetworkPolicy(List<ConnectivityResult> results) async {\n    if (!_initialized) return;\n    final wifiAvailable = results.contains(ConnectivityResult.wifi) ||\n        results.contains(ConnectivityResult.ethernet);\n    if (_wifiOnly && !wifiAvailable) {\n      for (final task in _activeTasks.values.toList()) {\n        if (task.status == DownloadStatus.downloading ||\n            task.status == DownloadStatus.pending) {\n          final paused = await pauseDownload(task.id);\n          if (paused) task.pausedByWifiPolicy = true;\n        }\n      }\n    } else {\n      for (final task in _activeTasks.values.toList()) {\n        if (task.pausedByWifiPolicy) {\n          task.pausedByWifiPolicy = false;\n          await resumeDownload(task.id);\n        }\n      }\n    }\n    await _persistMetadata();\n  }\n\n  Future<void> _restoreMetadata() async {
    final path = _metadataPath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final task = AppDownloadTask.fromJson(item);
            _activeTasks[task.id] = task;
          }
        }
      }
    } catch (error) {
      logger.w('Could not restore download metadata: $error');
    }
  }

  Future<void> _restorePluginTasks() async {
    try {
      final pluginTasks = await fd.FlutterDownloader.loadTasks();
      if (pluginTasks == null) return;

      final tasksById = {for (final task in pluginTasks) task.taskId: task};
      for (final task in _activeTasks.values) {
        final pluginTaskId = task.taskId;
        if (pluginTaskId == null) continue;
        final pluginTask = tasksById[pluginTaskId];
        if (pluginTask == null) continue;
        task.progress = pluginTask.progress.toDouble();
        task.status = _mapStatus(pluginTask.status);
      }
      await _persistMetadata();
    } catch (error) {
      logger.w('Could not restore native download tasks: $error');
    }
  }

  Future<void> _persistMetadata() async {
    final path = _metadataPath;
    if (path == null) return;
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(_activeTasks.values.map((task) => task.toJson()).toList()),
        flush: true,
      );
    } catch (error) {
      logger.w('Could not save download metadata: $error');
    }
  }

  Future<String?> startDownload({
    required String id,
    required String title,
    required String videoUrl,
    required String audioUrl,
    required String quality,
    required String format,
    required bool isAudioOnly,
  }) async {
    try {
      if (!_initialized) await initialize();
      if (!_initialized) {
        logger.e('Download service is unavailable; refusing to queue a task');
        return null;
      }

      final applicationDocDir = await getApplicationDocumentsDirectory();
      final downloadPath = '${applicationDocDir.path}/TubeArena/Downloads';
      await Directory(downloadPath).create(recursive: true);

      final normalizedFormat = format.toLowerCase();
      final fileExt = isAudioOnly
          ? (normalizedFormat.contains('mp3')
              ? '.mp3'
              : normalizedFormat.contains('webm')
                  ? '.webm'
                  : normalizedFormat.contains('aac')
                      ? '.aac'
                      : normalizedFormat.contains('wav')
                          ? '.wav'
                          : '.m4a')
          : (normalizedFormat.contains('webm') ? '.webm' : '.mp4');

      final downloadUrl = isAudioOnly ? audioUrl : videoUrl;
      final parsedUrl = Uri.tryParse(downloadUrl);
      if (parsedUrl == null ||
          !parsedUrl.hasScheme ||
          !['http', 'https'].contains(parsedUrl.scheme) ||
          parsedUrl.host.isEmpty) {
        logger.w('Rejected invalid download URL');
        return null;
      }

      final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final safeId = id.replaceAll(RegExp(r'[^\w-]'), '');
      final fileBase = safeTitle.isEmpty ? safeId : '${safeTitle}_$safeId';
      final safeFileName = '$fileBase$fileExt';

      final taskId = await fd.FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: downloadPath,
        fileName: safeFileName,
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );

      if (taskId == null) return null;

      final task = AppDownloadTask(
        id: id,
        title: title,
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        savePath: '$downloadPath/$safeFileName',
        quality: quality,
        format: format,
        isAudioOnly: isAudioOnly,
        taskId: taskId,
        status: DownloadStatus.pending,
      );
      _activeTasks[id] = task;
      await _persistMetadata();
      _notifyListeners();
      logger.i('Download queued: $title ($taskId)');
      return taskId;
    } catch (error, stackTrace) {
      logger.e('Error starting download', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> pauseDownload(String downloadId) async {
    final task = _activeTasks[downloadId];
    if (task?.taskId == null) return false;
    try {
      await fd.FlutterDownloader.pause(taskId: task!.taskId!);
      task.status = DownloadStatus.paused;
      await _persistMetadata();
      _notifyListeners();
      return true;
    } catch (error) {
      logger.e('Error pausing download: $error');
      return false;
    }
  }

  Future<bool> resumeDownload(String downloadId) async {
    final task = _activeTasks[downloadId];
    if (task?.taskId == null) return false;
    try {
      final newTaskId = await fd.FlutterDownloader.resume(taskId: task!.taskId!);
      if (newTaskId == null) return false;
      task.taskId = newTaskId;
      task.status = DownloadStatus.pending;
      await _persistMetadata();
      _notifyListeners();
      return true;
    } catch (error) {
      logger.e('Error resuming download: $error');
      return false;
    }
  }

  Future<bool> retryDownload(String downloadId) async {
    final task = _activeTasks[downloadId];
    if (task == null ||
        (task.status != DownloadStatus.failed &&
            task.status != DownloadStatus.cancelled)) {
      return false;
    }
    try {
      final downloadUrl = task.isAudioOnly ? task.audioUrl : task.videoUrl;
      final uri = Uri.tryParse(downloadUrl);
      if (uri == null ||
          !uri.hasScheme ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        return false;
      }
      final documents = await getApplicationDocumentsDirectory();
      final downloadsDirectory = Directory('${documents.path}/TubeArena/Downloads');
      await downloadsDirectory.create(recursive: true);
      final targetFile = File(task.savePath);
      final expectedPrefix = '${downloadsDirectory.absolute.path}${Platform.pathSeparator}';
      if (!targetFile.absolute.path.startsWith(expectedPrefix)) return false;
      await targetFile.parent.create(recursive: true);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      final newTaskId = await fd.FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: targetFile.parent.path,
        fileName: targetFile.uri.pathSegments.last,
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );
      if (newTaskId == null) return false;
      task.taskId = newTaskId;
      task.status = DownloadStatus.pending;
      task.progress = 0;
      await _persistMetadata();
      _notifyListeners();
      return true;
    } catch (error) {
      logger.e('Error retrying download: $error');
      return false;
    }
  }

  Future<bool> cancelDownload(String downloadId) async {
    final task = _activeTasks[downloadId];
    if (task?.taskId == null) return false;
    try {
      await fd.FlutterDownloader.cancel(taskId: task!.taskId!);
      task.status = DownloadStatus.cancelled;
      await _persistMetadata();
      _notifyListeners();
      return true;
    } catch (error) {
      logger.e('Error cancelling download: $error');
      return false;
    }
  }

  Future<void> forgetTask(String downloadId) async {
    _activeTasks.remove(downloadId);
    await _persistMetadata();
    _notifyListeners();
  }

  Map<String, AppDownloadTask> getActiveTasks() =>
      Map.unmodifiable(_activeTasks);

  Stream<Map<String, AppDownloadTask>> get statusStream =>
      _statusStreamController.stream;

  void _notifyListeners() {
    if (!_statusStreamController.isClosed) {
      _statusStreamController.add(Map.unmodifiable(_activeTasks));
    }
  }
}
