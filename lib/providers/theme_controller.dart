import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's theme choice (system, light or dark) and remembers it.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initial = ThemeMode.system, SharedPreferences? prefs}) : _mode = initial, _prefs = prefs;

  static const _key = 'theme_mode';

  ThemeMode _mode;
  SharedPreferences? _prefs;

  ThemeMode get mode => _mode;

  /// Reads the saved choice. Falls back to following the system on any error.
  static Future<ThemeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
      return ThemeController(initial: _parse(prefs.getString(_key)), prefs: prefs);
    } catch (error) {
      debugPrint('Could not read theme setting: $error');
      return ThemeController();
    }
  }

  static ThemeMode _parse(String? value) =>
      ThemeMode.values.firstWhere((m) => m.name == value, orElse: () => ThemeMode.system);

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_key, mode.name);
    } catch (error) {
      debugPrint('Could not save theme setting: $error');
    }
  }

  /// Switches between light and dark, resolving "system" to what is showing now.
  Future<void> toggle(Brightness current) => setMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}
