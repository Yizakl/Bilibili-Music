import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/advanced_settings.dart';
import '../models/settings.dart';

class SettingsService extends ChangeNotifier {
  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  String _audioQuality = 'standard';
  AdvancedSettings _advancedSettings = const AdvancedSettings();

  static const String _themeModeKey = 'theme_mode';
  static const String _audioQualityKey = 'audio_quality';
  static const String _advancedSettingsKey = 'advanced_settings';

  SettingsService(SharedPreferences prefs) {
    _prefs = prefs;
    _loadSettings();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  String get audioQuality => _audioQuality;
  bool get isHighQualityEnabled => _audioQuality == 'high';
  AdvancedSettings get advancedSettings => _advancedSettings;

  // 获取所有设置
  Settings get settings => Settings(
        themeMode: _themeMode,
        audioQuality: _audioQuality,
        advancedSettings: _advancedSettings,
      );

  // 从SharedPreferences加载设置
  void _loadSettings() {
    try {
      // 主题模式 (0=跟随系统, 1=浅色, 2=深色)
      final themeMode = _prefs.getInt(_themeModeKey) ?? 0;
      _themeMode = ThemeMode.values[themeMode.clamp(0, 2)];

      // 加载音质设置
      _audioQuality = _prefs.getString(_audioQualityKey) ?? 'standard';

      // 加载高级设置
      final advancedSettingsJson = _prefs.getString(_advancedSettingsKey);
      if (advancedSettingsJson != null) {
        try {
          _advancedSettings =
              AdvancedSettings.fromJson(json.decode(advancedSettingsJson));
        } catch (e) {
          debugPrint('解析高级设置失败: $e，将使用默认设置');
          _advancedSettings = const AdvancedSettings();
        }
      } else {
        _advancedSettings = const AdvancedSettings();
      }
    } catch (e) {
      debugPrint('加载设置失败: $e，将使用默认设置');
      _themeMode = ThemeMode.system;
      _audioQuality = 'standard';
      _advancedSettings = const AdvancedSettings();
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
  Future<void> setAudioQuality(String quality) async {
    _audioQuality = quality;
    await _prefs.setString(_audioQualityKey, quality);
    notifyListeners();
  }

  // 设置高品质
  Future<void> setHighQuality(bool enabled) async {
    await setAudioQuality(enabled ? 'high' : 'standard');
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

  // 更新播放模式
  Future<void> setPlaybackMode(PlaybackMode mode) async {
    final newSettings = _advancedSettings.copyWith(playbackMode: mode);
    await updateAdvancedSettings(newSettings);
  }
}
