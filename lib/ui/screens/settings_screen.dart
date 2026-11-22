import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../providers/playback_settings.dart';
import '../../providers/recommendation_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recommendations = context.watch<RecommendationSettings>();
    final playback = context.watch<PlaybackSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Recommendations', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: recommendations.defaultSection,
            decoration: const InputDecoration(labelText: 'Default Home section'),
            items: const [
              DropdownMenuItem(value: 'Recommended', child: Text('Recommended for you')),
              DropdownMenuItem(value: 'Subscriptions', child: Text('Subscriptions')),
              DropdownMenuItem(value: 'Trending', child: Text('Trending')),
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
            subtitle: Text(playback.preferredHeight == 0 ? 'Best available' : '${playback.preferredHeight}p'),
            trailing: DropdownButton<int>(
              value: playback.preferredHeight,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Auto / Best')),
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
              'Advanced persistent offline caching is not enabled until source permissions and storage management are implemented.',
            ),
          ),
        ],
      ),
    );
  }
}
