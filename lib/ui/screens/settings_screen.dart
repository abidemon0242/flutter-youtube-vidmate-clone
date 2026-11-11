import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/background_download_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _wifiOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<BackgroundDownloadService>();
    await service.initialize();
    if (mounted) {
      setState(() {
        _wifiOnly = service.wifiOnly;
        _loading = false;
      });
    }
  }

  Future<void> _setWifiOnly(bool value) async {
    setState(() => _wifiOnly = value);
    final service = context.read<BackgroundDownloadService>();
    await service.setWifiOnly(value);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: const Text('Theme'),
                  subtitle: Text(
                    themeProvider.isDark ? 'Dark mode' : 'Light mode',
                  ),
                  trailing: Switch(
                    value: themeProvider.isDark,
                    onChanged: (_) => themeProvider.toggleTheme(),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Wi-Fi only downloads'),
                  subtitle: const Text(
                    'Pause downloads when not on Wi-Fi or Ethernet. This is best-effort and may not block mobile data while the app is in the background.',
                  ),
                  value: _wifiOnly,
                  onChanged: _setWifiOnly,
                ),
                const Divider(),
                const ListTile(
                  title: Text('YouTube player'),
                  subtitle: Text(
                    'YouTube videos use the official IFrame player. Ads, quality, and availability are controlled by YouTube. Tube Arena cannot remove ads from the official player.',
                  ),
                ),
                const ListTile(
                  title: Text('Downloads'),
                  subtitle: Text(
                    'High-quality downloads may require merging video and audio. This can fail if YouTube changes its streams. Only download content you own or are authorized to save.',
                  ),
                ),
                const ListTile(
                  title: Text('Personalized feed'),
                  subtitle: Text(
                    'The home feed uses the official YouTube Data API (regional charts and search). It is not a logged-in personalized YouTube account feed.',
                  ),
                ),
                const ListTile(
                  title: Text('API key'),
                  subtitle: Text(
                    'A YouTube Data API key is required for the live feed and search. Restrict the key to this app\'s package name and certificate.',
                  ),
                ),
              ],
            ),
    );
  }
}
