import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  
  // 使用固定的默认封面图片
  static const String _defaultArtUrl = 'https://i0.hdslb.com/bfs/archive/0b2557b186a418cb3d8f307a5db85adb87bb25b0.jpg';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('初始化音频播放器...');
      
      // 使用一个空源初始化播放器
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse('https://example.com/empty.mp3'),
          tag: MediaItem(
            id: '0',
            album: 'Bilibili Music',
            title: 'No track selected',
            artist: 'Unknown',
            artUri: Uri.parse(_defaultArtUrl),
          ),
        ),
      );
      
      _isInitialized = true;
      debugPrint('音频播放器初始化成功');
    } catch (e) {
      debugPrint('初始化音频播放器失败: $e');
    }
  }

  Future<void> play(String url, String title, String artist, String? artUrl) async {
    try {
      debugPrint('准备播放音频: $title ($artist)');
      
      if (url.isEmpty) {
        debugPrint('错误: 音频URL为空');
        return;
      }
      
      // 确保 artUri 始终有效
      Uri artUri;
      try {
        artUri = Uri.parse(artUrl ?? _defaultArtUrl);
      } catch (e) {
        debugPrint('解析封面URL失败，使用默认封面: $e');
        artUri = Uri.parse(_defaultArtUrl);
      }
      
      // 确保所有 MediaItem 字段都是非空的
      final mediaItem = MediaItem(
        id: url,
        album: 'Bilibili Music',
        title: title.isNotEmpty ? title : '未知标题',
        artist: artist.isNotEmpty ? artist : '未知UP主',
        artUri: artUri,
      );
      
      // 确保播放器已初始化
      if (!_isInitialized) {
        await initialize();
      }
      
      debugPrint('设置音频源: $url');
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: mediaItem,
        ),
      );
      
      debugPrint('开始播放');
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('播放音频失败: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('暂停音频失败: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('恢复播放失败: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('停止播放失败: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('跳转到指定位置失败: $e');
    }
  }

  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<Duration?> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  void dispose() {
    _audioPlayer.dispose();
  }
} 