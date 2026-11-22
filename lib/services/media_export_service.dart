import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ExportMediaKind { audio, video }

class MediaExportService {
  static const MethodChannel _channel = MethodChannel(
    'com.tubearena.app/media_export',
  );

  static String _preferenceKey(ExportMediaKind kind) =>
      'library_export_destination_${kind.name}';

  Future<ExportMediaKind> detectKind(String path) async {
    final name = path.toLowerCase();
    const audioExtensions = [
      '.mp3', '.m4a', '.aac', '.wav', '.ogg', '.flac', '.opus',
    ];
    const videoExtensions = [
      '.mp4', '.m4v', '.mov', '.mkv', '.3gp', '.avi', '.webm',
    ];

    if (audioExtensions.any(name.endsWith)) return ExportMediaKind.audio;
    if (name.endsWith('.webm') ||
        name.endsWith('.mkv') ||
        name.endsWith('.mp4') ||
        name.endsWith('.m4v') ||
        name.endsWith('.mov') ||
        name.endsWith('.3gp') ||
        name.endsWith('.avi')) {
      try {
        final session = await FFprobeKit.getMediaInformation(path);
        final information = await session.getMediaInformation();
        final streams = information?.getStreams() ?? const [];
        final hasAudio = streams.any((stream) => stream.getType() == 'audio');
        final hasVideo = streams.any((stream) => stream.getType() == 'video');
        if (hasAudio && !hasVideo) return ExportMediaKind.audio;
        if (hasVideo) return ExportMediaKind.video;
      } catch (_) {
        // Fall back to the known container extension below.
      }
    }
    if (videoExtensions.any(name.endsWith)) return ExportMediaKind.video;
    throw const FormatException('This file is not a supported audio or video file.');
  }

  Future<String?> rememberedDestination(ExportMediaKind kind) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_preferenceKey(kind));
  }

  Future<void> rememberDestination(
    ExportMediaKind kind,
    String destination,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey(kind), destination);
  }

  Future<String> exportFile({
    required String sourcePath,
    required String destination,
    required ExportMediaKind kind,
  }) async {
    if (!await File(sourcePath).exists()) {
      throw const FileSystemException('The source file no longer exists.');
    }
    final sdk = await _channel.invokeMethod<int>('getAndroidSdkInt') ?? 0;
    if (sdk > 0 && sdk < 29) {
      final permission = await Permission.storage.request();
      if (!permission.isGranted) {
        throw PlatformException(
          code: 'STORAGE_PERMISSION_DENIED',
          message: 'Storage permission is required to save media on this Android version.',
        );
      }
    }
    final result = await _channel.invokeMethod<String>('exportMedia', {
      'sourcePath': sourcePath,
      'destination': destination,
      'mediaKind': kind.name,
    });
    if (result == null || result.isEmpty) {
      throw PlatformException(
        code: 'EXPORT_FAILED',
        message: 'Android did not return the exported file location.',
      );
    }
    return result;
  }
}
