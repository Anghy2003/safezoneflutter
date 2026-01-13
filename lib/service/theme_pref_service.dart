import 'package:shared_preferences/shared_preferences.dart';

class ThemePrefService {
  static const _key = 'theme_mode_index'; // 0 system, 1 light, 2 dark

  Future<int> loadThemeModeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  Future<void> saveThemeModeIndex(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, idx);
  }
}
