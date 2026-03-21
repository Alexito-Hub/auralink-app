import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
class ThemeManager with ChangeNotifier {
  static final ThemeManager instance = ThemeManager._();
  ThemeManager._() {
    _loadTheme();
  }
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  final _storage = const FlutterSecureStorage();
  void toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await _storage.write(key: 'theme_mode', value: isDark ? 'dark' : 'light');
    notifyListeners();
  }
  Future<void> _loadTheme() async {
    final saved = await _storage.read(key: 'theme_mode');
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (saved == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }
}
