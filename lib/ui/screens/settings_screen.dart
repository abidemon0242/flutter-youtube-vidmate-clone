import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../providers/playback_settings.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/recommendation_settings.dart';
import '../../services/google_auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recommendations = context.watch<RecommendationSettings>();
    final playback = context.watch<PlaybackSettings>();
    final downloads = context.watch<DownloadsProvider>();
    final googleAuth = context.watch<GoogleAuthService>();
    final user = googleAuth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: user?.photoURL == null ? null : NetworkImage(user!.photoURL!),
              child: user?.photoURL == null ? const Icon(Icons.account_circle_outlined) : null,
            ),
            title: Text(user?.displayName ?? 'Google account'),
            subtitle: Text(user?.email ?? 'Signed in with Firebase Authentication'),
            trailing: googleAuth.currentUser == null
                ? TextButton(
                    onPressed: googleAuth.isBusy
                        ? null
                        : () async {
                            try {
                              await googleAuth.signIn();
                            } catch (error) {
                              if (!context.mounted) return;
                              final message = googleAuth.lastError ?? 'Sign-in failed: $error';
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                            }
                          },
                    child: Text(googleAuth.isBusy ? 'Please wait…' : 'Sign in'),
                  )
                : TextButton(
                    onPressed: googleAuth.isBusy
                        ? null
                        : () async {
                            try {
                              await googleAuth.signOut();
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Sign-out failed: $error')),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Sign-out failed: $error')),
                              );
                            }
                          },
                    child: Text(googleAuth.isBusy ? 'Please wait…' : 'Sign out'),
                  ),
          ),
          if (googleAuth.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              googleAuth.lastError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
          ],
          const Divider(),
          Text('Recommendations', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: recommendations.defaultSection,
            decoration: const InputDecoration(labelText: 'Default Home section'),
            items: const [
              DropdownMenuItem(value: 'Recommended', child: Text('Recommended for you')),
              DropdownMenuItem(value: 'Subscriptions', child: Text('Subscriptions')),
              DropdownMenuItem(value: 'Trending', child: Text('Trending')),
              DropdownMenuItem(value: 'Study', child: Text('Study')),
              DropdownMenuItem(value: 'Funny', child: Text('Funny')),
              DropdownMenuItem(value: 'Romantic', child: Text('Romantic')),
              DropdownMenuItem(value: 'Technology', child: Text('Technology')),
              DropdownMenuItem(value: 'Gaming', child: Text('Gaming')),
              DropdownMenuItem(value: 'Music', child: Text('Music')),
              DropdownMenuItem(value: 'Science', child: Text('Science')),
              DropdownMenuItem(value: 'Sports', child: Text('Sports')),
              DropdownMenuItem(value: 'Watch Later', child: Text('Watch Later')),
              DropdownMenuItem(value: 'Shorts', child: Text('Shorts')),
              DropdownMenuItem(value: 'History', child: Text('History')),
            ],
            onChanged: (value) {
              if (value != null) recommendations.setDefaultSection(value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Personalized recommendations'),
            subtitle: const Text('Use your selected interests and local feedback'),
            value: recommendations.personalization,
            onChanged: recommendations.setPersonalization,
          ),
          const Divider(),
          Text('Your interests', style: Theme.of(context).textTheme.titleMedium),
          const Text('Choose categories and the topics you want to see within each category.'),
          for (final category in RecommendationSettings.categories)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(category),
              leading: Checkbox(
                value: recommendations.interests.contains(category),
                onChanged: (value) => recommendations.setInterest(category, value ?? false),
              ),
              children: [
                for (final topic in RecommendationSettings.subtopics[category] ?? const <String>[])
                  CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 20),
                    title: Text(topic),
                    value: recommendations.selectedSubtopics(category).contains(topic),
                    onChanged: (value) => recommendations.setSubtopic(category, topic, value ?? false),
                  ),
              ],
            ),
          const Divider(),
          Text('Hidden channels', style: Theme.of(context).textTheme.titleMedium),
          if (recommendations.hiddenChannels.isEmpty) const ListTile(title: Text('No hidden channels')),
          for (final channel in recommendations.hiddenChannels)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(channel),
              subtitle: const Text('Excluded from personalized recommendations'),
              trailing: TextButton(
                onPressed: () => recommendations.restoreChannel(channel),
                child: const Text('Enable'),
              ),
            ),
          const Divider(),
          Text('Subscriptions', style: Theme.of(context).textTheme.titleMedium),
          if (recommendations.subscriptions.isEmpty) const ListTile(title: Text('No subscribed channels yet')),
          for (final channel in recommendations.subscriptions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(channel),
              trailing: IconButton(
                tooltip: 'Unsubscribe',
                icon: const Icon(Icons.notifications_off_outlined),
                onPressed: () => recommendations.toggleSubscription(channel),
              ),
            ),
          TextButton.icon(
            onPressed: recommendations.resetPersonalization,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset recommendation feedback'),
          ),
          const Divider(),
          Text('Downloads', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Wi-Fi only downloads'),
            subtitle: const Text('Pause active downloads and wait when Wi-Fi is unavailable'),
            value: downloads.wifiOnly,
            onChanged: downloads.setWifiOnly,
          ),
          const Divider(),
          Text('Shorts storage', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const _ShortsStorageSettings(),
          const Divider(),
          Text('Playback', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Play in background'),
            value: playback.backgroundPlayback,
            onChanged: playback.setBackgroundPlayback,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Preferred video quality'),
            subtitle: Text(playback.preferredHeight == 0 ? 'Auto (network-aware)' : '${playback.preferredHeight}p'),
            trailing: DropdownButton<int>(
              value: playback.preferredHeight,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Auto (network-aware)')),
                DropdownMenuItem(value: 360, child: Text('360p')),
                DropdownMenuItem(value: 480, child: Text('480p')),
                DropdownMenuItem(value: 720, child: Text('720p')),
                DropdownMenuItem(value: 1080, child: Text('1080p')),
              ],
              onChanged: (value) {
                if (value != null) playback.setPreferredHeight(value);
              },
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Adaptive buffering and offline cache'),
            subtitle: Text(
              'Automatic background caching is separate from explicit downloads. Shorts you download are stored locally for offline playback.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortsStorageSettings extends StatefulWidget {
  const _ShortsStorageSettings();

  @override
  State<_ShortsStorageSettings> createState() => _ShortsStorageSettingsState();
}

class _ShortsStorageSettingsState extends State<_ShortsStorageSettings> {
  late final TextEditingController _controller = TextEditingController(text: '${DownloadsProvider.defaultShortsLimit}');
  int? _lastLimit;
  bool _initialised = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsProvider>();
    final limit = downloads.shortsLimit;
    if (!_initialised || _lastLimit != limit) {
      _initialised = true;
      _lastLimit = limit;
      if (limit != null) _controller.text = limit.toString();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Unlimited Shorts count'),
          subtitle: const Text('Do not automatically remove Shorts because of their number'),
          value: limit == null,
          onChanged: (enabled) async {
            final next = enabled
                ? null
                : (int.tryParse(_controller.text.trim()) ?? DownloadsProvider.defaultShortsLimit);
            try {
              await downloads.setShortsLimit(next);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Could not update Shorts limit: $error')));
              }
            }
          },
        ),
        TextField(
          controller: _controller,
          enabled: limit != null,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Maximum downloaded Shorts',
            helperText: 'Default: 1,000. Enter any positive whole number.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: limit == null || _saving
                ? null
                : () async {
                    final value = int.tryParse(_controller.text.trim());
                    if (value == null || value < 1) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Enter a whole number greater than zero.')));
                      return;
                    }
                    setState(() => _saving = true);
                    try {
                      await downloads.setShortsLimit(value);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Shorts limit set to $value. Existing Shorts will be kept until new downloads need space.',
                            ),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Could not save Shorts limit: $error')));
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: Text(_saving ? 'Saving...' : 'Save limit'),
          ),
        ),
        Text(
          '${downloads.downloadedShorts.length} downloaded Shorts · Protected Shorts are excluded from automatic replacement.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
