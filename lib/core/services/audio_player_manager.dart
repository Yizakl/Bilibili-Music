import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../features/player/models/audio_item.dart';
import 'dart:async';

class AudioPlayerManager extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioItem? _currentAudio;
  bool _isPlaying = false;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _processingStateSubscription;

  // 当前音频播放状态的ValueNotifier
  final ValueNotifier<AudioItem?> currentAudioNotifier =
      ValueNotifier<AudioItem?>(null);

  AudioPlayerManager() {
    _initializePlayer();
  }

  void _initializePlayer() {
    // 监听播放状态
    _playbackStateSubscription = _audioPlayer.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
      debugPrint('播放状态改变: $playing');
    });

    // 监听处理状态
    _processingStateSubscription =
        _audioPlayer.processingStateStream.listen((state) {
      debugPrint('处理状态改变: $state');
      if (state == ProcessingState.completed) {
        // 播放完成后重置
        _isPlaying = false;
        notifyListeners();
      }
    });
  }

  AudioPlayer get player => _audioPlayer;
  bool get isPlaying => _isPlaying;
  AudioItem? get currentAudio => _currentAudio;

  // 播放新音频
  Future<void> playAudio(AudioItem audioItem) async {
    try {
      debugPrint('开始播放音频: ${audioItem.title}, URL: ${audioItem.audioUrl}');

      if (_currentAudio?.id != audioItem.id ||
          _currentAudio?.audioUrl != audioItem.audioUrl) {
        // 如果是不同的音频，则设置新的
        _currentAudio = audioItem;
        currentAudioNotifier.value = audioItem;

        // 停止当前播放
        await _audioPlayer.stop();

        // 设置音频源
        try {
          final audioSource = AudioSource.uri(
            Uri.parse(audioItem.audioUrl),
            tag: MediaItem(
              id: audioItem.id,
              title: audioItem.title,
              artist: audioItem.uploader,
              artUri: Uri.parse(audioItem.thumbnail),
            ),
          );

          await _audioPlayer.setAudioSource(audioSource);
          debugPrint('音频源设置成功');
        } catch (e) {
          debugPrint('设置音频URL失败, 尝试使用不同方式: $e');

          // 如果是mir6 API链接，可能需要等待跳转处理完成
          if (audioItem.audioUrl.contains('api.mir6.com')) {
            // 使用timeout防止长时间等待
            await _audioPlayer
                .setUrl(audioItem.audioUrl, preload: false)
                .timeout(const Duration(seconds: 10));
            debugPrint('mir6 API链接设置成功');
          }
        }
      }

      // 开始播放
      await _audioPlayer.play();
      _isPlaying = true;
      notifyListeners();
      debugPrint('音频播放成功');
    } catch (e) {
      debugPrint('播放音频失败: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  // 暂停播放
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      notifyListeners();
      debugPrint('音频已暂停');
    } catch (e) {
      debugPrint('暂停音频失败: $e');
    }
  }

  // 恢复播放
  Future<void> resume() async {
    try {
      if (_currentAudio != null) {
        await _audioPlayer.play();
        _isPlaying = true;
        notifyListeners();
        debugPrint('音频已恢复播放');
      }
    } catch (e) {
      debugPrint('恢复播放失败: $e');
    }
  }

  // 停止播放
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      notifyListeners();
      debugPrint('音频已停止');
    } catch (e) {
      debugPrint('停止音频失败: $e');
    }
  }

  // 释放资源
  @override
  void dispose() {
    _playbackStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _audioPlayer.dispose();
    currentAudioNotifier.dispose();
    super.dispose();
    debugPrint('AudioPlayerManager资源已释放');
  }
}
