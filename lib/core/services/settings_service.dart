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
  bool _isPCMode = false;

  // 歌词相关设置
  LyricSettings _lyricSettings = LyricSettings();

  static const String _themeModeKey = 'theme_mode';
  static const String _audioQualityKey = 'audio_quality';
  static const String _advancedSettingsKey = 'advanced_settings';
  static const String _pcModeKey = 'pc_mode';

  SettingsService() {
    _initSettings();
  }

  Future<void> _initSettings() async {
    _prefs = await SharedPreferences.getInstance();

    // 加载基本设置
    _themeMode = ThemeMode.values[_prefs.getInt('themeMode') ?? 0];
    _audioQuality = _prefs.getString('audioQuality') ?? 'standard';
    _isPCMode = _prefs.getBool('pcMode') ?? false;

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

    // 加载歌词设置
    _lyricSettings = LyricSettings(
      defaultSource: LyricSource.values[_prefs.getInt('lyricSource') ?? 0],
      autoSync: _prefs.getBool('lyricAutoSync') ?? true,
      fontSize: _prefs.getDouble('lyricFontSize') ?? 16.0,
    );

    notifyListeners();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  String get audioQuality => _audioQuality;
  bool get isHighQualityEnabled => _audioQuality == 'high';
  AdvancedSettings get advancedSettings => _advancedSettings;
  bool get isPCMode => _isPCMode;

  // 获取所有设置
  Settings get settings => Settings(
        themeMode: _themeMode,
        audioQuality: _audioQuality,
        advancedSettings: _advancedSettings,
      );

  // 歌词设置的 getter
  LyricSettings get lyricSettings => _lyricSettings;

  // 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  // 设置音质
  Future<void> setAudioQuality(String quality) async {
    _audioQuality = quality;
    await _prefs.setString('audioQuality', quality);
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

  // PC 模式设置
  Future<void> setPCMode(bool isPCMode) async {
    _isPCMode = isPCMode;
    await _prefs.setBool('pcMode', isPCMode);
    notifyListeners();
  }

  // 设置播放器类型
  Future<void> setPlayerType(PlayerType playerType) async {
    final newSettings = _advancedSettings.copyWith(playerType: playerType);
    await updateAdvancedSettings(newSettings);
  }

  // 设置交叉淡入淡出
  Future<void> setCrossfade(bool enabled, {double duration = 2.0}) async {
    final newSettings = _advancedSettings.copyWith(
      enableCrossfade: enabled,
      crossfadeDuration: duration,
    );
    await updateAdvancedSettings(newSettings);
  }

  // 更新歌词设置
  Future<void> updateLyricSettings({
    LyricSource? defaultSource,
    bool? autoSync,
    double? fontSize,
  }) async {
    if (defaultSource != null) {
      _lyricSettings.defaultSource = defaultSource;
      await _prefs.setInt('lyricSource', defaultSource.index);
    }

    if (autoSync != null) {
      _lyricSettings.autoSync = autoSync;
      await _prefs.setBool('lyricAutoSync', autoSync);
    }

    if (fontSize != null) {
      _lyricSettings.fontSize = fontSize;
      await _prefs.setDouble('lyricFontSize', fontSize);
    }

    notifyListeners();
  }
}

// 新增歌词设置模型
class LyricSettings {
  LyricSource defaultSource;
  bool autoSync;
  double fontSize;

  LyricSettings({
    this.defaultSource = LyricSource.netease,
    this.autoSync = true,
    this.fontSize = 16.0,
  });
}

// 枚举定义移到单独的文件
enum LyricSource { bilibili, netease, manual }
