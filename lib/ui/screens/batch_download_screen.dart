import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/downloads_provider.dart';
import '../../services/background_download_service.dart';

class BatchDownloadScreen extends StatefulWidget {
  const BatchDownloadScreen({super.key, this.initialUrls});

  final List<String>? initialUrls;

  @override
  State<BatchDownloadScreen> createState() => _BatchDownloadScreenState();
}

class _BatchDownloadScreenState extends State<BatchDownloadScreen> {
  final TextEditingController _urlsController = TextEditingController();
  bool _isProcessing = false;
  bool _audioOnly = false;
  bool _wifiOnly = false;
  bool _notificationsDenied = false;
  String _status =
      'Paste direct media-file URLs here. YouTube watch-page links are not downloadable in this app.';

  static const _youtubeHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'www.youtu.be',
  };
  static const _videoExtensions = {'mp4', 'webm', '3gp'};
  static const _audioExtensions = {'mp3', 'm4a', 'aac', 'wav', 'webm'};

  @override
  void initState() {
    super.initState();
    _wifiOnly = BackgroundDownloadService().wifiOnly;
    final initialUrls = (widget.initialUrls ?? const <String>[])
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    if (initialUrls.isNotEmpty) {
      _urlsController.text = initialUrls.join('\n');
      _status =
          '${initialUrls.length} link(s) added. Only direct media files can be queued.';
    }
  }

  @override
  void dispose() {
    _urlsController.dispose();
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

  ({Uri uri, String extension})? _parseDirectMediaUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        _youtubeHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    if (uri.pathSegments.isEmpty) return null;
    final lastSegment = uri.pathSegments.last;
    final dot = lastSegment.lastIndexOf('.');
    if (dot < 0 || dot == lastSegment.length - 1) return null;
    final extension = lastSegment.substring(dot + 1).toLowerCase();
    final allowed = _audioOnly ? _audioExtensions : _videoExtensions;
    if (!allowed.contains(extension)) return null;
    return (uri: uri, extension: extension);
  }

  String _titleFromUri(Uri uri, String fallback) {
    final segment = uri.pathSegments.isEmpty ? fallback : uri.pathSegments.last;
    final decoded = Uri.decodeComponent(segment);
    final dot = decoded.lastIndexOf('.');
    final title = (dot > 0 ? decoded.substring(0, dot) : decoded)
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .trim();
    return title.isEmpty ? fallback : title;
  }

  Future<void> _startBatch() async {
    final urls = _readUrls();
    if (urls.isEmpty) {
      setState(() => _status = 'Enter at least one direct media URL.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Preparing ${urls.length} link(s)…';
    });

    final downloads = context.read<DownloadsProvider>();
    final service = BackgroundDownloadService();
    String documentsPath;
    try {
      documentsPath = (await getApplicationDocumentsDirectory()).path;
      if (Platform.isAndroid) {
        final permission = await Permission.notification.request();
        _notificationsDenied = !permission.isGranted;
      }
      if (!service.isInitialized) await service.initialize();
      if (!service.isInitialized) {
        throw StateError(
          service.initializationError ?? 'Download service is unavailable.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = 'Could not prepare downloads: $error';
      });
      return;
    }

    var queued = 0;
    final failures = <String>[];
    for (var index = 0; index < urls.length; index++) {
      if (!mounted) return;
      final rawUrl = urls[index];
      setState(() => _status = 'Checking ${index + 1} of ${urls.length}…');
      final parsed = _parseDirectMediaUrl(rawUrl);
      if (parsed == null) {
        final parsedInput = Uri.tryParse(rawUrl);
        final host = parsedInput?.host.toLowerCase() ?? '';
        final isYoutubePage = _youtubeHosts.contains(host);
        failures.add(
          isYoutubePage
              ? 'Link ${index + 1}: this is a YouTube page URL, not a direct media file. Tube Arena does not extract YouTube streams. Use a direct media-file URL that you own or have permission to download.'
              : 'Link ${index + 1}: unsupported URL or file extension. Use a direct MP4, WebM, 3GP, MP3, M4A, AAC or WAV file URL.',
        );
        continue;
      }

      final title = _titleFromUri(parsed.uri, 'Media ${index + 1}');
      final id = 'direct-${DateTime.now().microsecondsSinceEpoch}-$index';
      final normalizedTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final safeTitle = normalizedTitle.length > 80
          ? normalizedTitle.substring(0, 80)
          : normalizedTitle;
      final safeFileId = id.replaceAll(RegExp(r'[^\w-]'), '');
      final fileBase = safeTitle.isEmpty
          ? safeFileId
          : '${safeTitle}_$safeFileId';
      final extension = parsed.extension;
      final format = extension.toUpperCase();
      final fileName = '$fileBase.$extension';
      final savePath = '$documentsPath/TubeArena/Downloads/$fileName';

      final taskId = await service.startDownload(
        id: id,
        title: title,
        videoUrl: _audioOnly ? '' : rawUrl,
        audioUrl: _audioOnly ? rawUrl : '',
        sourceUrl: rawUrl,
        quality: 'Original',
        format: format,
        outputFormat: format,
        isAudioOnly: _audioOnly,
      );
      if (taskId == null) {
        failures.add(
          '$title: download could not be queued. Check the URL, Wi-Fi-only setting and existing task state.',
        );
        continue;
      }

      downloads.addDownload(
        DownloadEntry(
          id: id,
          title: title,
          url: rawUrl,
          sourceUrl: rawUrl,
          size: 'Unknown',
          format: _audioOnly ? 'Audio $format' : format,
          progress: 0,
          savedPath: savePath,
          isAudioOnly: _audioOnly,
        ),
      );
      queued++;
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      final permissionNote = _notificationsDenied
          ? ' Notification permission is off, so visible download notifications may be unavailable.'
          : '';
      _status =
          (failures.isEmpty
              ? '$queued download(s) queued.'
              : '$queued queued; ${failures.length} link(s) skipped.') +
          permissionNote;
    });

    if (queued > 0 && failures.isEmpty) _urlsController.clear();
    if (failures.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Some links were skipped'),
          content: SingleChildScrollView(child: Text(failures.join('\n\n'))),
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
            'Download direct media files',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste direct file URLs that end in a supported media extension. Tube Arena does not extract streams from YouTube pages. Only download media you own or have permission to save.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _audioOnly,
            title: const Text('Audio-only files'),
            subtitle: const Text(
              'Accept MP3, M4A, AAC, WAV and audio WebM links.',
            ),
            onChanged: _isProcessing
                ? null
                : (value) => setState(() => _audioOnly = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _wifiOnly,
            title: const Text('Wi-Fi only downloads'),
            subtitle: const Text(
              'Pause or block downloads when Wi-Fi is unavailable while Tube Arena is active.',
            ),
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
            enabled: !_isProcessing,
            decoration: const InputDecoration(
              hintText: 'https://example.com/media/video.mp4',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$count unique link(s)',
            style: const TextStyle(color: AppColors.textSecondary),
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
            label: Text(
              _isProcessing ? 'Preparing downloads…' : 'Download files',
            ),
          ),
          const SizedBox(height: 16),
          Text(_status, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
