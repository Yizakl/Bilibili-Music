import 'package:flutter/material.dart';
import 'advanced_settings.dart';

class Settings {
  final ThemeMode themeMode;
  final String audioQuality;
  final AdvancedSettings advancedSettings;

  const Settings({
    this.themeMode = ThemeMode.system,
    this.audioQuality = 'standard',
    this.advancedSettings = const AdvancedSettings(),
  });

  double get volume => advancedSettings.volume;
  double get playbackSpeed => advancedSettings.playbackSpeed;

  Settings copyWith({
    ThemeMode? themeMode,
    String? audioQuality,
    AdvancedSettings? advancedSettings,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      audioQuality: audioQuality ?? this.audioQuality,
      advancedSettings: advancedSettings ?? this.advancedSettings,
    );
  }
}
