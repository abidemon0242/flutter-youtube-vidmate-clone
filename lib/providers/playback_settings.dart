import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player preferences that are remembered between launches.
class PlaybackSettings extends ChangeNotifier {
  PlaybackSettings({bool backgroundPlayback = true, int preferredHeight = defaultHeight, SharedPreferences? prefs})
    : _background = backgroundPlayback,
      _preferredHeight = preferredHeight,
      _prefs = prefs;

  static const defaultHeight = 720;
  static const _backgroundKey = 'background_playback';
  static const _heightKey = 'preferred_quality';

  bool _background;
  int _preferredHeight;
  SharedPreferences? _prefs;

  /// Keep playing when the app is in the background or the screen is locked.
  bool get backgroundPlayback => _background;

  /// Preferred vertical resolution; 0 means the best available.
  int get preferredHeight => _preferredHeight;

  static Future<PlaybackSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
      return PlaybackSettings(
        backgroundPlayback: prefs.getBool(_backgroundKey) ?? true,
        preferredHeight: prefs.getInt(_heightKey) ?? defaultHeight,
        prefs: prefs,
      );
    } catch (error) {
      debugPrint('Could not read playback settings: $error');
      return PlaybackSettings();
    }
  }

  Future<void> setBackgroundPlayback(bool value) async {
    if (value == _background) return;
    _background = value;
    notifyListeners();
    await _save((prefs) => prefs.setBool(_backgroundKey, value));
  }

  Future<void> setPreferredHeight(int value) async {
    if (value == _preferredHeight) return;
    _preferredHeight = value;
    notifyListeners();
    await _save((prefs) => prefs.setInt(_heightKey, value));
  }

  Future<void> _save(Future<bool> Function(SharedPreferences prefs) write) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await write(_prefs!);
    } catch (error) {
      debugPrint('Could not save playback settings: $error');
    }
  }
}
