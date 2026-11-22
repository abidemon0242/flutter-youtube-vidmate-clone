import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
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

  /// Converts a downloaded audio-only stream to the selected output format.
  /// Returns false if the installed FFmpeg build lacks the required encoder.
  Future<bool> convertAudio({
    required String inputPath,
    required String outputPath,
    required String format,
    required String bitrate,
    int? sourceBitrateKbps,
  }) async {
    if (_samePath(inputPath, outputPath) || !await File(inputPath).exists()) {
      return false;
    }
    final normalized = format.toLowerCase();
    const codecs = <String, String>{
      'mp3': 'libmp3lame',
      'm4a': 'aac',
      'aac': 'aac',
      'opus': 'libopus',
      'flac': 'flac',
      'wav': 'pcm_s16le',
    };
    final codec = codecs[normalized];
    if (codec == null) return false;

    await File(outputPath).parent.create(recursive: true);
    final args = <String>['-y', '-i', inputPath, '-map', '0:a:0', '-vn', '-c:a', codec];
    if (normalized != 'flac' && normalized != 'wav') {
      if (bitrate == 'Best available') {
        final sourceRate = sourceBitrateKbps;
        if (sourceRate == null || sourceRate <= 0) {
          _logger.w('Cannot select Best available: source bitrate is unknown.');
          return false;
        }
        final targetRate = sourceRate.clamp(64, 320);
        args.addAll(['-b:a', '${targetRate}k']);
      } else {
        final kbps = int.tryParse(bitrate.replaceAll(' kbps', ''));
        if (kbps == null || kbps < 64 || kbps > 320) return false;
        args.addAll(['-b:a', '${kbps}k']);
      }
    }
    if (normalized == 'm4a') args.addAll(['-f', 'ipod']);
    if (normalized == 'aac') args.addAll(['-f', 'adts']);
    args.add(outputPath);

    try {
      final session = await FFmpegKit.executeWithArguments(args);
      final code = await session.getReturnCode();
      final output = File(outputPath);
      if (ReturnCode.isSuccess(code) && await output.exists()) {
        return await output.length() > 0;
      }
      _logger.e('Audio conversion failed (${code?.getValue()}): ${await session.getOutput()}');
    } catch (error, stackTrace) {
      _logger.e('Audio conversion failed', error: error, stackTrace: stackTrace);
    }
    final partial = File(outputPath);
    if (await partial.exists()) await partial.delete();
    return false;
  }
}
