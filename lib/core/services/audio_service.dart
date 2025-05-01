import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  
  // 使用固定的默认封面图片
  static const String _defaultArtUrl = 'https://i0.hdslb.com/bfs/archive/0b2557b186a418cb3d8f307a5db85adb87bb25b0.jpg';

  // 流暴露给UI层
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<bool> get playingStream => _audioPlayer.playingStream;
  
  // 当前状态获取
  Duration get position => _audioPlayer.position;
  Duration? get duration => _audioPlayer.duration;
  bool get playing => _audioPlayer.playing;
  
  // 音量控制
  double get volume => _audioPlayer.volume;
  set volume(double value) => _audioPlayer.setVolume(value);
  
  // 播放速度
  double get speed => _audioPlayer.speed;
  set speed(double value) => _audioPlayer.setSpeed(value);
  
  // 循环模式
  LoopMode get loopMode => _audioPlayer.loopMode;
  set loopMode(LoopMode mode) => _audioPlayer.setLoopMode(mode);

  // 初始化播放器
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 设置一个默认的媒体项，避免null报错
      final defaultMediaItem = MediaItem(
        id: 'default_id',
        title: '准备中...',
        artist: 'Bilibili Music',
      );
      
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse('https://example.com/empty.mp3'),
          tag: defaultMediaItem,
        ),
      );
      
      _isInitialized = true;
      debugPrint('AudioPlayer初始化成功');
    } catch (e) {
      debugPrint('AudioPlayer初始化失败: $e');
      throw Exception('音频播放器初始化失败: $e');
    }
  }

  // 播放音频
  Future<void> play({
    required String audioUrl,
    required String title,
    required String artist,
    String? artworkUrl,
    Map<String, dynamic>? extras,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // 创建MediaItem
      final mediaItem = MediaItem(
        id: audioUrl,
        title: title,
        artist: artist,
        artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
        extras: extras,
      );

      // 设置标题和艺术家等信息
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://www.bilibili.com/',
        'Origin': 'https://www.bilibili.com',
      };
      
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          tag: mediaItem,
          headers: headers,
        ),
      );
      
      await _audioPlayer.play();
      debugPrint('开始播放音频: $title');
    } catch (e) {
      debugPrint('播放音频失败: $e');
      throw Exception('无法播放音频: $e');
    }
  }

  // 暂停播放
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('暂停音频失败: $e');
    }
  }

  // 恢复播放
  Future<void> resume() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('恢复播放失败: $e');
    }
  }

  // 停止播放
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('停止音频失败: $e');
    }
  }

  // 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('音频定位失败: $e');
    }
  }

  // 设置循环模式
  Future<void> setLoopMode(LoopMode mode) async {
    try {
      await _audioPlayer.setLoopMode(mode);
    } catch (e) {
      debugPrint('设置循环模式失败: $e');
    }
  }

  // 设置音量
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('设置音量失败: $e');
    }
  }

  // 设置播放速度
  Future<void> setSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed.clamp(0.5, 2.0));
    } catch (e) {
      debugPrint('设置播放速度失败: $e');
    }
  }

  // 资源释放
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      _isInitialized = false;
      debugPrint('AudioPlayer已释放');
    } catch (e) {
      debugPrint('释放AudioPlayer失败: $e');
    }
  }
} 