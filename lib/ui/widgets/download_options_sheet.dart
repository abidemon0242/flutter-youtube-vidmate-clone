import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/video_model.dart';
import '../../providers/downloads_provider.dart';
import '../../services/youtube_extraction_service.dart';

String formatBytes(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value >= 10 || unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} ${units[unit]}';
}

/// Lets the user pick a quality for [video] and queues the download.
Future<void> showDownloadOptionsSheet(BuildContext context, VideoModel video) async {
  if (!video.isYoutube) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample videos cannot be downloaded. Open a YouTube video or paste a link.')),
    );
    return;
  }
  final option = await showModalBottomSheet<DownloadOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    showDragHandle: true,
    builder: (_) => _DownloadOptionsSheet(video: video),
  );
  if (option == null || !context.mounted) return;
  await startDownload(context, video, option);
}

Future<void> startDownload(BuildContext context, VideoModel video, DownloadOption option, {bool notify = true}) async {
  final downloads = context.read<DownloadsProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final entry = await downloads.start(
    videoId: video.youtubeId!,
    title: video.title,
    channelName: video.channelName,
    thumbnailUrl: video.thumbnailUrl,
    option: option,
  );
  if (!notify) return;
  final message = entry.status == DownloadStatus.completed
      ? 'Already downloaded: ${option.label}'
      : 'Downloading ${option.label}. Keep Tube Arena open until it finishes.';
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: 'View', onPressed: () => router.go('/downloads')),
    ),
  );
}

class _DownloadOptionsSheet extends StatefulWidget {
  const _DownloadOptionsSheet({required this.video});
  final VideoModel video;

  @override
  State<_DownloadOptionsSheet> createState() => _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<_DownloadOptionsSheet> {
  late Future<DownloadOptions> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DownloadOptions> _load() =>
      context.read<YoutubeExtractionService>().getDownloadOptions(widget.video.youtubeId!);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: FutureBuilder<DownloadOptions>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
              final message = snapshot.error is YoutubeServiceException
                  ? (snapshot.error as YoutubeServiceException).message
                  : 'No downloadable formats were found for this video.';
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('Try again')),
                  ],
                ),
              );
            }
            final options = snapshot.data!;
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    widget.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (options.video.isNotEmpty) const _Header('Video'),
                for (final option in options.video) _OptionTile(option: option, icon: Icons.movie_outlined),
                if (options.audio.isNotEmpty) const _Header('Audio only'),
                for (final option in options.audio) _OptionTile(option: option, icon: Icons.music_note_outlined),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.icon});
  final DownloadOption option;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(option.label),
    subtitle: Text([option.detail, formatBytes(option.sizeBytes)].where((s) => s.isNotEmpty).join(' · ')),
    trailing: const Icon(Icons.download_rounded),
    onTap: () => Navigator.pop(context, option),
  );
}
