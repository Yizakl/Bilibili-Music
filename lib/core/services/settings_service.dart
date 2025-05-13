import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/advanced_settings.dart';

class SettingsService extends ChangeNotifier {
  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isHighQualityEnabled = true;
  AdvancedSettings _advancedSettings = const AdvancedSettings();

  static const String _themeModeKey = 'theme_mode';
  static const String _highQualityKey = 'high_quality_enabled';
  static const String _advancedSettingsKey = 'advanced_settings';

  SettingsService(SharedPreferences prefs) {
    _prefs = prefs;
    _loadSettings();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get isHighQualityEnabled => _isHighQualityEnabled;
  AdvancedSettings get advancedSettings => _advancedSettings;

  // 从SharedPreferences加载设置
  Future<void> _loadSettings() async {
    // 加载主题设置
    final themeModeIndex = _prefs.getInt(_themeModeKey);
    if (themeModeIndex != null) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    // 加载音质设置
    _isHighQualityEnabled = _prefs.getBool(_highQualityKey) ?? true;

    // 加载高级设置
    final advancedSettingsJson = _prefs.getString(_advancedSettingsKey);
    if (advancedSettingsJson != null) {
      try {
        _advancedSettings =
            AdvancedSettings.fromJson(json.decode(advancedSettingsJson));
      } catch (e) {
        debugPrint('加载高级设置失败: $e');
      }
    }

    notifyListeners();
  }

  // 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  // 设置音质
  Future<void> setHighQuality(bool isEnabled) async {
    _isHighQualityEnabled = isEnabled;
    await _prefs.setBool(_highQualityKey, isEnabled);
    notifyListeners();
  }

  // 更新高级设置
  Future<void> updateAdvancedSettings(AdvancedSettings settings) async {
    _advancedSettings = settings;
    await _prefs.setString(
        _advancedSettingsKey, json.encode(settings.toJson()));
    notifyListeners();
  }

  // 更新音频API来源
  Future<void> setAudioApiSource(AudioApiSource source) async {
    final newSettings = _advancedSettings.copyWith(audioApiSource: source);
    await updateAdvancedSettings(newSettings);
  }
}
