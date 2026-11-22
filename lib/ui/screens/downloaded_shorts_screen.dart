import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/video_model.dart';
import '../../providers/downloads_provider.dart';
import 'watch_screen.dart';

/// Offline, swipeable playback for Shorts already stored on this device.
class DownloadedShortsScreen extends StatefulWidget {
  const DownloadedShortsScreen({super.key});

  @override
  State<DownloadedShortsScreen> createState() => _DownloadedShortsScreenState();
}

class _DownloadedShortsScreenState extends State<DownloadedShortsScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    final entries = downloads.downloadedShorts;
    if (_index >= entries.length && entries.isNotEmpty) {
      _index = entries.length - 1;
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Downloaded Shorts (${entries.length})'),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text('No downloaded Shorts yet.', style: TextStyle(color: Colors.white70)),
            )
          : PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: entries.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final video = VideoModel(
                  id: 'local-short:${entry.id}',
                  title: entry.title,
                  channelName: entry.channelName,
                  thumbnailUrl: entry.thumbnailUrl,
                  duration: '',
                  localPath: entry.savedPath,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    WatchScreen(
                      key: ValueKey('downloaded-short-${entry.id}'),
                      video: video,
                      immersive: true,
                      autoplay: index == _index,
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: SafeArea(
                        child: Row(
                          children: [
                            Text(
                              '${index + 1} / ${entries.length}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: entry.isProtected ? 'Unprotect Short' : 'Keep important Short',
                              onPressed: () => downloads.setShortProtected(entry.id, !entry.isProtected),
                              icon: Icon(
                                entry.isProtected ? Icons.bookmark : Icons.bookmark_border,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete downloaded Short',
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final deleted = await downloads.remove(entry);
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(deleted ? 'Short deleted.' : 'Short removed from the list.'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 76,
                      bottom: 32,
                      child: IgnorePointer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.channelName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
