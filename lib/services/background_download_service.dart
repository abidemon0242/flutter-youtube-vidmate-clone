import 'dart:async';
import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.audioUrl,
    required this.savePath,
    required this.quality,
    required this.format,
    required this.isAudioOnly,
  });

  final String id;
  final String title;
  final String videoUrl;
  final String audioUrl;
  final String savePath;
  final String quality;
  final String format;
  final bool isAudioOnly;

  DownloadStatus status = DownloadStatus.pending;
  double progress = 0;
  String? taskId;
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
  static final BackgroundDownloadService _instance =
      BackgroundDownloadService._internal();

  final logger = Logger();
  final Map<String, DownloadTask> _activeTasks = {};
  final StreamController<Map<String, DownloadTask>> _statusStreamController =
      StreamController<Map<String, DownloadTask>>.broadcast();

  bool _initialized = false;

  factory BackgroundDownloadService() => _instance;

  BackgroundDownloadService._internal();

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await FlutterDownloader.initialize(
        debug: false,
        ignoreSsl: false,
      );
      _initialized = true;
      logger.i('BackgroundDownloadService initialized.');
    } catch (error, stackTrace) {
      logger.e(
        'Could not initialize background downloads.',
        error: error,
        stackTrace: stackTrace,
      );
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
      if (id.trim().isEmpty) {
        logger.e('A non-empty download ID is required.');
        return null;
      }

      final existingTask = _activeTasks[id];
      if (existingTask != null) return existingTask.taskId;

      if (!_initialized) await initialize();
      if (!_initialized) return null;

      final downloadUrl = isAudioOnly ? audioUrl : videoUrl;
      final uri = Uri.tryParse(downloadUrl);
      if (uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        logger.e('Download URL must be a valid HTTP(S) URL.');
        return null;
      }

      final applicationDocDir = await getApplicationDocumentsDirectory();
      final downloadDirectory =
          Directory('${applicationDocDir.path}/TubeArena/Downloads');
      await downloadDirectory.create(recursive: true);

      final extension = isAudioOnly
          ? (format.toUpperCase().contains('MP3') ? '.mp3' : '.m4a')
          : '.mp4';
      final sanitizedTitle = title
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final safeTitle = sanitizedTitle.length > 80
          ? sanitizedTitle.substring(0, 80)
          : sanitizedTitle;
      final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      if (safeId.isEmpty) {
        logger.e('Download ID contains no filename-safe characters.');
        return null;
      }
      final fileName =
          '${safeTitle.isEmpty ? 'download' : safeTitle}_${safeId.substring(0, safeId.length > 48 ? 48 : safeId.length)}$extension';
      final savePath = '${downloadDirectory.path}/$fileName';

      final task = DownloadTask(
        id: id,
        title: title,
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        savePath: savePath,
        quality: quality,
        format: format,
        isAudioOnly: isAudioOnly,
      );

      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: downloadDirectory.path,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );

      if (taskId == null) return null;

      task
        ..taskId = taskId
        ..status = DownloadStatus.downloading;
      _activeTasks[id] = task;
      _notifyListeners();
      return taskId;
    } catch (error, stackTrace) {
      logger.e(
        'Error starting download.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> pauseDownload(String downloadId) async {
    try {
      final task = _activeTasks[downloadId];
      if (task?.taskId == null) return false;
      await FlutterDownloader.pause(taskId: task!.taskId!);
      task.status = DownloadStatus.paused;
      _notifyListeners();
      return true;
    } catch (error, stackTrace) {
      logger.e('Error pausing download.', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> resumeDownload(String downloadId) async {
    try {
      final task = _activeTasks[downloadId];
      if (task?.taskId == null) return false;
      final newTaskId = await FlutterDownloader.resume(taskId: task!.taskId!);
      if (newTaskId == null) return false;
      task
        ..taskId = newTaskId
        ..status = DownloadStatus.downloading;
      _notifyListeners();
      return true;
    } catch (error, stackTrace) {
      logger.e('Error resuming download.', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> cancelDownload(String downloadId) async {
    try {
      final task = _activeTasks[downloadId];
      if (task?.taskId == null) return false;
      await FlutterDownloader.cancel(taskId: task!.taskId!);
      task.status = DownloadStatus.cancelled;
      _activeTasks.remove(downloadId);
      _notifyListeners();
      return true;
    } catch (error, stackTrace) {
      logger.e('Error cancelling download.', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  void updateProgress(String downloadId, double progress) {
    final task = _activeTasks[downloadId];
    if (task == null) return;
    task.progress = progress.clamp(0, 100).toDouble();
    if (task.progress >= 100) task.status = DownloadStatus.completed;
    _notifyListeners();
  }

  Map<String, DownloadTask> getActiveTasks() =>
      Map.unmodifiable(_activeTasks);

  Stream<Map<String, DownloadTask>> get statusStream =>
      _statusStreamController.stream;

  void _notifyListeners() {
    if (!_statusStreamController.isClosed) {
      _statusStreamController.add(Map.unmodifiable(_activeTasks));
    }
  }

  void dispose() {
    if (!_statusStreamController.isClosed) {
      _statusStreamController.close();
    }
  }
}
