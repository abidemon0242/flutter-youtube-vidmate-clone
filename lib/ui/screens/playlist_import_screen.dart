import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/personalization_service.dart';

class PlaylistImportScreen extends StatefulWidget {
  const PlaylistImportScreen({super.key});
  @override
  State<PlaylistImportScreen> createState() => _PlaylistImportScreenState();
}

class _PlaylistImportScreenState extends State<PlaylistImportScreen> {
  final controller = TextEditingController();
  bool loading = false;
  String? error;
  Future<void> import() async {
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final p = await context.read<PersonalizationService>().importPlaylist(
        controller.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ' +
                p.title +
                ' (' +
                p.videos.length.toString() +
                ' videos)',
          ),
        ),
      );
      controller.clear();
    } on PlaylistImportException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Playlist import failed. Try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PersonalizationService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Import YouTube playlist')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.playlist_add, size: 52),
          const SizedBox(height: 12),
          Text(
            'Personalize your feed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste a public YouTube playlist link. Tube Arena reads playlist and video metadata through the official YouTube Data API.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Playlist URL',
              hintText: 'https://www.youtube.com/playlist?list=...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : import,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(loading ? 'Importing…' : 'Import playlist'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Imported playlists (' + p.playlists.length.toString() + ')',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (p.playlists.isEmpty)
            const Text('No playlists imported yet.')
          else
            ...p.playlists.map(
              (x) => Card(
                child: ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(x.title),
                  subtitle: Text(
                    x.channel + ' • ' + x.videos.length.toString() + ' videos',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => p.removePlaylist(x.id),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Only publicly accessible playlists are supported here. Private playlists need a separate approved Google authorization flow.',
          ),
        ],
      ),
    );
  }
}
