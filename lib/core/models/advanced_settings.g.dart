// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advanced_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdvancedSettings _$AdvancedSettingsFromJson(Map<String, dynamic> json) =>
    AdvancedSettings(
      audioApiSource: $enumDecodeNullable(
              _$AudioApiSourceEnumMap, json['audioApiSource']) ??
          AudioApiSource.mir6,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      playbackMode:
          $enumDecodeNullable(_$PlaybackModeEnumMap, json['playbackMode']) ??
              PlaybackMode.sequential,
      useHardwareDecoding: json['useHardwareDecoding'] as bool? ?? true,
      enableGaplessPlayback: json['enableGaplessPlayback'] as bool? ?? false,
      downloadHighQualityAudio:
          json['downloadHighQualityAudio'] as bool? ?? true,
      enableDebugLogging: json['enableDebugLogging'] as bool? ?? false,
      playerType:
          $enumDecodeNullable(_$PlayerTypeEnumMap, json['playerType']) ??
              PlayerType.native,
      enableCrossfade: json['enableCrossfade'] as bool? ?? false,
      crossfadeDuration: (json['crossfadeDuration'] as num?)?.toDouble() ?? 2.0,
    );

Map<String, dynamic> _$AdvancedSettingsToJson(AdvancedSettings instance) =>
    <String, dynamic>{
      'audioApiSource': _$AudioApiSourceEnumMap[instance.audioApiSource]!,
      'volume': instance.volume,
      'playbackSpeed': instance.playbackSpeed,
      'playbackMode': _$PlaybackModeEnumMap[instance.playbackMode]!,
      'useHardwareDecoding': instance.useHardwareDecoding,
      'enableGaplessPlayback': instance.enableGaplessPlayback,
      'downloadHighQualityAudio': instance.downloadHighQualityAudio,
      'enableDebugLogging': instance.enableDebugLogging,
      'playerType': _$PlayerTypeEnumMap[instance.playerType]!,
      'enableCrossfade': instance.enableCrossfade,
      'crossfadeDuration': instance.crossfadeDuration,
    };

const _$AudioApiSourceEnumMap = {
  AudioApiSource.mir6: 'mir6',
  AudioApiSource.official: 'official',
};

const _$PlaybackModeEnumMap = {
  PlaybackMode.sequential: 'sequential',
  PlaybackMode.loop: 'loop',
  PlaybackMode.random: 'random',
};

const _$PlayerTypeEnumMap = {
  PlayerType.native: 'native',
  PlayerType.externalPlayer: 'externalPlayer',
};
