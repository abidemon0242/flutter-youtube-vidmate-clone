import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';
import '../../services/background_download_service.dart';
import '../../services/youtube_extraction_service.dart';

class BatchDownloadScreen extends StatefulWidget {
  const BatchDownloadScreen({super.key, this.initialUrls});

  final List<String>? initialUrls;

  @override
  State<BatchDownloadScreen> createState() => _BatchDownloadScreenState();
}

class _BatchDownloadScreenState extends State<BatchDownloadScreen> {
  final TextEditingController _urlsController = TextEditingController();
  late final YoutubeExtractionService _extractionService;
  bool _isProcessing = false;
  String _preferredQuality = '1080p';
  String _preferredFormat = 'MP4';
  List<VideoQualityOption> _previewOptions = const [];
  List<AudioQualityOption> _previewAudioOptions = const [];
  String _preferredAudioBitrate = '';
  String _preferredAudioFormat = '';

  String get _preferredAudioOption => '$_preferredAudioFormat|$_preferredAudioBitrate';
  bool _isPreviewLoading = false;
  int _previewRequest = 0;
  bool _audioOnly = false;
  bool _wifiOnly = false;
  bool _notificationsDenied = false;
  String _status = 'Paste one video link per line.';

  @override
  void initState() {
    super.initState();
    _extractionService = YoutubeExtractionService();
    _wifiOnly = BackgroundDownloadService().wifiOnly;
    final initialUrls = (widget.initialUrls ?? const <String>[])
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    if (initialUrls.isNotEmpty) {
      _urlsController.text = initialUrls.join('\n');
      _status = '${initialUrls.length} selected video link(s) added. Check available formats before downloading.';
    }
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

  String get _sourceFormat => _preferredFormat == '3GP' ? 'MP4' : _preferredFormat;

  VideoQualityOption _chooseQuality(List<VideoQualityOption> options) {
    final matchingFormat = options.where((option) {
      final matchesSource = option.format.toUpperCase() == _sourceFormat;
      // Button-phone output needs a muxable MP4 source, not a video-only
      // fallback, so the 3GP conversion always receives both streams.
      return matchesSource && (_preferredFormat != '3GP' || option.audioUrl.isNotEmpty);
    }).toList();
    if (matchingFormat.isEmpty) {
      throw Exception('No $_preferredFormat stream is available for the selected video.');
    }

    final exact = matchingFormat.where((option) => option.quality == _preferredQuality);
    if (exact.isNotEmpty) return exact.first;

    // For other links in a batch, use the highest real stream no higher than
    // the selected resolution. Never silently exceed the user's limit.
    final targetHeight =
        int.tryParse(RegExp(r'(\d+)p').firstMatch(_preferredQuality)?.group(1) ?? '') ?? 1080;
    final atOrBelowTarget = matchingFormat.where((option) {
      final height =
          int.tryParse(RegExp(r'(\d+)p').firstMatch(option.quality)?.group(1) ?? '');
      return height != null && height <= targetHeight;
    }).toList()
      ..sort((a, b) {
        final aHeight = int.tryParse(RegExp(r'(\d+)p').firstMatch(a.quality)?.group(1) ?? '') ?? 0;
        final bHeight = int.tryParse(RegExp(r'(\d+)p').firstMatch(b.quality)?.group(1) ?? '') ?? 0;
        if (aHeight != bHeight) return bHeight.compareTo(aHeight);
        return b.fps.compareTo(a.fps);
      });

    if (atOrBelowTarget.isEmpty) {
      throw Exception('No $_preferredFormat stream is available at or below $_preferredQuality.');
    }
    return atOrBelowTarget.first;
  }

  List<VideoQualityOption> _sortedPreviewOptions(List<VideoQualityOption> options) {
    final sorted = [...options];
    sorted.sort((a, b) {
      final aHeight = int.tryParse(RegExp(r'(\d+)p').firstMatch(a.quality)?.group(1) ?? '') ?? 0;
      final bHeight = int.tryParse(RegExp(r'(\d+)p').firstMatch(b.quality)?.group(1) ?? '') ?? 0;
      if (aHeight != bHeight) return bHeight.compareTo(aHeight);
      return b.fps.compareTo(a.fps);
    });
    return sorted;
  }

  Future<void> _previewQualities() async {
    if (_isPreviewLoading || _isProcessing) return;
    final request = ++_previewRequest;
    final urls = _readUrls();
    if (urls.isEmpty) {
      setState(() => _status = 'Add a video URL first to check available formats and sizes.');
      return;
    }
    setState(() {
      _isPreviewLoading = true;
      _previewOptions = const [];
      _previewAudioOptions = const [];
      _status = _audioOnly
          ? 'Checking available audio bitrates…'
          : 'Checking available resolutions and file sizes…';
    });
    try {
      if (_audioOnly) {
        final audioOptions = await _extractionService.getAudioQualities(urls.first);
        if (!mounted || request != _previewRequest) return;
        setState(() {
          _previewAudioOptions = audioOptions;
          _isPreviewLoading = false;
          if (audioOptions.isEmpty) {
            _preferredAudioBitrate = '';
            _preferredAudioFormat = '';
            _status = 'This video does not provide a compatible audio stream.';
          } else {
            if (!audioOptions.any((option) => '${option.format}|${option.bitrate}' == _preferredAudioOption)) {
              _preferredAudioFormat = audioOptions.first.format;
              _preferredAudioBitrate = audioOptions.first.bitrate;
            }
            final selected = audioOptions.firstWhere((option) => '${option.format}|${option.bitrate}' == _preferredAudioOption);
            _status = 'Available audio: ${selected.bitrate} ${selected.format} • ${selected.fileSize}';
          }
        });
        return;
      }
      final options = await _extractionService.getVideoQualities(urls.first);
      if (!mounted || request != _previewRequest) return;
      final matching = _sortedPreviewOptions(options.where((option) {
        final matchesSource = option.format.toUpperCase() == _sourceFormat;
        return matchesSource && (_preferredFormat != '3GP' || option.audioUrl.isNotEmpty);
      }).toList());
      setState(() {
        _previewOptions = matching;
        _isPreviewLoading = false;
        if (matching.isEmpty) {
          _status = 'This video does not provide a $_preferredFormat stream.';
        } else {
          // For older feature phones, avoid downloading a large HD source
          // only to shrink it to CIF during 3GP conversion. Prefer 240p, or
          // the lowest available stream if the source has no 240p-or-lower option.
          final selected = _preferredFormat == '3GP'
              ? matching.firstWhere(
                  (option) {
                    final height = int.tryParse(
                      RegExp(r'(\d+)p').firstMatch(option.quality)?.group(1) ?? '',
                    );
                    return height != null && height <= 240;
                  },
                  orElse: () => matching.last,
                )
              : matching.first;
          _preferredQuality = selected.quality;
          _status = 'Available selection: ${selected.quality} ${selected.format} • ${selected.fileSize}';
        }
      });
    } catch (error) {
      if (!mounted || request != _previewRequest) return;
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
      if (Platform.isAndroid) {
        // A denied notification permission does not block the download itself.
        final permission = await Permission.notification.request();
        _notificationsDenied = !permission.isGranted;
      }
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

    Future<bool> prepareExistingRecord(String id, String title) async {
      final existing = downloads.items.where((item) => item.id == id).toList();
      if (existing.isEmpty) return true;
      final item = existing.first;
      final canRequeue = item.status == 'failed' || item.status == 'cancelled';
      if (canRequeue && await downloads.deleteFileFor(item)) return true;
      failures.add('$title: a download with this ID is already queued or could not be safely cleared');
      return false;
    }

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
          final targetBitrate = int.tryParse(
                RegExp(r'(\\d+)').firstMatch(_preferredAudioBitrate)?.group(1) ?? '',
              ) ?? 0;
          final formatOptions = _preferredAudioFormat.isEmpty
              ? audioOptions
              : audioOptions.where((option) => option.format == _preferredAudioFormat).toList();
          if (formatOptions.isEmpty) {
            failures.add('$title: selected audio format $_preferredAudioFormat is unavailable');
            continue;
          }
          final atOrBelowTarget = formatOptions.where((option) {
            final bitrate = int.tryParse(
                  RegExp(r'(\\d+)').firstMatch(option.bitrate)?.group(1) ?? '',
                ) ?? 0;
            return _preferredAudioBitrate.isEmpty || bitrate <= targetBitrate;
          }).toList();
          if (atOrBelowTarget.isEmpty) {
            failures.add('$title: no audio stream is available at or below $_preferredAudioBitrate');
            continue;
          }
          final exactAudio = formatOptions.where((option) => option.bitrate == _preferredAudioBitrate);
          final audio = exactAudio.isNotEmpty ? exactAudio.first : atOrBelowTarget.first;
          final downloadId = 'youtube-audio-$videoId';
          if (!await prepareExistingRecord(downloadId, title)) continue;
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
            sourceUrl: url,
            quality: audio.bitrate,
            format: audio.format,
            isAudioOnly: true,
          );
          if (taskId == null) {
            failures.add('$title: ${downloadService.initializationError ?? 'audio download could not be queued'}');
            continue;
          }
          downloads.addDownload(
            DownloadEntry(
              id: downloadId,
              title: title,
              url: audio.audioUrl,
              sourceUrl: url,
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
        if (!await prepareExistingRecord(downloadId, title)) continue;
        final safeId = downloadId.replaceAll(RegExp(r'[^\w-]'), '');
        final fileBase = safeTitle.isEmpty ? safeId : '${safeTitle}_$safeId';
        final extension = _preferredFormat.toLowerCase();
        final fileName = '$fileBase.$extension';
        final savePath = '${documentsPath}/TubeArena/Downloads/$fileName';

        final taskId = await downloadService.startDownload(
          id: downloadId,
          title: title,
          videoUrl: quality.videoUrl,
          audioUrl: quality.audioUrl,
          sourceUrl: url,
          quality: quality.quality,
          format: quality.format,
          outputFormat: _preferredFormat,
          isAudioOnly: false,
        );
        if (taskId == null) {
          failures.add('$title: ${downloadService.initializationError ?? 'download could not be queued'}');
          continue;
        }
        downloads.addDownload(
          DownloadEntry(
            id: downloadId,
            title: title,
            url: quality.videoUrl,
            sourceUrl: url,
            size: quality.fileSize,
            format: '${quality.quality} $_preferredFormat',
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
      final permissionNote = _notificationsDenied
          ? ' Android notification permission is off; downloads may run without visible notifications.'
          : '';
      _status = (failures.isEmpty
          ? '$queued download(s) queued successfully.'
          : '$queued queued; ${failures.length} link(s) could not be queued.') + permissionNote;
    });

    if (queued > 0 && failures.isEmpty) {
      _urlsController.clear();
      setState(() {
        _previewRequest++;
        _previewOptions = const [];
        _previewAudioOptions = const [];
        _preferredAudioBitrate = '';
        _preferredAudioFormat = '';
      });
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
            'Paste one YouTube URL per line. Choose MP4, WebM, or 3GP (button-phone preset), then check the first video. The resolution list shows only compatible source streams and estimated sizes. 3GP converts to low-resolution H.263 video with AMR-NB audio for older phones. Only use media you are authorized to download.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _preferredFormat,
            decoration: const InputDecoration(
              labelText: 'Save video as',
              border: OutlineInputBorder(),
            ),
            items: const ['MP4', 'WEBM', '3GP']
                .map((format) => DropdownMenuItem(value: format, child: Text(format)))
                .toList(),
            onChanged: _isProcessing || _audioOnly
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _previewRequest++;
                        _isPreviewLoading = false;
                        _preferredFormat = value;
                        _previewOptions = const [];
                      });
                    }
                  },
          ),
          const SizedBox(height: 12),
          if (_audioOnly && _previewAudioOptions.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _previewAudioOptions.any((option) => '${option.format}|${option.bitrate}' == _preferredAudioOption)
                  ? _preferredAudioOption
                  : null,
              decoration: const InputDecoration(
                labelText: 'Audio bitrate',
                helperText: 'The selected bitrate is an upper limit for every link in this batch.',
                border: OutlineInputBorder(),
              ),
              items: _previewAudioOptions
                  .map((option) => DropdownMenuItem(
                        value: '${option.format}|${option.bitrate}',
                        child: Text('${option.bitrate} • ${option.format} • ${option.fileSize}'),
                      ))
                  .toList(),
              onChanged: _isProcessing
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        final selected = _previewAudioOptions.firstWhere((option) => '${option.format}|${option.bitrate}' == value);
                        _preferredAudioFormat = selected.format;
                        _preferredAudioBitrate = selected.bitrate;
                        _status = 'Selected audio: ${selected.bitrate} ${selected.format} • ${selected.fileSize}';
                      });
                    },
            ),
          DropdownButtonFormField<String>(
            initialValue: _previewOptions.any((option) => option.quality == _preferredQuality)
                ? _preferredQuality
                : null,
            decoration: const InputDecoration(
              labelText: 'Available resolution',
              helperText: 'Check available sizes first. Only resolutions found for this video are listed.',
              border: OutlineInputBorder(),
            ),
            items: _previewOptions
                .map((option) => DropdownMenuItem(
                      value: option.quality,
                      child: Text('${option.quality} • ${option.fileSize} • ${option.fps} FPS'),
                    ))
                .toList(),
            onChanged: _isProcessing || _audioOnly || _previewOptions.isEmpty
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _preferredQuality = value;
                        final selected = _previewOptions.firstWhere((option) => option.quality == value);
                        _status = 'Selected: ${selected.quality} ${selected.format} • ${selected.fileSize}';
                      });
                    }
                  },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isProcessing || _isPreviewLoading ? null : _previewQualities,
            icon: _isPreviewLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.data_usage),
            label: Text(_isPreviewLoading
                ? 'Checking formats…'
                : _audioOnly ? 'Check audio bitrates' : 'Check available sizes'),
          ),
          if (_audioOnly && _previewAudioOptions.isNotEmpty)
            Builder(builder: (context) {
              final selected = _previewAudioOptions.firstWhere((option) => '${option.format}|${option.bitrate}' == _preferredAudioOption);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                child: Text('Selected audio: ${selected.bitrate} ${selected.format} • ${selected.fileSize}'),
              );
            }),
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
                    Text('Selected: ${selected.quality} • $_preferredFormat',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_preferredFormat == '3GP'
                        ? 'Source stream size: ${selected.fileSize} • converted 3GP size will differ'
                        : 'Estimated download size: ${selected.fileSize}',
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
            subtitle: const Text('Save the original audio format; this does not convert to MP3 or another audio format.'),
            onChanged: _isProcessing ? null : (value) => setState(() {
              _previewRequest++;
              _isPreviewLoading = false;
              _audioOnly = value;
              _previewOptions = const [];
              _previewAudioOptions = const [];
              _preferredAudioBitrate = '';
              _preferredAudioFormat = '';
            }),
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
            onChanged: (_) => setState(() {
              _previewRequest++;
              _isPreviewLoading = false;
              // A preview belongs to the first URL only; invalidate it when
              // the pasted video list changes so stale sizes cannot be selected.
              _previewOptions = const [];
              _previewAudioOptions = const [];
              _preferredAudioBitrate = '';
              _preferredAudioFormat = '';
            }),
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
            onPressed: _isProcessing || _isPreviewLoading ? null : _startBatch,
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
