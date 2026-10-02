import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';
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
  double progress = 0.0;
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
  static final BackgroundDownloadService _instance = BackgroundDownloadService._internal();
  final logger = Logger();
  final dio = Dio();

  final Map<String, DownloadTask> _activeTasks = {};
  final _statusStreamController = StreamController<Map<String, DownloadTask>>.broadcast();

  factory BackgroundDownloadService() {
    return _instance;
  }

  BackgroundDownloadService._internal();

  /// Initialize background download service
  /// Must be called on app startup
  Future<void> initialize() async {
    try {
      logger.i('Initializing BackgroundDownloadService...');
      await FlutterDownloader.initialize(
        debug: true,
        ignoreSsl: true,
      );
      logger.i('FlutterDownloader initialized successfully');
    } catch (e) {
      logger.e('Error initializing background download: $e');
    }
  }

  /// Start downloading a video or audio file
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
      final applicationDocDir = await getApplicationDocumentsDirectory();
      final downloadPath = '${applicationDocDir.path}/TubeArena/Downloads';

      logger.i('Starting download: $title');
      logger.i('Download path: $downloadPath');

      // Determine file extension
      final fileExt = isAudioOnly
          ? (format.contains('MP3') ? '.mp3' : '.m4a')
          : '.mp4';

      // Create download task
      final downloadTask = DownloadTask(
        id: id,
        title: title,
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        savePath: '$downloadPath/${title.replaceAll(RegExp(r'[^\w\s]'), '')}$fileExt',
        quality: quality,
        format: format,
        isAudioOnly: isAudioOnly,
      );

      // Use the first available URL (video or audio)
      final downloadUrl = isAudioOnly ? audioUrl : videoUrl;

      // Start download using FlutterDownloader
      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: downloadPath,
        fileName: '${title.replaceAll(RegExp(r'[^\w\s]'), '')}$fileExt',
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );

      if (taskId != null) {
        downloadTask.taskId = taskId;
        downloadTask.status = DownloadStatus.downloading;
        _activeTasks[id] = downloadTask;
        _notifyListeners();

        logger.i('Download started with task ID: $taskId');
        return taskId;
      }
    } catch (e) {
      logger.e('Error starting download: $e');
    }
    return null;
  }

  /// Pause an active download
  Future<bool> pauseDownload(String downloadId) async {
    try {
      final task = _activeTasks[downloadId];
      if (task?.taskId != null) {
        await FlutterDownloader.pause(taskId: task!.taskId!);
        task.status = DownloadStatus.paused;
        _notifyListeners();
        logger.i('Download paused: $downloadId');
        return true;
      }
    } catch (e) {
      logger.e('Error pausing download: $e');
    }
    return false;
  }

  /// Resume a paused download
  Future<bool> resumeDownload(String downloadId) async {
    try {
      final task = _activeTasks[downloadId];
      if (task?.taskId != null) {
        final newTaskId = await FlutterDownloader.resume(taskId: task!.taskId!);
        if (newTaskId != null) {
          task.taskId = newTaskId;
          task.status = DownloadStatus.downloading;
          _notifyListeners();
          logger.i('Download resumed: $downloadId');
          return true;
        }
      }
    } catch (e) {
      logger.e('Error resuming download: $e');
    }
    return false;
  }

  /// Cancel a download
  Future<bool> cancelDownload(String downloadId) async {
    try {
      final task = _activeTasks[downloadId];
      if (task?.taskId != null) {
        await FlutterDownloader.cancel(taskId: task!.taskId!);
        task.status = DownloadStatus.cancelled;
        _activeTasks.remove(downloadId);
        _notifyListeners();
        logger.i('Download cancelled: $downloadId');
        return true;
      }
    } catch (e) {
      logger.e('Error cancelling download: $e');
    }
    return false;
  }

  /// Update download progress
  void updateProgress(String downloadId, double progress) {
    final task = _activeTasks[downloadId];
    if (task != null) {
      task.progress = progress;
      if (progress >= 100) {
        task.status = DownloadStatus.completed;
      }
      _notifyListeners();
    }
  }

  /// Get all active downloads
  Map<String, DownloadTask> getActiveTasks() => Map.unmodifiable(_activeTasks);

  /// Stream of download status updates
  Stream<Map<String, DownloadTask>> get statusStream => _statusStreamController.stream;

  /// Notify listeners of status changes
  void _notifyListeners() {
    _statusStreamController.add(Map.unmodifiable(_activeTasks));
  }

  /// Dispose resources
  void dispose() {
    _statusStreamController.close();
  }
}
