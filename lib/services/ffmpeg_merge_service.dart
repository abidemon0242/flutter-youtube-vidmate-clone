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

  Future<bool> _prepareOutput(String path) async {
    try {
      if (path.trim().isEmpty || await File(path).exists()) return false;
      await Directory(File(path).parent.path).create(recursive: true);
      return true;
    } catch (error, stackTrace) {
      logger.e('Could not prepare media output', error: error, stackTrace: stackTrace);
      return false;
    }
  }

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
    bool normalizeForMp4 = false,
  }) async {
    if (_samePath(videoPath, outputPath) ||
        _samePath(audioPath, outputPath) ||
        !await File(videoPath).exists() ||
        !await File(audioPath).exists() ||
        !await _prepareOutput(outputPath)) {
      logger.e('Cannot merge: an input file does not exist.');
      return false;
    }
    logger.i('Merging streams at $quality to $outputPath');
    final codecArguments = normalizeForMp4
        ? ['-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '23', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart']
        : ['-c:v', 'copy', '-c:a', 'copy'];
    return _run([
      '-n', '-i', videoPath, '-i', audioPath,
      '-map', '0:v:0', '-map', '1:a:0',
      ...codecArguments,
      '-shortest', outputPath,
    ]);
  }

  Future<bool> convertVideo({
    required String inputPath,
    required String outputPath,
    required String codec,
    required String bitrate,
  }) async {
    if (_samePath(inputPath, outputPath) ||
        !await File(inputPath).exists() ||
        !await _prepareOutput(outputPath)) return false;
    return _run([
      '-n', '-i', inputPath, '-c:v', codec, '-b:v', bitrate,
      '-c:a', 'aac', '-b:a', '128k', outputPath,
    ]);
  }

  /// Converts an MP4 source into a conservative 3GP profile for older
  /// feature phones: CIF-or-smaller H.263 video at 15 fps and AMR-NB mono audio.
  /// The configured FFmpeg build must include libopencore-amrnb.
  Future<bool> convertTo3gp({
    required String inputPath,
    required String outputPath,
  }) async {
    if (_samePath(inputPath, outputPath) ||
        !await File(inputPath).exists() ||
        !await _prepareOutput(outputPath)) return false;
    return _run([
      '-n', '-i', inputPath,
      '-vf', 'scale=352:288:force_original_aspect_ratio=decrease,pad=352:288:(ow-iw)/2:(oh-ih)/2',
      '-r', '15', '-c:v', 'h263', '-b:v', '256k',
      '-c:a', 'libopencore_amrnb', '-ar', '8000', '-ac', '1', '-b:a', '12.2k',
      '-f', '3gp', outputPath,
    ]);
  }

  Future<bool> extractAudio({
    required String videoPath,
    required String audioOutputPath,
    required String format,
  }) async {
    if (_samePath(videoPath, audioOutputPath) ||
        !await File(videoPath).exists()) return false;
    final normalizedFormat = format.toLowerCase();
    if (normalizedFormat != 'mp3' && normalizedFormat != 'm4a') {
      logger.e('Unsupported audio format: $format');
      return false;
    }
    if (!await _prepareOutput(audioOutputPath)) return false;
    return _run([
      '-n', '-i', videoPath, '-vn', '-codec:a',
      normalizedFormat == 'mp3' ? 'libmp3lame' : 'aac',
      '-b:a', '320k', audioOutputPath,
    ]);
  }
}
