import 'package:logger/logger.dart';

/// Explicit placeholder until a maintained FFmpeg integration is selected.
/// These methods deliberately return false instead of pretending to process media.
class FFmpegMergeService {
  static final FFmpegMergeService _instance = FFmpegMergeService._internal();
  final Logger logger = Logger();

  factory FFmpegMergeService() => _instance;

  FFmpegMergeService._internal();

  Future<bool> mergeVideoAndAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    required String quality,
  }) async {
    logger.w('Audio/video merging is not implemented in this build.');
    return false;
  }

  Future<bool> convertVideo({
    required String inputPath,
    required String outputPath,
    required String codec,
    required String bitrate,
  }) async {
    logger.w('Video conversion is not implemented in this build.');
    return false;
  }

  Future<bool> extractAudio({
    required String videoPath,
    required String audioOutputPath,
    required String format,
  }) async {
    logger.w('Audio extraction/conversion is not implemented in this build.');
    return false;
  }
}
