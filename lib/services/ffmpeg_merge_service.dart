import 'dart:async';
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

  static final Map<String, int?> _activeSessions = {};
  static final Set<String> _startingPaths = {};
  static final Set<String> _cancelRequested = {};

  /// Cancels the FFmpeg job writing [outputPath]. A pending cancellation is
  /// remembered in case the FFmpeg session is still being created.
  static Future<void> cancelForOutput(String outputPath) async {
    final path = File(outputPath).absolute.path;
    final sessionId = _activeSessions[path];
    if (sessionId != null) {
      try {
        await FFmpegKit.cancel(sessionId);
      } catch (error) {
        Logger().w('Could not request FFmpeg cancellation: $error');
      }
    } else if (_startingPaths.contains(path)) {
      _cancelRequested.add(path);
    }
  }

  Future<bool> _execute(List<String> args, String outputPath) async {
    final path = File(outputPath).absolute.path;
    final completed = Completer<dynamic>();
    _startingPaths.add(path);
    try {
      final session = await FFmpegKit.executeWithArgumentsAsync(
        args,
        (finishedSession) {
          if (!completed.isCompleted) completed.complete(finishedSession);
        },
      );
      final sessionId = session.getSessionId();
      if (sessionId == null) {
        throw StateError('FFmpeg did not return a session ID.');
      }
      _startingPaths.remove(path);
      _activeSessions[path] = sessionId;
      if (_cancelRequested.remove(path)) {
        try {
          await FFmpegKit.cancel(sessionId);
        } catch (error) {
          _logger.w('Could not request FFmpeg cancellation: $error');
        }
      }
      final finishedSession = await completed.future;
      final code = await finishedSession.getReturnCode();
      return ReturnCode.isSuccess(code);
    } finally {
      _startingPaths.remove(path);
      _activeSessions.remove(path);
      _cancelRequested.remove(path);
    }
  }

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
      if (await _execute(args, outputPath)) return true;
      _logger.e('FFmpeg merge failed or was canceled.');
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
        final targetRate = sourceRate.clamp(1, 320);
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
      final success = await _execute(args, outputPath);
      final output = File(outputPath);
      if (success && await output.exists()) {
        return await output.length() > 0;
      }
      _logger.e('Audio conversion failed or was canceled.');
    } catch (error, stackTrace) {
      _logger.e('Audio conversion failed', error: error, stackTrace: stackTrace);
    }
    final partial = File(outputPath);
    if (await partial.exists()) await partial.delete();
    return false;
  }
}
