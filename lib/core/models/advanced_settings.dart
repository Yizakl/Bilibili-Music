import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AudioApiSource {
  thirdParty, // 第三方解析API
  official, // 官方API
}

class AdvancedSettings {
  final AudioApiSource audioApiSource;
  final bool useHardwareDecoding;
  final bool enableGaplessPlayback;
  final bool downloadHighQualityAudio;
  final bool enableDebugLogging;

  const AdvancedSettings({
    this.audioApiSource = AudioApiSource.thirdParty,
    this.useHardwareDecoding = true,
    this.enableGaplessPlayback = true,
    this.downloadHighQualityAudio = true,
    this.enableDebugLogging = false,
  });

  // 复制并修改
  AdvancedSettings copyWith({
    AudioApiSource? audioApiSource,
    bool? useHardwareDecoding,
    bool? enableGaplessPlayback,
    bool? downloadHighQualityAudio,
    bool? enableDebugLogging,
  }) {
    return AdvancedSettings(
      audioApiSource: audioApiSource ?? this.audioApiSource,
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
      audioApiSource: AudioApiSource.values[json['audioApiSource'] ?? 0],
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
      'useHardwareDecoding': useHardwareDecoding,
      'enableGaplessPlayback': enableGaplessPlayback,
      'downloadHighQualityAudio': downloadHighQualityAudio,
      'enableDebugLogging': enableDebugLogging,
    };
  }
}
