import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AudioApiSource {
  thirdParty, // 第三方解析API
  official, // 官方API
}

// 新增播放模式枚举
enum PlaybackMode {
  audioOnly, // 仅音频 (默认)
  videoAsAudio, // 视频模式 (仅音频)
}

class AdvancedSettings {
  final AudioApiSource audioApiSource;
  final double volume;
  final double playbackSpeed;
  final PlaybackMode playbackMode;
  final bool useHardwareDecoding;
  final bool enableGaplessPlayback;
  final bool downloadHighQualityAudio;
  final bool enableDebugLogging;

  const AdvancedSettings({
    this.audioApiSource = AudioApiSource.thirdParty,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.playbackMode = PlaybackMode.audioOnly,
    this.useHardwareDecoding = true,
    this.enableGaplessPlayback = true,
    this.downloadHighQualityAudio = true,
    this.enableDebugLogging = false,
  });

  // 复制并修改
  AdvancedSettings copyWith({
    AudioApiSource? audioApiSource,
    double? volume,
    double? playbackSpeed,
    PlaybackMode? playbackMode,
    bool? useHardwareDecoding,
    bool? enableGaplessPlayback,
    bool? downloadHighQualityAudio,
    bool? enableDebugLogging,
  }) {
    return AdvancedSettings(
      audioApiSource: audioApiSource ?? this.audioApiSource,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      playbackMode: playbackMode ?? this.playbackMode,
      useHardwareDecoding: useHardwareDecoding ?? this.useHardwareDecoding,
      enableGaplessPlayback:
          enableGaplessPlayback ?? this.enableGaplessPlayback,
      downloadHighQualityAudio:
          downloadHighQualityAudio ?? this.downloadHighQualityAudio,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
    );
  }

  // 从JSON
  factory AdvancedSettings.fromJson(Map<String, dynamic> json) {
    return AdvancedSettings(
      audioApiSource: AudioApiSource
          .values[json['audioApiSource'] ?? AudioApiSource.thirdParty.index],
      volume: json['volume'] as double? ?? 1.0,
      playbackSpeed: json['playbackSpeed'] as double? ?? 1.0,
      playbackMode: PlaybackMode
          .values[json['playbackMode'] ?? PlaybackMode.audioOnly.index],
      useHardwareDecoding: json['useHardwareDecoding'] ?? true,
      enableGaplessPlayback: json['enableGaplessPlayback'] ?? true,
      downloadHighQualityAudio: json['downloadHighQualityAudio'] ?? true,
      enableDebugLogging: json['enableDebugLogging'] ?? false,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'audioApiSource': audioApiSource.index,
      'volume': volume,
      'playbackSpeed': playbackSpeed,
      'playbackMode': playbackMode.index,
      'useHardwareDecoding': useHardwareDecoding,
      'enableGaplessPlayback': enableGaplessPlayback,
      'downloadHighQualityAudio': downloadHighQualityAudio,
      'enableDebugLogging': enableDebugLogging,
    };
  }
}
