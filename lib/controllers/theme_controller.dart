import 'package:flutter/material.dart';
import '../service/theme_pref_service.dart';

class ThemeController extends ChangeNotifier {
  final ThemePrefService _svc;
  ThemeMode _mode = ThemeMode.system;

  ThemeController(this._svc);

  ThemeMode get mode => _mode;

  /// Cargar preferencia guardada
  Future<void> load() async {
    final idx = await _svc.loadThemeModeIndex();
    _mode = _fromIndex(idx);
    notifyListeners();
  }

  /// Guardar y aplicar
  Future<void> setMode(ThemeMode newMode) async {
    _mode = newMode;
    notifyListeners();
    await _svc.saveThemeModeIndex(_toIndex(newMode));
  }

  ThemeMode _fromIndex(int i) {
    if (i == 1) return ThemeMode.light;
    if (i == 2) return ThemeMode.dark;
    return ThemeMode.system;
  }

  int _toIndex(ThemeMode m) {
    if (m == ThemeMode.light) return 1;
    if (m == ThemeMode.dark) return 2;
    return 0;
  }
}
