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
                    'Regular downloads pause when Wi-Fi or Ethernet is lost. HLS downloads check the connection before starting but are not automatically paused if it changes. Android background limits may delay pause events.',
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
                    'Downloads accept direct media-file URLs and completed HLS VOD manifests. Live HLS playlists and YouTube watch-page extraction are not supported. Only save content you own or are authorized to download.',
                  ),
                ),
                const ListTile(
                  title: Text('Personalized feed'),
                  subtitle: Text(
                    'Public search and regional trending metadata use independently operated Invidious catalog instances. Public channel subscriptions use YouTube RSS. This is not a logged-in personalized YouTube account feed.',
                  ),
                ),
                const ListTile(
                  title: Text('YouTube Data API key'),
                  subtitle: Text(
                    'No YouTube Data API key is used or required. Public catalog availability can vary because instances are independently operated.',
                  ),
                ),
              ],
            ),
    );
  }
}
