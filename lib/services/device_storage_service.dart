import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Where a file saved with "Save to phone" ended up.
enum PublicCollection { movies, music }

/// Thrown with a message that is safe to show to users.
class SaveToPhoneException implements Exception {
  const SaveToPhoneException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _audioExtensions = {'m4a', 'mp3', 'opus', 'ogg', 'aac', 'flac', 'wav', 'weba'};

String fileExtension(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
}

bool isAudioFile(String path) => _audioExtensions.contains(fileExtension(path));

/// MIME type used for MediaStore. Video containers go to Movies, audio to Music.
String mimeTypeFor(String path, {bool? audio}) {
  final ext = fileExtension(path);
  final isAudio = audio ?? isAudioFile(path);
  return switch (ext) {
    'mp4' => isAudio ? 'audio/mp4' : 'video/mp4',
    'm4a' => 'audio/mp4',
    'webm' || 'weba' => isAudio || ext == 'weba' ? 'audio/webm' : 'video/webm',
    'mkv' => 'video/x-matroska',
    'mp3' => 'audio/mpeg',
    'opus' || 'ogg' => 'audio/ogg',
    'aac' => 'audio/aac',
    'flac' => 'audio/flac',
    'wav' => 'audio/wav',
    _ => isAudio ? 'audio/*' : 'video/*',
  };
}

/// Native helpers in MainActivity: free space (StatFs) and copying files to
/// public storage through MediaStore.
class DeviceStorageService {
  DeviceStorageService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.tubearena.app/storage';
  final MethodChannel _channel;
  int? _sdkInt;

  /// Free bytes on the volume holding [path], or null if it can't be read.
  Future<int?> freeBytes(String path) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('freeBytes', {'path': path});
    } catch (error) {
      debugPrint('Could not read free space: $error');
      return null;
    }
  }

  Future<int> _sdk() async => _sdkInt ??= await _channel.invokeMethod<int>('sdkInt') ?? 0;

  /// Copies [path] into Movies/Tube Arena (video) or Music/Tube Arena (audio)
  /// so it shows in Gallery / Files and survives uninstalling the app.
  Future<PublicCollection> saveToPhone(String path, {bool? audio}) async {
    if (!Platform.isAndroid) throw const SaveToPhoneException('Saving to the phone is only available on Android.');
    if (!await File(path).exists()) throw const SaveToPhoneException('The file is no longer on this device.');
    final isAudio = audio ?? isAudioFile(path);
    try {
      // Android 9 and older need the storage permission; MediaStore needs none.
      if (await _sdk() < 29) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw const SaveToPhoneException('Storage permission is needed to save to the phone.');
        }
      }
      await _channel.invokeMethod<String>('saveToPublic', {
        'path': path,
        'name': path.split(RegExp(r'[\\/]')).last,
        'mimeType': mimeTypeFor(path, audio: isAudio),
        'audio': isAudio,
      });
      return isAudio ? PublicCollection.music : PublicCollection.movies;
    } on SaveToPhoneException {
      rethrow;
    } catch (error) {
      debugPrint('Save to phone failed: $error');
      throw const SaveToPhoneException('Could not save to the phone. Check free space and try again.');
    }
  }
}

String savedToPhoneMessage(PublicCollection collection) =>
    collection == PublicCollection.music ? 'Saved to Music/Tube Arena.' : 'Saved to Movies/Tube Arena.';
