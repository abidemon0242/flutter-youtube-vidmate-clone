import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:logger/logger.dart';

/// Media processing helpers backed by FFmpegKit.
///
/// These operations require a platform where the configured FFmpegKit package
/// is available. A failed command is reported as false; it is never reported
/// as successful merely because the command was started.
class FFmpegMergeService {
  static final FFmpegMergeService _instance = FFmpegMergeService._internal();
  final logger = Logger();

  factory FFmpegMergeService() => _instance;

  FFmpegMergeService._internal();


  bool _samePath(String first, String second) =>
      File(first).absolute.path == File(second).absolute.path;

  Future<bool> _run(List<String> arguments) async {
    try {
      final session = await FFmpegKit.executeWithArguments(arguments);
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) return true;
      logger.e('FFmpeg failed: ${await session.getFailStackTrace()}');
    } catch (error, stackTrace) {
      logger.e('FFmpeg operation failed', error: error, stackTrace: stackTrace);
    }
    return false;
  }

  Future<bool> mergeVideoAndAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    required String quality,
  }) async {
    if (_samePath(videoPath, outputPath) ||
        _samePath(audioPath, outputPath) ||
        !await File(videoPath).exists() ||
        !await File(audioPath).exists()) {
      logger.e('Cannot merge: an input file does not exist.');
      return false;
    }
    await Directory(File(outputPath).parent.path).create(recursive: true);
    logger.i('Merging streams at $quality to $outputPath');
    return _run([
      '-y', '-i', videoPath, '-i', audioPath,
      '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'copy', '-c:a', 'aac',
      '-shortest', outputPath,
    ]);
  }

  Future<bool> convertVideo({
    required String inputPath,
    required String outputPath,
    required String codec,
    required String bitrate,
  }) async {
    if (_samePath(inputPath, outputPath) || !await File(inputPath).exists()) return false;
    await Directory(File(outputPath).parent.path).create(recursive: true);
    return _run([
      '-y', '-i', inputPath, '-c:v', codec, '-b:v', bitrate,
      '-c:a', 'aac', '-b:a', '128k', outputPath,
    ]);
  }

  /// Re-encodes a video to a conservative feature-phone playback profile.
  Future<bool> convertForButtonPhone({
    required String inputPath,
    required String outputPath,
  }) async {
    if (_samePath(inputPath, outputPath) || !await File(inputPath).exists()) {
      logger.e('Cannot convert: input file is missing or output would overwrite it.');
      return false;
    }
    await Directory(File(outputPath).parent.path).create(recursive: true);
    final converted = await _run([
      '-y', '-i', inputPath,
      '-map', '0:v:0', '-map', '0:a?',
      '-vf', 'scale=320:240:force_original_aspect_ratio=decrease,pad=320:240:(ow-iw)/2:(oh-ih)/2,setsar=1',
      '-r', '15',
      '-c:v', 'libx264', '-profile:v', 'baseline', '-level', '3.0',
      '-pix_fmt', 'yuv420p', '-b:v', '300k', '-maxrate', '400k', '-bufsize', '600k',
      '-c:a', 'aac', '-b:a', '64k', '-ac', '2', '-ar', '44100',
      '-movflags', '+faststart', '-f', 'mp4', outputPath,
    ]);
    if (!converted) return false;
    final output = File(outputPath);
    return await output.exists() && await output.length() >= 1024;
  }

  Future<bool> extractAudio({
    required String videoPath,
    required String audioOutputPath,
    required String format,
  }) async {
    if (_samePath(videoPath, audioOutputPath) || !await File(videoPath).exists()) return false;
    final normalizedFormat = format.toLowerCase();
    if (normalizedFormat != 'mp3' && normalizedFormat != 'm4a') {
      logger.e('Unsupported audio format: $format');
      return false;
    }
    await Directory(File(audioOutputPath).parent.path).create(recursive: true);
    return _run([
      '-y', '-i', videoPath, '-vn', '-codec:a',
      normalizedFormat == 'mp3' ? 'libmp3lame' : 'aac',
      '-b:a', '320k', audioOutputPath,
    ]);
  }
}
