import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:json_annotation/json_annotation.dart';

part 'advanced_settings.g.dart';

/// 音频API来源枚举
/// 定义获取音频的不同方式
@JsonEnum()
enum AudioApiSource {
  /// 第三方解析API（如 mir6）
  @JsonValue('mir6')
  mir6,

  /// 官方B站API
  @JsonValue('official')
  official,
}

/// 播放模式枚举
/// 控制音频/视频播放的顺序和重复方式
@JsonEnum()
enum PlaybackMode {
  /// 顺序播放：按列表顺序依次播放
  @JsonValue('sequential')
  sequential,

  /// 循环播放：重复播放当前列表
  @JsonValue('loop')
  loop,

  /// 随机播放：随机播放列表中的项目
  @JsonValue('random')
  random,
}

/// 播放器类型枚举
/// 定义播放媒体的方式
@JsonEnum()
enum PlayerType {
  /// 原生播放器：使用应用内置播放器
  @JsonValue('native')
  native,

  /// 外部播放器：调用系统默认播放器
  @JsonValue('externalPlayer')
  externalPlayer,
}

/// 高级设置模型
/// 包含应用的详细配置选项
@JsonSerializable()
class AdvancedSettings {
  /// 音频API来源
  final AudioApiSource audioApiSource;

  /// 音量大小（0.0 - 1.0）
  final double volume;

  /// 播放速度
  final double playbackSpeed;

  /// 播放模式
  final PlaybackMode playbackMode;

  /// 是否使用硬件解码
  final bool useHardwareDecoding;

  /// 是否启用无缝播放
  final bool enableGaplessPlayback;

  /// 是否下载高品质音频
  final bool downloadHighQualityAudio;

  /// 是否启用调试日志
  final bool enableDebugLogging;

  /// 播放器类型
  final PlayerType playerType;

  /// 是否启用交叉淡入淡出
  final bool enableCrossfade;

  /// 交叉淡入淡出持续时间（秒）
  final double crossfadeDuration;

  /// 构造函数，提供默认值
  const AdvancedSettings({
    this.audioApiSource = AudioApiSource.mir6,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.playbackMode = PlaybackMode.sequential,
    this.useHardwareDecoding = true,
    this.enableGaplessPlayback = false,
    this.downloadHighQualityAudio = true,
    this.enableDebugLogging = false,
    this.playerType = PlayerType.native,
    this.enableCrossfade = false,
    this.crossfadeDuration = 2.0,
  });

  /// 创建一个新的 AdvancedSettings 实例，可以部分覆盖现有设置
  AdvancedSettings copyWith({
    AudioApiSource? audioApiSource,
    double? volume,
    double? playbackSpeed,
    PlaybackMode? playbackMode,
    bool? useHardwareDecoding,
    bool? enableGaplessPlayback,
    bool? downloadHighQualityAudio,
    bool? enableDebugLogging,
    PlayerType? playerType,
    bool? enableCrossfade,
    double? crossfadeDuration,
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
      playerType: playerType ?? this.playerType,
      enableCrossfade: enableCrossfade ?? this.enableCrossfade,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
    );
  }

  /// 从 JSON 反序列化
  factory AdvancedSettings.fromJson(Map<String, dynamic> json) =>
      _$AdvancedSettingsFromJson(json);

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => _$AdvancedSettingsToJson(this);

  /// 相等性比较
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedSettings &&
          audioApiSource == other.audioApiSource &&
          volume == other.volume &&
          playbackSpeed == other.playbackSpeed &&
          playbackMode == other.playbackMode &&
          useHardwareDecoding == other.useHardwareDecoding &&
          enableGaplessPlayback == other.enableGaplessPlayback &&
          downloadHighQualityAudio == other.downloadHighQualityAudio &&
          enableDebugLogging == other.enableDebugLogging &&
          playerType == other.playerType &&
          enableCrossfade == other.enableCrossfade &&
          crossfadeDuration == other.crossfadeDuration;

  /// 哈希码
  @override
  int get hashCode =>
      audioApiSource.hashCode ^
      volume.hashCode ^
      playbackSpeed.hashCode ^
      playbackMode.hashCode ^
      useHardwareDecoding.hashCode ^
      enableGaplessPlayback.hashCode ^
      downloadHighQualityAudio.hashCode ^
      enableDebugLogging.hashCode ^
      playerType.hashCode ^
      enableCrossfade.hashCode ^
      crossfadeDuration.hashCode;
}
