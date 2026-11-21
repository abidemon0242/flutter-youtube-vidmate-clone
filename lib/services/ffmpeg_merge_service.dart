import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:logger/logger.dart';

/// Joins separately downloaded video and audio streams into one file.
///
/// Streams are copied without re-encoding, so merging is fast and lossless.
/// The output container (mp4, webm or mkv) is chosen by the caller so that
/// it can hold both codecs.
class FFmpegMergeService {
  FFmpegMergeService();

  final _logger = Logger();

  bool _samePath(String a, String b) => File(a).absolute.path == File(b).absolute.path;

  Future<bool> mergeVideoAndAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    if (_samePath(videoPath, outputPath) ||
        _samePath(audioPath, outputPath) ||
        !await File(videoPath).exists() ||
        !await File(audioPath).exists()) {
      _logger.e('Cannot merge: an input file is missing.');
      return false;
    }
    await File(outputPath).parent.create(recursive: true);
    final args = [
      '-y',
      '-i',
      videoPath,
      '-i',
      audioPath,
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      '-c',
      'copy',
      if (outputPath.endsWith('.mp4')) ...['-movflags', '+faststart'],
      outputPath,
    ];
    try {
      final session = await FFmpegKit.executeWithArguments(args);
      final code = await session.getReturnCode();
      if (ReturnCode.isSuccess(code)) return true;
      _logger.e('FFmpeg merge failed (${code?.getValue()}): ${await session.getOutput()}');
    } catch (error, stackTrace) {
      _logger.e('FFmpeg merge failed', error: error, stackTrace: stackTrace);
    }
    final partial = File(outputPath);
    if (await partial.exists()) await partial.delete();
    return false;
  }
}
