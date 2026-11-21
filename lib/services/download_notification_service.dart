import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/downloads_provider.dart';

/// What the ongoing download notification shows.
@immutable
class DownloadProgressInfo {
  const DownloadProgressInfo({required this.title, required this.text, required this.percent});
  final String title;
  final String text;

  /// 0-100, or -1 for an indeterminate bar (queued, merging, unknown size).
  final int percent;

  @override
  bool operator ==(Object other) =>
      other is DownloadProgressInfo && other.title == title && other.text == text && other.percent == percent;

  @override
  int get hashCode => Object.hash(title, text, percent);
}

/// Platform side of download notifications.
abstract class DownloadNotifier {
  /// Shows or updates the ongoing notification and keeps the foreground
  /// service running so Android doesn't stop downloads in the background.
  Future<void> showProgress(DownloadProgressInfo info);

  /// Removes the ongoing notification and stops the foreground service.
  Future<void> stopProgress();

  /// A one-off notification for a finished or failed download.
  Future<void> showResult({required String id, required String title, required bool success, String? message});
}

/// Used in tests and on platforms without notifications.
class NoopDownloadNotifier implements DownloadNotifier {
  const NoopDownloadNotifier();
  @override
  Future<void> showProgress(DownloadProgressInfo info) async {}
  @override
  Future<void> stopProgress() async {}
  @override
  Future<void> showResult({required String id, required String title, required bool success, String? message}) async {}
}

/// Talks to DownloadService (a dataSync foreground service) in MainActivity.
class MethodChannelDownloadNotifier implements DownloadNotifier {
  MethodChannelDownloadNotifier({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.tubearena.app/download_notifications';
  final MethodChannel _channel;
  bool _askedPermission = false;

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (error) {
      debugPrint('Download notification $method failed: $error');
    }
  }

  @override
  Future<void> showProgress(DownloadProgressInfo info) async {
    if (!_askedPermission && Platform.isAndroid) {
      _askedPermission = true;
      try {
        // Android 13+ asks once; older versions grant it automatically.
        await Permission.notification.request();
      } catch (_) {}
    }
    await _call('showProgress', {'title': info.title, 'text': info.text, 'percent': info.percent});
  }

  @override
  Future<void> stopProgress() => _call('stopProgress');

  @override
  Future<void> showResult({required String id, required String title, required bool success, String? message}) =>
      _call('showResult', {'id': id, 'title': title, 'success': success, 'message': message});
}

/// Watches [DownloadsProvider] and mirrors it into notifications, so the
/// provider itself stays free of platform code.
class DownloadNotificationController {
  DownloadNotificationController(
    this._downloads,
    this._notifier, {
    this.minInterval = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    for (final entry in _downloads.items) {
      _lastStatus[entry.id] = entry.status;
    }
    _downloads.addListener(_onChanged);
    _onChanged();
  }

  final DownloadsProvider _downloads;
  final DownloadNotifier _notifier;

  /// Android drops notification updates sent faster than about once a second.
  final Duration minInterval;
  final DateTime Function() _clock;

  final Map<String, DownloadStatus> _lastStatus = {};
  DownloadProgressInfo? _shown;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  static bool _wasRunning(DownloadStatus? status) =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading || status == DownloadStatus.merging;

  void _onChanged() {
    if (_disposed) return;
    final items = _downloads.items;
    for (final entry in items) {
      final before = _lastStatus[entry.id];
      if (before != entry.status && _wasRunning(before)) {
        if (entry.status == DownloadStatus.completed) {
          _notifier.showResult(id: entry.id, title: entry.title, success: true, message: 'Download complete');
        } else if (entry.status == DownloadStatus.failed) {
          _notifier.showResult(id: entry.id, title: entry.title, success: false, message: entry.error);
        }
      }
      _lastStatus[entry.id] = entry.status;
    }
    _lastStatus.removeWhere((id, _) => items.every((e) => e.id != id));

    final info = progressInfo(items, waitingForWifi: _downloads.waitingForWifi);
    if (info == null) {
      if (_shown != null) {
        _shown = null;
        _notifier.stopProgress();
      }
      return;
    }
    final now = _clock();
    final structural = _shown == null || _shown!.title != info.title || (_shown!.percent < 0) != (info.percent < 0);
    if (info == _shown || (!structural && now.difference(_lastUpdate) < minInterval)) return;
    _shown = info;
    _lastUpdate = now;
    _notifier.showProgress(info);
  }

  /// Summary of all active downloads, or null when nothing is active.
  static DownloadProgressInfo? progressInfo(List<DownloadEntry> items, {bool waitingForWifi = false}) {
    final active = items.where((e) => e.isActive).toList();
    if (active.isEmpty) return null;
    final title = active.length == 1 ? active.single.title : 'Downloading ${active.length} files';
    final running = active.where((e) => e.status == DownloadStatus.downloading).toList();
    if (running.isEmpty) {
      final merging = active.any((e) => e.status == DownloadStatus.merging);
      final text = merging ? 'Combining video and audio...' : (waitingForWifi ? 'Waiting for Wi-Fi' : 'Waiting...');
      return DownloadProgressInfo(title: title, text: text, percent: -1);
    }
    final total = active.fold<int>(0, (sum, e) => sum + e.totalBytes);
    final received = active.fold<int>(0, (sum, e) => sum + e.receivedBytes);
    if (total <= 0) return DownloadProgressInfo(title: title, text: 'Downloading...', percent: -1);
    final percent = (received * 100 ~/ total).clamp(0, 100);
    return DownloadProgressInfo(
      title: title,
      text: '$percent% · ${formatByteCount(received)} of ${formatByteCount(total)}',
      percent: percent,
    );
  }

  void dispose() {
    _disposed = true;
    _downloads.removeListener(_onChanged);
    if (_shown != null) _notifier.stopProgress();
  }
}
