import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences stored locally.
class UserPreferences {
  const UserPreferences({
    this.themeMode = ThemeMode.system,
    this.locale,
  });

  final ThemeMode themeMode;
  final Locale? locale;

  UserPreferences copyWith({ThemeMode? themeMode, Locale? locale}) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
    );
  }
}

/// Service for managing user preferences with local storage.
class UserPreferencesService extends ChangeNotifier {
  static const _themeModeKey = 'themeMode';
  static const _localeKey = 'locale';

  UserPreferences _preferences = const UserPreferences();
  SharedPreferences? _prefs;

  UserPreferences get preferences => _preferences;
  ThemeMode get themeMode => _preferences.themeMode;
  Locale? get locale => _preferences.locale;

  /// Initialize and load saved preferences.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = _prefs;
    if (prefs == null) return;

    // Load theme mode
    final themeModeIndex = prefs.getInt(_themeModeKey);
    final themeMode = themeModeIndex != null && themeModeIndex < ThemeMode.values.length
        ? ThemeMode.values[themeModeIndex]
        : ThemeMode.system;

    // Load locale
    final localeCode = prefs.getString(_localeKey);
    final locale = localeCode != null ? Locale(localeCode) : null;

    _preferences = UserPreferences(themeMode: themeMode, locale: locale);
    notifyListeners();
  }

  /// Set theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    _preferences = _preferences.copyWith(themeMode: mode);
    await _prefs?.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  /// Set locale.
  Future<void> setLocale(Locale? locale) async {
    _preferences = UserPreferences(
      themeMode: _preferences.themeMode,
      locale: locale,
    );
    if (locale != null) {
      await _prefs?.setString(_localeKey, locale.languageCode);
    } else {
      await _prefs?.remove(_localeKey);
    }
    notifyListeners();
  }
}

final userPreferencesService = UserPreferencesService();
