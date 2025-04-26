import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  
  // 定时关闭控制
  Duration? _sleepTimer;
  DateTime? _sleepTargetTime;
  
  // 获取当前播放状态
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  
  // 获取定时关闭剩余时间
  Duration? get remainingSleepTime {
    if (_sleepTargetTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(_sleepTargetTime!)) return Duration.zero;
    return _sleepTargetTime!.difference(now);
  }

  // 设置定时关闭
  Future<void> setSleepTimer(Duration? duration) async {
    _sleepTimer = duration;
    if (duration == null) {
      _sleepTargetTime = null;
      return;
    }
    
    _sleepTargetTime = DateTime.now().add(duration);
    await Future.delayed(duration, () {
      if (_sleepTargetTime != null) {
        pause();
        _sleepTimer = null;
        _sleepTargetTime = null;
      }
    });
  }

  // 播放控制
  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  
  // 设置音频源
  Future<void> setAudioSource(String url, {
    required String title,
    required String artist,
    String? artUrl,
  }) async {
    try {
      // 构建有效的 MediaItem
      final mediaItem = MediaItem(
        id: url, // 使用URL作为唯一标识符
        title: title,
        artist: artist,
        album: 'Bilibili Music', // 添加专辑信息
        artUri: artUrl != null && artUrl.isNotEmpty 
            ? Uri.parse(artUrl) 
            : Uri.parse('https://example.com/placeholder.png'), // 使用默认封面
      );

      debugPrint('Setting audio source: $url');
      
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: mediaItem,
        ),
      );
    } catch (e) {
      debugPrint('Error loading audio source: $e');
    }
  }

  // 释放资源
  void dispose() {
    _player.dispose();
  }
} 