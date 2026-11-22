import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_controller.dart';

/// App bar button for choosing System, Light or Dark theme.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  static const _labels = {ThemeMode.system: 'Use device setting', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'};
  static const _icons = {
    ThemeMode.system: Icons.brightness_auto_rounded,
    ThemeMode.light: Icons.light_mode_rounded,
    ThemeMode.dark: Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme: ${_labels[controller.mode]}',
      icon: Icon(_icons[controller.mode]),
      initialValue: controller.mode,
      onSelected: controller.setMode,
      itemBuilder: (_) => [
        for (final mode in ThemeMode.values)
          PopupMenuItem<ThemeMode>(
            value: mode,
            child: Row(
              children: [
                SizedBox(width: 24, child: mode == controller.mode ? const Icon(Icons.check_rounded, size: 20) : null),
                const SizedBox(width: 8),
                Icon(_icons[mode], size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(_labels[mode]!, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
    );
  }
}
