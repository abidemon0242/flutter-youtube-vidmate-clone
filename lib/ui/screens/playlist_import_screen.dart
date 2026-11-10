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
      final channel = await context
          .read<PersonalizationService>()
          .addChannelFeed(controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${channel.title} (${channel.videos.length} recent videos)',
          ),
        ),
      );
      controller.clear();
    } on PlaylistImportException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not add this channel. Try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Future<void> importPlaylist() async {
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final playlist = await context
          .read<PersonalizationService>()
          .importPlaylist(controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${playlist.title} (${playlist.videos.length} videos on the first page)',
          ),
        ),
      );
      controller.clear();
    } on PlaylistImportException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not import this playlist. Try again.');
      }
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
    final profile = context.watch<PersonalizationService>();
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube channel subscriptions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.rss_feed, size: 52),
          const SizedBox(height: 12),
          Text(
            'Build a live feed without an API key',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a public YouTube channel using its /channel/UC… address, @handle URL, or RSS feed URL. You can also import a public playlist. Global search and trending use community-run public catalog servers without a YouTube Data API key; availability can vary. Private playlists are not supported.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Supported examples:\nhttps://www.youtube.com/channel/UC…\nhttps://www.youtube.com/@creator\nhttps://www.youtube.com/feeds/videos.xml?channel_id=UC…\nhttps://www.youtube.com/playlist?list=PL…',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'YouTube channel or playlist URL',
              hintText: 'https://www.youtube.com/@creator or playlist URL',
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
                : const Icon(Icons.add),
            label: Text(loading ? 'Adding…' : 'Add channel'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: loading ? null : importPlaylist,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Import public playlist'),
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
            'Your subscriptions and playlists (${profile.playlists.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (profile.playlists.isEmpty)
            const Text('No channels or playlists added yet.')
          else
            ...profile.playlists.map(
              (channel) => Card(
                child: ListTile(
                  leading: Icon(channel.id.startsWith('playlist:') ? Icons.playlist_play : Icons.subscriptions_outlined),
                  title: Text(channel.title),
                  subtitle: Text('${channel.videos.length} videos'),
                  trailing: IconButton(
                    tooltip: 'Remove item',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => profile.removePlaylist(channel.id),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: profile.playlists.isEmpty || loading
                ? null
                : () async {
                    setState(() => loading = true);
                    await profile.refreshChannelFeeds();
                    if (mounted) setState(() => loading = false);
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh channel feeds'),
          ),
        ],
      ),
    );
  }
}
