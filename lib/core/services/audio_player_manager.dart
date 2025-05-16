import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../features/player/models/audio_item.dart';
import '../models/advanced_settings.dart';
import 'settings_service.dart';
import '../models/settings.dart';

class AudioPlayerManager extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SettingsService _settingsService;

  // 内部状态变量
  String? _currentUrl;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;
  int _currentIndex = -1;
  bool _isShuffleMode = false;
  bool _isLoopMode = false;
  AudioItem? _currentAudio;

  // UI 状态通知器
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>('点击播放');
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<List<AudioItem>> playlistNotifier =
      ValueNotifier<List<AudioItem>>([]);
  final ValueNotifier<AudioItem?> currentItemNotifier =
      ValueNotifier<AudioItem?>(null);
  final ValueNotifier<double> playbackSpeedNotifier =
      ValueNotifier<double>(1.0);

  // 添加一个标志来防止意外暂停
  bool _preventAutoStop = false;

  // Getters
  String? get currentUrl => _currentUrl;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  double get speed => _speed;
  List<AudioItem> get playlist => playlistNotifier.value;
  int get currentIndex => _currentIndex;
  AudioItem? get currentItem => currentItemNotifier.value;
  bool get isShuffleMode => _isShuffleMode;
  bool get isLoopMode => _isLoopMode;
  AudioItem? get currentAudio => _currentAudio;

  // 计算播放进度
  double get progress {
    if (_duration.inMilliseconds <= 0) return 0.0;
    final value = _position.inMilliseconds / _duration.inMilliseconds;
    return value.clamp(0.0, 1.0);
  }

  AudioPlayerManager(this._settingsService) {
    _initAudioPlayer();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = _settingsService.settings;
    _volume = settings.volume;
    _speed = settings.playbackSpeed;
    volumeNotifier.value = _volume;
    playbackSpeedNotifier.value = _speed;
  }

  Future<void> _initAudioPlayer() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // 配置音频会话
      await session.setActive(true);

      // 配置音频中断处理
      final sessionId = await _audioPlayer.androidAudioSessionId;
      if (sessionId != null && kDebugMode) {
        print('音频会话ID: $sessionId');
      }

      // 播放状态监听
      _audioPlayer.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        isPlayingNotifier.value = _isPlaying;

        switch (state.processingState) {
          case ProcessingState.loading:
          case ProcessingState.buffering:
            statusNotifier.value = '音频缓冲中...';
            isLoadingNotifier.value = true;
            break;
          case ProcessingState.ready:
            statusNotifier.value = _isPlaying ? '正在播放' : '已暂停';
            isLoadingNotifier.value = false;
            break;
          case ProcessingState.completed:
            statusNotifier.value = '播放完成';
            isLoadingNotifier.value = false;
            _position = Duration.zero;
            positionNotifier.value = _position;
            if (_isLoopMode || _currentIndex < playlist.length - 1) {
              playNext();
            }
            break;
          case ProcessingState.idle:
            statusNotifier.value = '播放器就绪';
            isLoadingNotifier.value = false;
            break;
        }
      });

      // 播放事件监听
      _audioPlayer.playbackEventStream.listen(
        (event) {
          _duration = event.duration ?? Duration.zero;
          durationNotifier.value = _duration;

          // 更新通知栏信息
          if (_currentAudio != null) {
            final mediaItem = MediaItem(
              id: _currentAudio!.id,
              title: _currentAudio!.title,
              artist: _currentAudio!.uploader,
              artUri: Uri.parse(_currentAudio!.thumbnail),
              displayTitle: _currentAudio!.title,
              displaySubtitle: _currentAudio!.uploader,
              duration: _duration,
              album: '哔哩哔哩音乐',
            );
            // 通知栏信息会自动更新
          }
        },
        onError: (Object e, StackTrace stackTrace) {
          if (kDebugMode) {
            print('播放器错误: $e');
            print(stackTrace);
          }
          statusNotifier.value = '播放出错: $e';
        },
      );

      // 播放位置监听
      _audioPlayer.positionStream.listen((position) {
        _position = position;
        positionNotifier.value = position;
      });

      // 初始化音量和播放速度
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setSpeed(_speed);

      if (kDebugMode) {
        print('音频播放器初始化成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('初始化音频播放器失败: $e');
      }
      statusNotifier.value = '初始化失败: $e';
    }
  }

  Future<void> playAudio(AudioItem item, {bool forceRestart = false}) async {
    // 如果当前正在播放同一个音频，且不强制重新开始，则不执行重新播放
    if (!forceRestart &&
        _currentAudio != null &&
        _currentAudio!.id == item.id &&
        _isPlaying) {
      return;
    }

    // 防止意外暂停
    _preventAutoStop = true;

    try {
      isLoadingNotifier.value = true;
      statusNotifier.value = '准备播放...';
      _currentUrl = item.audioUrl;
      _currentAudio = item;
      currentItemNotifier.value = item;

      // 先停止当前播放
      await _audioPlayer.stop();

      // 重置状态
      _position = Duration.zero;
      positionNotifier.value = _position;

      // 设置音频源
      final audioSource = AudioSource.uri(
        Uri.parse(item.audioUrl),
        tag: MediaItem(
          id: item.id,
          title: item.title,
          artist: item.uploader,
          artUri: Uri.parse(item.thumbnail),
          displayTitle: item.title,
          displaySubtitle: item.uploader,
          album: '哔哩哔哩音乐',
        ),
      );

      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setSpeed(_speed);

      // 开始播放
      await _audioPlayer.play();
      _isPlaying = true;
      isPlayingNotifier.value = true;
      statusNotifier.value = '正在播放';

      // 更新播放列表状态
      if (!playlist.contains(item)) {
        playlistNotifier.value = [...playlist, item];
        _currentIndex = playlist.length - 1;
      } else {
        _currentIndex = playlist.indexOf(item);
      }
    } catch (e) {
      debugPrint('播放失败: $e');
      statusNotifier.value = '播放失败: $e';
      isLoadingNotifier.value = false;
      _isPlaying = false;
      isPlayingNotifier.value = false;
    } finally {
      _preventAutoStop = false;
    }
  }

  Future<void> playAudioWithCustomHeaders(
    AudioItem item, {
    required Map<String, String> headers,
  }) async {
    if (item.audioUrl.isEmpty) {
      statusNotifier.value = '无效的音频链接';
      return;
    }

    try {
      isLoadingNotifier.value = true;
      statusNotifier.value = '准备播放...';
      _currentUrl = item.audioUrl;
      _currentAudio = item;
      currentItemNotifier.value = item;

      // 先停止当前播放
      await _audioPlayer.stop();

      // 重置状态
      _position = Duration.zero;
      positionNotifier.value = _position;

      // 设置音频源
      try {
        final audioSource = AudioSource.uri(
          Uri.parse(item.audioUrl),
          tag: MediaItem(
            id: item.id,
            title: item.title,
            artist: item.uploader,
            artUri: Uri.parse(item.thumbnail),
            displayTitle: item.title,
            displaySubtitle: item.uploader,
            album: '哔哩哔哩音乐',
          ),
          headers: headers,
        );

        await _audioPlayer.setAudioSource(audioSource);

        // 设置音量和播放速度
        await _audioPlayer.setVolume(_volume);
        await _audioPlayer.setSpeed(_speed);

        // 开始播放
        await _audioPlayer.play();

        _isPlaying = true;
        isPlayingNotifier.value = true;
        statusNotifier.value = '正在播放';

        // 更新播放列表状态
        if (!playlist.contains(item)) {
          playlistNotifier.value = [...playlist, item];
          _currentIndex = playlist.length - 1;
        } else {
          _currentIndex = playlist.indexOf(item);
        }
      } catch (e) {
        debugPrint('设置音频源失败: $e');
        statusNotifier.value = '音频加载失败，请重试';
        isLoadingNotifier.value = false;
        return;
      }
    } catch (e) {
      debugPrint('播放失败: $e');
      statusNotifier.value = '播放失败: $e';
      isLoadingNotifier.value = false;
      _isPlaying = false;
      isPlayingNotifier.value = false;
    }
  }

  Future<void> pause() async {
    if (_preventAutoStop) return;

    await _audioPlayer.pause();
    _isPlaying = false;
    isPlayingNotifier.value = false;
  }

  Future<void> resume() async {
    if (!_isPlaying && _currentUrl != null) {
      try {
        await _audioPlayer.play();
        _isPlaying = true;
        isPlayingNotifier.value = true;
        statusNotifier.value = '正在播放';
      } catch (e) {
        if (kDebugMode) {
          print('恢复播放失败: $e');
        }
        statusNotifier.value = '恢复播放失败: $e';
        _isPlaying = false;
        isPlayingNotifier.value = false;
      }
    }
  }

  Future<void> stopAudio() async {
    if (_preventAutoStop) return;

    try {
      await _audioPlayer.stop();
      _currentUrl = null;
      _currentAudio = null;
      currentItemNotifier.value = null;
      _position = Duration.zero;
      positionNotifier.value = _position;
      _isPlaying = false;
      isPlayingNotifier.value = false;
      statusNotifier.value = '已停止';
    } catch (e) {
      if (kDebugMode) {
        print('停止播放失败: $e');
      }
      statusNotifier.value = '停止播放失败: $e';
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    _position = position;
    positionNotifier.value = position;
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    volumeNotifier.value = _volume;
    await _audioPlayer.setVolume(_volume);
  }

  Future<void> setSpeed(double speed) async {
    final validSpeed = speed.clamp(0.5, 2.0);
    _speed = validSpeed;
    playbackSpeedNotifier.value = validSpeed;
    await _audioPlayer.setSpeed(validSpeed);
  }

  void setPlaylist(List<AudioItem> items, {int startIndex = 0}) {
    playlistNotifier.value = List.from(items);
    if (items.isNotEmpty && startIndex >= 0 && startIndex < items.length) {
      _currentIndex = startIndex;
      final item = items[startIndex];
      playAudio(item);
    }
  }

  void playNext() {
    if (playlist.isEmpty) return;

    if (_isShuffleMode) {
      // 随机播放模式
      final currentIndex = playlist.indexOf(_currentAudio!);
      final availableIndices = List<int>.generate(playlist.length, (i) => i)
        ..removeAt(currentIndex);
      if (availableIndices.isEmpty) return;

      final randomIndex = availableIndices[
          DateTime.now().millisecondsSinceEpoch % availableIndices.length];
      final item = playlist[randomIndex];
      _currentIndex = randomIndex;
      playAudio(item);
    } else {
      // 顺序播放模式
      if (_currentIndex >= playlist.length - 1) {
        if (_isLoopMode) {
          _currentIndex = 0;
        } else {
          return;
        }
      } else {
        _currentIndex++;
      }
      final item = playlist[_currentIndex];
      playAudio(item);
    }
  }

  void playPrevious() {
    if (playlist.isEmpty) return;

    if (_isShuffleMode) {
      // 随机播放模式
      final currentIndex = playlist.indexOf(_currentAudio!);
      final availableIndices = List<int>.generate(playlist.length, (i) => i)
        ..removeAt(currentIndex);
      if (availableIndices.isEmpty) return;

      final randomIndex = availableIndices[
          DateTime.now().millisecondsSinceEpoch % availableIndices.length];
      final item = playlist[randomIndex];
      _currentIndex = randomIndex;
      playAudio(item);
    } else {
      // 顺序播放模式
      if (_currentIndex <= 0) {
        if (_isLoopMode) {
          _currentIndex = playlist.length - 1;
        } else {
          return;
        }
      } else {
        _currentIndex--;
      }
      final item = playlist[_currentIndex];
      playAudio(item);
    }
  }

  void addToPlaylist(List<AudioItem> items) {
    final newList = List<AudioItem>.from(playlistNotifier.value)..addAll(items);
    playlistNotifier.value = newList;
  }

  void removeFromPlaylist(String id) {
    final index = playlist.indexWhere((item) => item.id == id);
    if (index < 0) return;
    removeFromPlaylistByIndex(index);
  }

  void removeFromPlaylistByIndex(int index) {
    if (index < 0 || index >= playlist.length) return;

    final newList = List<AudioItem>.from(playlist);
    newList.removeAt(index);
    playlistNotifier.value = newList;

    if (index == _currentIndex) {
      if (newList.isEmpty) {
        stopAudio();
        _currentIndex = -1;
      } else {
        _currentIndex = _currentIndex.clamp(0, newList.length - 1);
        final item = newList[_currentIndex];
        playAudio(item);
      }
    } else if (index < _currentIndex) {
      _currentIndex--;
    }
  }

  void clearPlaylist() {
    playlistNotifier.value = [];
    _currentIndex = -1;
    stopAudio();
  }

  void toggleShuffleMode() {
    _isShuffleMode = !_isShuffleMode;
    notifyListeners();
  }

  void toggleLoopMode() {
    _isLoopMode = !_isLoopMode;
    notifyListeners();
  }

  // 添加一个方法来检查当前是否正在播放
  bool get isCurrentlyPlaying => _isPlaying && _currentAudio != null;

  @override
  void dispose() {
    _audioPlayer.stop().then((_) {
      _audioPlayer.dispose();
    });
    isPlayingNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    statusNotifier.dispose();
    isLoadingNotifier.dispose();
    volumeNotifier.dispose();
    playlistNotifier.dispose();
    currentItemNotifier.dispose();
    playbackSpeedNotifier.dispose();
    super.dispose();
  }
}
