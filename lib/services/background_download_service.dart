import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart' as fd;
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import 'ffmpeg_merge_service.dart';
import 'youtube_extraction_service.dart';

class AppDownloadTask {
  AppDownloadTask({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.audioUrl,
    this.sourceUrl,
    required this.savePath,
    required this.quality,
    required this.format,
    this.outputFormat = '',
    required this.isAudioOnly,
    this.taskId,
    this.status = DownloadStatus.pending,
    this.progress = 0,
    this.pausedByWifiPolicy = false,
    this.videoTaskId,
    this.audioTaskId,
    this.videoTempPath,
    this.audioTempPath,
    this.requiresMerge = false,
    this.videoStatus,
    this.audioStatus,
    this.videoProgress = 0,
    this.audioProgress = 0,
    this.isMerging = false,
  });

  final String id;
  final String title;
  String videoUrl;
  String audioUrl;
  final String? sourceUrl;
  final String savePath;
  String quality;
  String format;
  final String outputFormat;
  final bool isAudioOnly;
  String? taskId;
  DownloadStatus status;
  double progress;
  bool pausedByWifiPolicy;
  String? videoTaskId;
  String? audioTaskId;
  String? videoTempPath;
  String? audioTempPath;
  bool requiresMerge;
  DownloadStatus? videoStatus;
  DownloadStatus? audioStatus;
  double videoProgress;
  double audioProgress;
  bool isMerging;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'videoUrl': videoUrl,
    'audioUrl': audioUrl,
    'sourceUrl': sourceUrl,
    'savePath': savePath,
    'quality': quality,
    'format': format,
    'outputFormat': outputFormat,
    'isAudioOnly': isAudioOnly,
    'taskId': taskId,
    'status': status.name,
    'progress': progress,
    'pausedByWifiPolicy': pausedByWifiPolicy,
    'videoTaskId': videoTaskId,
    'audioTaskId': audioTaskId,
    'videoTempPath': videoTempPath,
    'audioTempPath': audioTempPath,
    'requiresMerge': requiresMerge,
    'videoStatus': videoStatus?.name,
    'audioStatus': audioStatus?.name,
    'videoProgress': videoProgress,
    'audioProgress': audioProgress,
    'isMerging': isMerging,
  };

  factory AppDownloadTask.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'pending';
    return AppDownloadTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Download',
      videoUrl: json['videoUrl'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String?,
      savePath: json['savePath'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      format: json['format'] as String? ?? '',
      outputFormat:
          json['outputFormat'] as String? ?? (json['format'] as String? ?? ''),
      isAudioOnly: json['isAudioOnly'] as bool? ?? false,
      taskId: json['taskId'] as String?,
      status: DownloadStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => DownloadStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      pausedByWifiPolicy: json['pausedByWifiPolicy'] as bool? ?? false,
      videoTaskId: json['videoTaskId'] as String?,
      audioTaskId: json['audioTaskId'] as String?,
      videoTempPath: json['videoTempPath'] as String?,
      audioTempPath: json['audioTempPath'] as String?,
      requiresMerge: json['requiresMerge'] as bool? ?? false,
      videoStatus: json['videoStatus'] is String
          ? DownloadStatus.values.firstWhere(
              (v) => v.name == json['videoStatus'],
              orElse: () => DownloadStatus.pending,
            )
          : null,
      audioStatus: json['audioStatus'] is String
          ? DownloadStatus.values.firstWhere(
              (v) => v.name == json['audioStatus'],
              orElse: () => DownloadStatus.pending,
            )
          : null,
      videoProgress: (json['videoProgress'] as num?)?.toDouble() ?? 0,
      audioProgress: (json['audioProgress'] as num?)?.toDouble() ?? 0,
      isMerging: json['isMerging'] as bool? ?? false,
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
  processing,
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  bool _initialized = false;
  String? _initializationError;
  bool _wifiOnly = false;

  bool get isInitialized => _initialized;
  String? get initializationError => _initializationError;
  String? _metadataPath;
  String? _preferencesPath;
  Future<void> _metadataSaveQueue = Future<void>.value();
  Future<void>? _initialization;

  bool get wifiOnly => _wifiOnly;

  factory BackgroundDownloadService() => _instance;

  BackgroundDownloadService._internal();

  @pragma('vm:entry-point')
  static void downloadCallback(String taskId, int status, int progress) {
    final sendPort = IsolateNameServer.lookupPortByName(_portName);
    sendPort?.send([taskId, status, progress]);
  }

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final active = _initialization;
    if (active != null) return active;
    late final Future<void> attempt;
    attempt = _initialize().whenComplete(() {
      if (identical(_initialization, attempt)) _initialization = null;
    });
    _initialization = attempt;
    return attempt;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    try {
      final documents = await getApplicationDocumentsDirectory();
      _metadataPath = '${documents.path}/TubeArena/download_tasks.json';
      _preferencesPath =
          '${documents.path}/TubeArena/download_preferences.json';
      await Directory('${documents.path}/TubeArena').create(recursive: true);

      await fd.FlutterDownloader.initialize(debug: false, ignoreSsl: false);

      _receivePort = ReceivePort();
      IsolateNameServer.removePortNameMapping(_portName);
      final registered = IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort,
        _portName,
      );
      if (!registered)
        throw StateError(
          'Could not register the background download callback port.',
        );
      _receivePort!.listen(_handleCallback);
      await fd.FlutterDownloader.registerCallback(downloadCallback);

      await _restorePreferences();
      await _restoreMetadata();
      await _restorePluginTasks();
      _initialized = true;
      _initializationError = null;
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _applyNetworkPolicy,
      );
      await _applyNetworkPolicy(await _connectivity.checkConnectivity());
      _notifyListeners();
      logger.i('Background download service initialized and restored');
    } catch (error, stackTrace) {
      IsolateNameServer.removePortNameMapping(_portName);
      _receivePort?.close();
      _receivePort = null;
      await _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
      _initialized = false;
      _initializationError = error.toString();
      logger.e(
        'Error initializing download service',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleCallback(dynamic message) {
    if (message is! List ||
        message.length != 3 ||
        message[0] is! String ||
        message[1] is! int ||
        message[2] is! int) {
      return;
    }
    final taskId = message[0] as String;
    final statusIndex = message[1] as int;
    final progress = message[2] as int;

    final task = _activeTasks.values.cast<AppDownloadTask?>().firstWhere(
      (item) =>
          item?.taskId == taskId ||
          item?.videoTaskId == taskId ||
          item?.audioTaskId == taskId,
      orElse: () => null,
    );
    if (task == null) return;

    final mapped =
        statusIndex >= 0 && statusIndex < fd.DownloadTaskStatus.values.length
        ? _mapStatus(fd.DownloadTaskStatus.values[statusIndex])
        : DownloadStatus.failed;
    if (task.requiresMerge) {
      if (task.videoTaskId == taskId) {
        task.videoProgress = progress.toDouble().clamp(0, 100).toDouble();
        task.videoStatus = mapped;
      } else if (task.audioTaskId == taskId) {
        task.audioProgress = progress.toDouble().clamp(0, 100).toDouble();
        task.audioStatus = mapped;
      }
      task.progress = ((task.videoProgress + task.audioProgress) / 2)
          .clamp(0, 100)
          .toDouble();
      _refreshAdaptiveTask(task);
    } else {
      task.progress = progress.toDouble().clamp(0, 100).toDouble();
      task.status = mapped;
    }
    _persistMetadata();
    _notifyListeners();
  }

  void _refreshAdaptiveTask(AppDownloadTask task) {
    final video = task.videoStatus;
    final audio = task.audioStatus;
    if (video == DownloadStatus.failed || audio == DownloadStatus.failed) {
      task.status = DownloadStatus.failed;
      final siblingId = video == DownloadStatus.failed
          ? task.audioTaskId
          : task.videoTaskId;
      if (siblingId != null)
        unawaited(fd.FlutterDownloader.cancel(taskId: siblingId));
      unawaited(_cleanupAdaptiveTempFiles(task));
      return;
    }
    if (video == DownloadStatus.cancelled ||
        audio == DownloadStatus.cancelled) {
      task.status = DownloadStatus.cancelled;
      final siblingId = video == DownloadStatus.cancelled
          ? task.audioTaskId
          : task.videoTaskId;
      if (siblingId != null)
        unawaited(fd.FlutterDownloader.cancel(taskId: siblingId));
      unawaited(_cleanupAdaptiveTempFiles(task));
      return;
    }
    if (video == DownloadStatus.completed &&
        audio == DownloadStatus.completed) {
      task.progress = 99;
      task.status = DownloadStatus.processing;
      if (!task.isMerging) unawaited(_finishAdaptiveMerge(task));
      return;
    }
    task.status =
        video == DownloadStatus.paused || audio == DownloadStatus.paused
        ? DownloadStatus.paused
        : video == DownloadStatus.downloading ||
              audio == DownloadStatus.downloading
        ? DownloadStatus.downloading
        : DownloadStatus.pending;
  }

  Future<bool> _hasValidMergedOutput(AppDownloadTask task) async {
    try {
      final file = File(task.savePath);
      if (!await file.exists() || await file.length() <= 0) return false;
      final session = await FFprobeKit.getMediaInformation(task.savePath);
      final information = await session.getMediaInformation();
      final streams = information?.getStreams() ?? const [];
      return streams.any((stream) => stream.getType() == 'video') &&
          streams.any((stream) => stream.getType() == 'audio');
    } catch (error) {
      logger.w('Could not validate a previous merge output: $error');
      return false;
    }
  }

  Future<void> _finishAdaptiveMerge(AppDownloadTask task) async {
    if (task.isMerging) return;
    task.isMerging = true;
    task.status = DownloadStatus.processing;
    await _persistMetadata();
    _notifyListeners();
    // A process can die after FFmpeg writes the final file but before the
    // completed state is persisted. Adopt a valid output instead of deleting
    // it and trying to merge input streams that may already have been cleaned.
    if (await _hasValidMergedOutput(task)) {
      task.status = DownloadStatus.completed;
      task.progress = 100;
      task.isMerging = false;
      if (task.outputFormat.toUpperCase() == '3GP') {
        final intermediate = File('${task.savePath}.source.mp4');
        if (await intermediate.exists()) await intermediate.delete();
      }
      await _cleanupAdaptiveTempFiles(task);
      await _persistMetadata();
      _notifyListeners();
      return;
    }
    if (task.videoTempPath == null || task.audioTempPath == null) {
      task.status = DownloadStatus.failed;
      task.progress = 0;
      task.isMerging = false;
      await _persistMetadata();
      _notifyListeners();
      return;
    }
    var merged = false;
    try {
      final output = File(task.savePath);
      if (await output.exists()) await output.delete();
      final ffmpeg = FFmpegMergeService();
      final needs3gp = task.outputFormat.toUpperCase() == '3GP';
      final mergePath = needs3gp
          ? '${task.savePath}.source.mp4'
          : task.savePath;
      if (needs3gp) {
        final staleIntermediate = File(mergePath);
        if (await staleIntermediate.exists()) await staleIntermediate.delete();
      }
      final muxed = await ffmpeg.mergeVideoAndAudio(
        videoPath: task.videoTempPath!,
        audioPath: task.audioTempPath!,
        outputPath: mergePath,
        quality: task.quality,
      );
      merged =
          muxed &&
          (!needs3gp ||
              await ffmpeg.convertTo3gp(
                inputPath: mergePath,
                outputPath: task.savePath,
              ));
      if (needs3gp) {
        final intermediate = File(mergePath);
        if (await intermediate.exists()) await intermediate.delete();
      }
    } catch (error, stackTrace) {
      logger.e(
        'Adaptive stream merge failed',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (merged) {
      task.status = DownloadStatus.completed;
      task.progress = 100;
      for (final path in [task.videoTempPath!, task.audioTempPath!]) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (error) {
          logger.w('Could not remove temporary stream file: $error');
        }
      }
    } else {
      try {
        final output = File(task.savePath);
        if (await output.exists()) await output.delete();
      } catch (error) {
        logger.w('Could not remove incomplete merged file: $error');
      }
      task.status = DownloadStatus.failed;
      task.progress = 0;
    }
    task.isMerging = false;
    await _cleanupAdaptiveTempFiles(task);
    await _persistMetadata();
    _notifyListeners();
  }

  Future<void> _cleanupAdaptiveTempFiles(AppDownloadTask task) async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final root = Directory('${documents.path}/TubeArena/Downloads');
      final prefix = '${root.absolute.path}${Platform.pathSeparator}';
      for (final path in [task.videoTempPath, task.audioTempPath]) {
        if (path == null) continue;
        final file = File(path);
        if (!file.absolute.path.startsWith(prefix)) continue;
        try {
          if (await file.exists()) await file.delete();
        } catch (error) {
          logger.w('Could not clean temporary download file: $error');
        }
      }
    } catch (error) {
      logger.w(
        'Could not access download storage for temporary-file cleanup: $error',
      );
    }
  }

  DownloadStatus _mapStatus(fd.DownloadTaskStatus status) {
    if (status == fd.DownloadTaskStatus.running)
      return DownloadStatus.downloading;
    if (status == fd.DownloadTaskStatus.paused) return DownloadStatus.paused;
    if (status == fd.DownloadTaskStatus.complete)
      return DownloadStatus.completed;
    if (status == fd.DownloadTaskStatus.failed) return DownloadStatus.failed;
    if (status == fd.DownloadTaskStatus.canceled)
      return DownloadStatus.cancelled;
    return DownloadStatus.pending;
  }

  Future<void> _restorePreferences() async {
    final path = _preferencesPath;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          _wifiOnly = decoded['wifiOnly'] as bool? ?? false;
        }
      }
    } catch (error) {
      logger.w('Could not restore download preferences: $error');
    }
  }

  Future<void> _persistPreferences() async {
    final path = _preferencesPath;
    if (path == null) return;
    try {
      await File(
        path,
      ).writeAsString(jsonEncode({'wifiOnly': _wifiOnly}), flush: true);
    } catch (error) {
      logger.w('Could not save download preferences: $error');
    }
  }

  Future<void> setWifiOnly(bool enabled) async {
    _wifiOnly = enabled;
    await _persistPreferences();
    await _applyNetworkPolicy(await _connectivity.checkConnectivity());
    _notifyListeners();
  }

  Future<bool> _hasWifiConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  Future<void> _applyNetworkPolicy(List<ConnectivityResult> results) async {
    if (!_initialized) return;
    final wifiAvailable =
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    if (_wifiOnly && !wifiAvailable) {
      for (final task in _activeTasks.values.toList()) {
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.pending) {
          final paused = await pauseDownload(task.id);
          if (paused) task.pausedByWifiPolicy = true;
        }
      }
    } else {
      for (final task in _activeTasks.values.toList()) {
        if (task.pausedByWifiPolicy) {
          final resumed = await resumeDownload(task.id);
          if (resumed) task.pausedByWifiPolicy = false;
        }
      }
    }
    await _persistMetadata();
  }

  Future<void> _restoreMetadata() async {
    final path = _metadataPath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) continue;
          try {
            final task = AppDownloadTask.fromJson(item);
            _activeTasks[task.id] = task;
          } catch (error) {
            // A corrupt row must not discard every other saved download.
            logger.w('Skipping invalid saved download task: $error');
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
      final tasksById = {
        for (final task in pluginTasks ?? <fd.DownloadTask>[])
          task.taskId: task,
      };

      for (final task in _activeTasks.values) {
        if (task.requiresMerge) {
          final video = task.videoTaskId == null
              ? null
              : tasksById[task.videoTaskId];
          final audio = task.audioTaskId == null
              ? null
              : tasksById[task.audioTaskId];
          if (video == null || audio == null) {
            if (task.status != DownloadStatus.completed) {
              task.status = DownloadStatus.failed;
              task.pausedByWifiPolicy = false;
              unawaited(_cleanupAdaptiveTempFiles(task));
            }
            continue;
          }
          task.videoStatus = _mapStatus(video.status);
          task.audioStatus = _mapStatus(audio.status);
          task.videoProgress = video.progress
              .toDouble()
              .clamp(0, 100)
              .toDouble();
          task.audioProgress = audio.progress
              .toDouble()
              .clamp(0, 100)
              .toDouble();
          task.progress = ((task.videoProgress + task.audioProgress) / 2)
              .clamp(0, 100)
              .toDouble();
          task.isMerging = false;
          _refreshAdaptiveTask(task);
          continue;
        }

        final pluginTaskId = task.taskId;
        if (pluginTaskId == null) continue;
        final pluginTask = tasksById[pluginTaskId];
        if (pluginTask == null) {
          if (task.status == DownloadStatus.pending ||
              task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.paused) {
            task.status = DownloadStatus.failed;
            task.pausedByWifiPolicy = false;
          }
          continue;
        }
        task.progress = pluginTask.progress.toDouble().clamp(0, 100).toDouble();
        task.status = _mapStatus(pluginTask.status);
      }
      await _persistMetadata();
    } catch (error) {
      logger.w('Could not restore native download tasks: $error');
    }
  }

  Future<void> _persistMetadata() {
    final path = _metadataPath;
    if (path == null) return Future<void>.value();
    _metadataSaveQueue = _metadataSaveQueue.then((_) async {
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
    });
    return _metadataSaveQueue;
  }

  Future<String?> startDownload({
    required String id,
    required String title,
    required String videoUrl,
    required String audioUrl,
    String? sourceUrl,
    required String quality,
    required String format,
    String? outputFormat,
    required bool isAudioOnly,
  }) async {
    try {
      if (!_initialized) await initialize();
      if (!_initialized) return null;
      if (_wifiOnly && !await _hasWifiConnection()) return null;
      final existing = _activeTasks[id];
      if (existing != null &&
          existing.status != DownloadStatus.failed &&
          existing.status != DownloadStatus.cancelled)
        return null;

      final documents = await getApplicationDocumentsDirectory();
      final downloadPath = '${documents.path}/TubeArena/Downloads';
      await Directory(downloadPath).create(recursive: true);
      final normalizedFormat = format.toLowerCase();
      final normalizedOutputFormat = (outputFormat ?? format).toUpperCase();
      const supportedVideoOutputs = {'MP4', 'WEBM', '3GP'};
      if (!isAudioOnly &&
          !supportedVideoOutputs.contains(normalizedOutputFormat))
        return null;
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
          : '.${normalizedOutputFormat.toLowerCase()}';
      if (!isAudioOnly &&
          normalizedOutputFormat == '3GP' &&
          (normalizedFormat != 'mp4' || audioUrl.trim().isEmpty))
        return null;
      final sourceExt = normalizedFormat.contains('webm') ? '.webm' : '.mp4';
      final normalizedTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final safeTitle = normalizedTitle.length > 80
          ? normalizedTitle.substring(0, 80)
          : normalizedTitle;
      final safeId = id.replaceAll(RegExp(r'[^\w-]'), '');
      if (safeId.isEmpty || safeId.length > 40) return null;
      final fileBase = safeTitle.isEmpty ? safeId : '${safeTitle}_${safeId}';
      final safeFileName = '$fileBase$fileExt';
      final outputPath = '$downloadPath/$safeFileName';

      bool validUrl(String value) {
        final uri = Uri.tryParse(value);
        return uri != null &&
            uri.hasScheme &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty;
      }

      if (isAudioOnly) {
        if (!validUrl(audioUrl)) return null;
      } else if (!validUrl(videoUrl)) {
        return null;
      }
      final requiresMerge = !isAudioOnly && audioUrl.trim().isNotEmpty;
      if (requiresMerge && !validUrl(audioUrl)) return null;

      if (requiresMerge) {
        final videoTempPath = '$downloadPath/$fileBase.video$sourceExt';
        final audioExt = normalizedFormat.contains('webm') ? '.webm' : '.m4a';
        final audioTempPath = '$downloadPath/$fileBase.audio$audioExt';
        for (final path in [outputPath, videoTempPath, audioTempPath]) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }

        final videoTaskId = await fd.FlutterDownloader.enqueue(
          url: videoUrl,
          savedDir: downloadPath,
          fileName: videoTempPath.split(Platform.pathSeparator).last,
          showNotification: false,
          openFileFromNotification: false,
          saveInPublicStorage: false,
        );
        if (videoTaskId == null) return null;

        final task = AppDownloadTask(
          id: id,
          title: title,
          videoUrl: videoUrl,
          audioUrl: audioUrl,
          sourceUrl: sourceUrl,
          savePath: outputPath,
          quality: quality,
          format: format,
          outputFormat: normalizedOutputFormat,
          isAudioOnly: false,
          taskId: videoTaskId,
          videoTaskId: videoTaskId,
          videoTempPath: videoTempPath,
          audioTempPath: audioTempPath,
          requiresMerge: true,
          videoStatus: DownloadStatus.pending,
        );
        _activeTasks[id] = task;
        await _persistMetadata();

        String? audioTaskId;
        try {
          audioTaskId = await fd.FlutterDownloader.enqueue(
            url: audioUrl,
            savedDir: downloadPath,
            fileName: audioTempPath.split(Platform.pathSeparator).last,
            showNotification: false,
            openFileFromNotification: false,
            saveInPublicStorage: false,
          );
        } catch (error) {
          logger.e('Could not queue adaptive audio stream: $error');
        }
        if (audioTaskId == null) {
          await fd.FlutterDownloader.cancel(taskId: videoTaskId);
          _activeTasks.remove(id);
          for (final path in [videoTempPath, audioTempPath]) {
            final file = File(path);
            if (await file.exists()) await file.delete();
          }
          await _persistMetadata();
          return null;
        }
        task.audioTaskId = audioTaskId;
        task.audioStatus = DownloadStatus.pending;
        await _persistMetadata();
        _notifyListeners();
        return videoTaskId;
      }

      final downloadUrl = isAudioOnly ? audioUrl : videoUrl;
      final taskId = await fd.FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: downloadPath,
        fileName: safeFileName,
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );
      if (taskId == null) return null;
      _activeTasks[id] = AppDownloadTask(
        id: id,
        title: title,
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        sourceUrl: sourceUrl,
        savePath: outputPath,
        quality: quality,
        format: format,
        outputFormat: normalizedOutputFormat,
        isAudioOnly: isAudioOnly,
        taskId: taskId,
        status: DownloadStatus.pending,
      );
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
    if (task == null ||
        task.isMerging ||
        task.status == DownloadStatus.processing)
      return false;
    try {
      final ids = task.requiresMerge
          ? [
              if (task.videoStatus != DownloadStatus.completed)
                task.videoTaskId,
              if (task.audioStatus != DownloadStatus.completed)
                task.audioTaskId,
            ].whereType<String>().toList()
          : [task.taskId].whereType<String>().toList();
      if (ids.isEmpty) return false;
      for (final id in ids) {
        await fd.FlutterDownloader.pause(taskId: id);
      }
      task.status = DownloadStatus.paused;
      if (task.requiresMerge) {
        if (task.videoStatus != DownloadStatus.completed)
          task.videoStatus = DownloadStatus.paused;
        if (task.audioStatus != DownloadStatus.completed)
          task.audioStatus = DownloadStatus.paused;
      }
      await _persistMetadata();
      _notifyListeners();
      return true;
    } catch (error) {
      logger.e('Error pausing download: $error');
      return false;
    }
  }

  Future<bool> resumeDownload(String downloadId) async {
    if (_wifiOnly && !await _hasWifiConnection()) return false;
    final task = _activeTasks[downloadId];
    if (task == null) return false;
    try {
      if (!task.requiresMerge) {
        if (task.taskId == null) return false;
        final id = await fd.FlutterDownloader.resume(taskId: task.taskId!);
        if (id == null) return false;
        task.taskId = id;
      } else {
        if (task.videoStatus == DownloadStatus.paused) {
          if (task.videoTaskId == null) return false;
          final id = await fd.FlutterDownloader.resume(
            taskId: task.videoTaskId!,
          );
          if (id == null) return false;
          task.videoTaskId = id;
          task.taskId = id;
          task.videoStatus = DownloadStatus.pending;
        }
        if (task.audioStatus == DownloadStatus.paused) {
          if (task.audioTaskId == null) return false;
          final id = await fd.FlutterDownloader.resume(
            taskId: task.audioTaskId!,
          );
          if (id == null) return false;
          task.audioTaskId = id;
          task.audioStatus = DownloadStatus.pending;
        }
      }
      task.status = DownloadStatus.pending;
      await _persistMetadata();
      _notifyListeners();
      return true;
    } catch (error) {
      logger.e('Error resuming download: $error');
      return false;
    }
  }

  Future<bool> _refreshYoutubeStreams(AppDownloadTask task) async {
    final source = task.sourceUrl?.trim() ?? '';
    if (source.isEmpty) return true;
    final extractor = YoutubeExtractionService();
    try {
      if (task.isAudioOnly) {
        final options = await extractor.getAudioQualities(source);
        if (options.isEmpty) return false;
        final requested =
            int.tryParse(
              RegExp(r'(\d+)').firstMatch(task.quality)?.group(1) ?? '',
            ) ??
            0;
        final candidates = options
            .where(
              (option) =>
                  option.format.toUpperCase() == task.format.toUpperCase(),
            )
            .toList();
        if (candidates.isEmpty) return false;
        candidates.sort((a, b) {
          final aBitrate =
              int.tryParse(
                RegExp(r'(\d+)').firstMatch(a.bitrate)?.group(1) ?? '',
              ) ??
              0;
          final bBitrate =
              int.tryParse(
                RegExp(r'(\d+)').firstMatch(b.bitrate)?.group(1) ?? '',
              ) ??
              0;
          return aBitrate.compareTo(bBitrate);
        });
        final below = candidates.where((option) {
          final bitrate =
              int.tryParse(
                RegExp(r'(\d+)').firstMatch(option.bitrate)?.group(1) ?? '',
              ) ??
              0;
          return bitrate <= requested;
        }).toList();
        if (requested > 0 && below.isEmpty) return false;
        final chosen = below.isNotEmpty ? below.last : candidates.first;
        task.audioUrl = chosen.audioUrl;
        task.format = chosen.format;
        task.quality = chosen.bitrate;
        return true;
      }
      final options = await extractor.getVideoQualities(source);
      final expectedFormat = task.outputFormat.toUpperCase() == '3GP'
          ? 'MP4'
          : task.format.toUpperCase();
      final compatible = options
          .where(
            (o) =>
                o.format.toUpperCase() == expectedFormat &&
                (task.outputFormat.toUpperCase() != '3GP' ||
                    o.audioUrl.isNotEmpty),
          )
          .toList();
      if (compatible.isEmpty) return false;
      final targetHeight =
          int.tryParse(
            RegExp(r'(\d+)p').firstMatch(task.quality)?.group(1) ?? '',
          ) ??
          0;
      compatible.sort((a, b) {
        final ah =
            int.tryParse(
              RegExp(r'(\d+)p').firstMatch(a.quality)?.group(1) ?? '',
            ) ??
            0;
        final bh =
            int.tryParse(
              RegExp(r'(\d+)p').firstMatch(b.quality)?.group(1) ?? '',
            ) ??
            0;
        if (ah != bh) return ah.compareTo(bh);
        return a.fps.compareTo(b.fps);
      });
      final exact = compatible.where((o) => o.quality == task.quality).toList();
      final below = compatible
          .where(
            (o) =>
                (int.tryParse(
                      RegExp(r'(\d+)p').firstMatch(o.quality)?.group(1) ?? '',
                    ) ??
                    0) <=
                targetHeight,
          )
          .toList();
      if (exact.isEmpty && below.isEmpty) return false;
      final chosen = exact.isNotEmpty ? exact.first : below.last;
      task.videoUrl = chosen.videoUrl;
      task.audioUrl = chosen.audioUrl;
      task.quality = chosen.quality;
      task.format = chosen.format;
      task.requiresMerge = chosen.audioUrl.isNotEmpty;
      if (task.requiresMerge) {
        final output = File(task.savePath);
        final dot = output.path.lastIndexOf('.');
        final base = dot > output.path.lastIndexOf(Platform.pathSeparator)
            ? output.path.substring(0, dot)
            : output.path;
        final ext = chosen.format.toLowerCase().contains('webm')
            ? '.webm'
            : '.mp4';
        task.videoTempPath = '$base.video$ext';
        task.audioTempPath = '$base.audio${ext == '.webm' ? '.webm' : '.m4a'}';
      }
      return true;
    } catch (error) {
      logger.e('Could not refresh YouTube stream URLs for retry: $error');
      return false;
    } finally {
      await extractor.dispose();
    }
  }

  Future<bool> retryDownload(String downloadId) async {
    if (_wifiOnly && !await _hasWifiConnection()) return false;
    final task = _activeTasks[downloadId];
    if (task == null ||
        (task.status != DownloadStatus.failed &&
            task.status != DownloadStatus.cancelled))
      return false;
    try {
      // Remove stale adaptive fragments before selecting new stream URLs. The
      // refreshed manifest may switch this task between adaptive and muxed.
      await _cleanupAdaptiveTempFiles(task);
      if (!await _refreshYoutubeStreams(task)) {
        logger.w(
          'Retry stopped because fresh compatible YouTube streams could not be obtained.',
        );
        return false;
      }
      final documents = await getApplicationDocumentsDirectory();
      final root = Directory('${documents.path}/TubeArena/Downloads');
      await root.create(recursive: true);
      final target = File(task.savePath);
      final prefix = '${root.absolute.path}${Platform.pathSeparator}';
      if (!target.absolute.path.startsWith(prefix)) return false;
      await target.parent.create(recursive: true);
      if (await target.exists()) await target.delete();

      if (task.requiresMerge) {
        // Clear stale native task IDs and statuses before enqueuing either
        // stream. A fast callback from the new video task must never be
        // mistaken for completion/failure of the previous audio task.
        task.taskId = null;
        task.videoTaskId = null;
        task.audioTaskId = null;
        task.videoStatus = DownloadStatus.pending;
        task.audioStatus = DownloadStatus.pending;
        task.videoProgress = 0;
        task.audioProgress = 0;
        task.progress = 0;
        task.isMerging = false;
        await _persistMetadata();

        final videoUri = Uri.tryParse(task.videoUrl);
        final audioUri = Uri.tryParse(task.audioUrl);
        if (task.videoTempPath == null ||
            task.audioTempPath == null ||
            videoUri == null ||
            audioUri == null ||
            !['http', 'https'].contains(videoUri.scheme) ||
            videoUri.host.isEmpty ||
            !['http', 'https'].contains(audioUri.scheme) ||
            audioUri.host.isEmpty)
          return false;
        for (final path in [task.videoTempPath!, task.audioTempPath!]) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        final videoId = await fd.FlutterDownloader.enqueue(
          url: task.videoUrl,
          savedDir: root.path,
          fileName: File(task.videoTempPath!).uri.pathSegments.last,
          showNotification: false,
          openFileFromNotification: false,
          saveInPublicStorage: false,
        );
        if (videoId == null) return false;
        task.videoTaskId = videoId;
        task.taskId = videoId;
        task.videoStatus = DownloadStatus.pending;
        task.videoProgress = 0;
        String? audioId;
        try {
          audioId = await fd.FlutterDownloader.enqueue(
            url: task.audioUrl,
            savedDir: root.path,
            fileName: File(task.audioTempPath!).uri.pathSegments.last,
            showNotification: false,
            openFileFromNotification: false,
            saveInPublicStorage: false,
          );
        } catch (error) {
          logger.e(
            'Could not queue adaptive audio stream during retry: $error',
          );
        }
        if (audioId == null) {
          // Do not leave the successfully queued video stream running alone.
          try {
            await fd.FlutterDownloader.cancel(taskId: videoId);
          } catch (error) {
            logger.w('Could not cancel partial adaptive retry: $error');
          }
          task.taskId = null;
          task.videoTaskId = null;
          task.audioTaskId = null;
          task.videoStatus = DownloadStatus.failed;
          task.audioStatus = DownloadStatus.failed;
          task.status = DownloadStatus.failed;
          task.progress = 0;
          await _persistMetadata();
          _notifyListeners();
          return false;
        }
        task.audioTaskId = audioId;
        task.audioStatus = DownloadStatus.pending;
        task.audioProgress = 0;
      } else {
        final url = task.isAudioOnly ? task.audioUrl : task.videoUrl;
        final uri = Uri.tryParse(url);
        if (uri == null ||
            !uri.hasScheme ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty)
          return false;
        final id = await fd.FlutterDownloader.enqueue(
          url: url,
          savedDir: root.path,
          fileName: target.uri.pathSegments.last,
          showNotification: true,
          openFileFromNotification: false,
          saveInPublicStorage: false,
        );
        if (id == null) return false;
        task.taskId = id;
      }
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
    if (task == null ||
        task.isMerging ||
        task.status == DownloadStatus.processing)
      return false;
    try {
      final ids = task.requiresMerge
          ? [
              if (task.videoStatus != DownloadStatus.completed)
                task.videoTaskId,
              if (task.audioStatus != DownloadStatus.completed)
                task.audioTaskId,
            ].whereType<String>().toList()
          : [task.taskId].whereType<String>().toList();
      if (ids.isEmpty) return false;
      var success = true;
      for (final id in ids) {
        try {
          await fd.FlutterDownloader.cancel(taskId: id);
        } catch (_) {
          success = false;
        }
      }
      if (success) {
        task.status = DownloadStatus.cancelled;
        if (task.requiresMerge) await _cleanupAdaptiveTempFiles(task);
        await _persistMetadata();
        _notifyListeners();
      }
      return success;
    } catch (error) {
      logger.e('Error cancelling download: $error');
      return false;
    }
  }

  Future<void> forgetTask(String downloadId) async {
    final task = _activeTasks.remove(downloadId);
    if (task != null && task.requiresMerge) {
      final documents = await getApplicationDocumentsDirectory();
      final root = Directory('${documents.path}/TubeArena/Downloads');
      final prefix = '${root.absolute.path}${Platform.pathSeparator}';
      for (final path in [task.videoTempPath, task.audioTempPath]) {
        if (path == null) continue;
        final file = File(path);
        if (file.absolute.path.startsWith(prefix) && await file.exists()) {
          await file.delete();
        }
      }
    }
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
