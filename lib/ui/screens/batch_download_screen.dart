import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';
import '../../services/background_download_service.dart';
import '../../services/youtube_extraction_service.dart';

class BatchDownloadScreen extends StatefulWidget {
  const BatchDownloadScreen({super.key});

  @override
  State<BatchDownloadScreen> createState() => _BatchDownloadScreenState();
}

class _BatchDownloadScreenState extends State<BatchDownloadScreen> {
  final TextEditingController _urlsController = TextEditingController();
  late final YoutubeExtractionService _extractionService;
  bool _isProcessing = false;
  String _preferredQuality = '360p';
  String _preferredFormat = 'MP4';
  List<VideoQualityOption> _previewOptions = const [];
  bool _isPreviewLoading = false;
  bool _audioOnly = false;
  bool _wifiOnly = false;
  String _status = 'Paste one video link per line.';

  @override
  void initState() {
    super.initState();
    _extractionService = YoutubeExtractionService();
    _wifiOnly = BackgroundDownloadService().wifiOnly;
  }

  @override
  void dispose() {
    _urlsController.dispose();
    _extractionService.dispose();
    super.dispose();
  }

  List<String> _readUrls() {
    final seen = <String>{};
    return _urlsController.text
        .split(RegExp(r'\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && seen.add(value))
        .toList();
  }

  VideoQualityOption _chooseQuality(List<VideoQualityOption> options) {
    final matchingFormat = options.where((option) => option.format.toUpperCase() == _preferredFormat).toList();
    if (matchingFormat.isEmpty) {
      throw Exception('No $_preferredFormat stream is available for the selected video.');
    }
    final ranked = [...matchingFormat]
      ..sort((a, b) {
        final aHeight = int.tryParse(RegExp(r'(\d+)p').firstMatch(a.quality)?.group(1) ?? '') ?? 0;
        final bHeight = int.tryParse(RegExp(r'(\d+)p').firstMatch(b.quality)?.group(1) ?? '') ?? 0;
        return aHeight.compareTo(bHeight);
      });

    final targetHeight = int.tryParse(_preferredQuality.replaceAll('p', '')) ?? 720;
    final atOrBelowTarget = ranked.where((option) {
      final height = int.tryParse(RegExp(r'(\d+)p').firstMatch(option.quality)?.group(1) ?? '');
      return height != null && height <= targetHeight;
    }).toList();

    if (atOrBelowTarget.isEmpty) {
      throw Exception('No $_preferredFormat stream is available at or below $_preferredQuality.');
    }
    return atOrBelowTarget.last;
  }

  Future<void> _previewQualities() async {
    final urls = _readUrls();
    if (urls.isEmpty) {
      setState(() => _status = 'Add a video URL first to check available formats and sizes.');
      return;
    }
    setState(() {
      _isPreviewLoading = true;
      _previewOptions = const [];
      _status = 'Checking available resolutions and file sizes…';
    });
    try {
      final options = await _extractionService.getVideoQualities(urls.first);
      if (!mounted) return;
      final matching = options
          .where((option) => option.format.toUpperCase() == _preferredFormat)
          .toList();
      setState(() {
        _previewOptions = matching;
        _isPreviewLoading = false;
        if (matching.isEmpty) {
          _status = 'This video does not provide a $_preferredFormat stream.';
        } else {
          final selected = _chooseQuality(matching);
          _status = 'Available selection: ${selected.quality} ${selected.format} • ${selected.fileSize}';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPreviewLoading = false;
        _status = 'Could not check video formats: $error';
      });
    }
  }

  Future<void> _startBatch() async {
    final urls = _readUrls();
    if (urls.isEmpty) {
      setState(() => _status = 'Enter at least one YouTube video URL.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Checking ${urls.length} link(s)…';
    });

    final downloads = context.read<DownloadsProvider>();
    final downloadService = BackgroundDownloadService();
    late final String documentsPath;
    try {
      documentsPath = (await getApplicationDocumentsDirectory()).path;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = 'Could not access the app download folder: $error';
      });
      return;
    }
    var queued = 0;
    final failures = <String>[];
    final seenVideoIds = <String>{};

    for (var index = 0; index < urls.length; index++) {
      if (!mounted) return;
      final url = urls[index];
      setState(() => _status = 'Checking ${index + 1} of ${urls.length}…');

      try {
        final metadata = await _extractionService.extractVideoMetadata(url);
        final videoId = metadata['videoId'] as String;
        final title = (metadata['title'] as String?)?.trim().isNotEmpty == true
            ? (metadata['title'] as String).trim()
            : videoId;
        if (!seenVideoIds.add(videoId)) {
          failures.add('$title: duplicate link in this batch');
          continue;
        }

        final normalizedSafeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        // Keep the UI's expected path identical to BackgroundDownloadService,
        // which caps sanitized titles at 80 characters.
        final safeTitle = normalizedSafeTitle.length > 80
            ? normalizedSafeTitle.substring(0, 80)
            : normalizedSafeTitle;
        if (_audioOnly) {
          final audioOptions = await _extractionService.getAudioQualities(url);
          if (audioOptions.isEmpty) {
            failures.add('$title: no compatible audio stream');
            continue;
          }
          final audio = audioOptions.first;
          final downloadId = 'youtube-audio-$videoId';
          if (downloads.items.any((item) => item.id == downloadId)) {
            failures.add('$title: audio is already queued');
            continue;
          }
          final safeId = downloadId.replaceAll(RegExp(r'[^\w-]'), '');
          final fileBase = safeTitle.isEmpty ? safeId : '${safeTitle}_$safeId';
          final extension = audio.format.toLowerCase().contains('webm')
              ? 'webm'
              : audio.format.toLowerCase().contains('aac')
                  ? 'aac'
                  : 'm4a';
          final fileName = '$fileBase.$extension';
          final savePath = '${documentsPath}/TubeArena/Downloads/$fileName';
          final taskId = await downloadService.startDownload(
            id: downloadId,
            title: title,
            videoUrl: '',
            audioUrl: audio.audioUrl,
            quality: audio.bitrate,
            format: audio.format,
            isAudioOnly: true,
          );
          if (taskId == null) {
            failures.add('$title: audio download could not be queued');
            continue;
          }
          downloads.addDownload(
            DownloadEntry(
              id: downloadId,
              title: title,
              url: audio.audioUrl,
              size: audio.fileSize,
              format: 'Audio ${audio.bitrate} ${audio.format}',
              progress: 0,
              savedPath: savePath,
              isAudioOnly: true,
            ),
          );
          queued++;
          continue;
        }

        final options = await _extractionService.getVideoQualities(url);
        if (options.isEmpty) {
          failures.add('$title: no compatible video stream');
          continue;
        }
        final quality = _chooseQuality(options);
        final downloadId = 'youtube-$videoId';
        if (downloads.items.any((item) => item.id == downloadId)) {
          failures.add('$title: video is already queued');
          continue;
        }
        final safeId = downloadId.replaceAll(RegExp(r'[^\w-]'), '');
        final fileBase = safeTitle.isEmpty ? safeId : '${safeTitle}_$safeId';
        final extension = quality.format.toLowerCase().contains('webm') ? 'webm' : 'mp4';
        final fileName = '$fileBase.$extension';
        final savePath = '${documentsPath}/TubeArena/Downloads/$fileName';

        final taskId = await downloadService.startDownload(
          id: downloadId,
          title: title,
          videoUrl: quality.videoUrl,
          audioUrl: quality.audioUrl,
          quality: quality.quality,
          format: quality.format,
          isAudioOnly: false,
        );
        if (taskId == null) {
          failures.add('$title: download could not be queued');
          continue;
        }
        downloads.addDownload(
          DownloadEntry(
            id: downloadId,
            title: title,
            url: quality.videoUrl,
            size: quality.fileSize,
            format: '${quality.quality} ${quality.format}',
            progress: 0,
            savedPath: savePath,
          ),
        );
        queued++;
      } catch (error) {
        failures.add('Link ${index + 1}: $error');
      }
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _status = failures.isEmpty
          ? '$queued download(s) queued successfully.'
          : '$queued queued; ${failures.length} link(s) could not be queued.';
    });

    if (queued > 0 && failures.isEmpty) {
      _urlsController.clear();
    }

    if (failures.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Some links were skipped'),
          content: SingleChildScrollView(
            child: Text(failures.join('\n\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _readUrls().length;
    return Scaffold(
      appBar: AppBar(title: const Text('Batch downloads')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Add video links',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste one YouTube URL per line. Choose MP4 or WebM and a maximum resolution from 4K to 144p. Check the first video to see its actual available stream and estimated file size.  Only use media you are authorized to download.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _preferredFormat,
            decoration: const InputDecoration(
              labelText: 'Video format',
              border: OutlineInputBorder(),
            ),
            items: const ['MP4', 'WEBM']
                .map((format) => DropdownMenuItem(value: format, child: Text(format)))
                .toList(),
            onChanged: _isProcessing || _audioOnly
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _preferredFormat = value;
                        _previewOptions = const [];
                      });
                    }
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _preferredQuality,
            decoration: const InputDecoration(
              labelText: 'Maximum resolution',
              helperText: '4K down to 144p. The actual available stream may be lower.',
              border: OutlineInputBorder(),
            ),
            items: const ['2160p', '1440p', '1080p', '720p', '480p', '360p', '240p', '144p']
                .map((quality) => DropdownMenuItem(value: quality, child: Text(quality)))
                .toList(),
            onChanged: _isProcessing || _audioOnly
                ? null
                : (value) {
                    if (value != null) setState(() => _preferredQuality = value);
                  },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isProcessing || _isPreviewLoading || _audioOnly ? null : _previewQualities,
            icon: _isPreviewLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.data_usage),
            label: Text(_isPreviewLoading ? 'Checking sizes…' : 'Check available sizes'),
          ),
          if (_previewOptions.isNotEmpty) ...[
            Builder(builder: (context) {
              final selected = _chooseQuality(_previewOptions);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selected: ${selected.quality} • ${selected.format}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Estimated download size: ${selected.fileSize}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    Text('Frame rate: ${selected.fps} FPS',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _audioOnly,
            title: const Text('Audio only'),
            subtitle: const Text('Save the original audio format; this does not convert to MP3.'),
            onChanged: _isProcessing ? null : (value) => setState(() => _audioOnly = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _wifiOnly,
            title: const Text('Wi-Fi only downloads'),
            subtitle: const Text('Pause or block downloads on mobile data while Tube Arena is active. Android may not report network changes while the app is in the background.'),
            onChanged: _isProcessing
                ? null
                : (value) async {
                    setState(() => _wifiOnly = value);
                    await BackgroundDownloadService().setWifiOnly(value);
                  },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlsController,
            minLines: 5,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'https://www.youtube.com/watch?v=…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            enabled: !_isProcessing,
          ),
          const SizedBox(height: 12),
          Text(
            '$count unique link(s)',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Only add videos you own or have permission to download. Some videos may not provide a compatible stream.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _startBatch,
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_isProcessing ? 'Checking links…' : 'Check and download'),
          ),
          const SizedBox(height: 16),
          Text(_status, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
