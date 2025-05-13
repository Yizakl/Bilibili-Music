import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../../features/player/models/audio_item.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/video_item.dart';

class AudioPlayerManager extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio();
  AudioItem? _currentAudio;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffleMode = false;
  bool _isLoopMode = false;
  double _volume = 1.0;
  double _speed = 1.0;
  List<AudioItem> _playlist = [];
  int _currentIndex = -1;

  // 播放状态通知器
  final ValueNotifier<AudioItem?> currentAudioNotifier =
      ValueNotifier<AudioItem?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier =
      ValueNotifier<Duration>(Duration.zero);

  // 下载状态通知器
  final Map<String, ValueNotifier<double>> _downloadProgressNotifiers = {};
  final Map<String, ValueNotifier<String>> _downloadStatusNotifiers = {};

  // 收藏夹
  List<AudioItem> _favorites = [];

  VideoItem? _currentVideo;

  AudioPlayerManager() {
    _initAudioPlayer();
    _loadFavorites();
    _loadPlaylist();
  }

  void _initAudioPlayer() {
    // 监听播放状态
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      isPlayingNotifier.value = state.playing;

      // 确保iOS设备上保持音频会话活跃（修复后台播放问题）
      if (Platform.isIOS) {
        AudioSession.instance.then((session) {
          session.setActive(state.playing);
        });
      }

      // 更新通知栏状态
      if (state.playing) {
        _updateNotificationState();
      }

      notifyListeners();
    });

    // 监听播放位置
    _audioPlayer.positionStream.listen((position) {
      _position = position;
      positionNotifier.value = position;
      notifyListeners();
    });

    // 监听音频时长
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        durationNotifier.value = duration;
        notifyListeners();
      }
    });

    // 监听播放完成
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (_isLoopMode) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        } else {
          playNext();
        }
      }
    });
  }

  // 更新通知栏状态
  void _updateNotificationState() {
    if (_currentAudio != null) {
      // 确保通知栏显示正确的播放状态
      _audioPlayer
          .setAudioSource(
        _audioPlayer.audioSource!,
        preload: false,
      )
          .then((_) {
        // 重新设置播放状态
        if (_isPlaying) {
          _audioPlayer.play();
        }
      });
    }
  }

  // 播放音频
  Future<void> playAudio(AudioItem audioItem) async {
    try {
      if (_currentAudio?.id == audioItem.id) {
        if (!_isPlaying) {
          await _audioPlayer.play();
          _isPlaying = true;
          isPlayingNotifier.value = true;
          _updateNotificationState();
        }
        return;
      }

      _currentAudio = audioItem;
      currentAudioNotifier.value = audioItem;

      // 更新播放列表中的当前索引
      _currentIndex = _playlist.indexWhere((item) => item.id == audioItem.id);
      if (_currentIndex == -1) {
        _playlist.add(audioItem);
        _currentIndex = _playlist.length - 1;
      }

      // 停止当前播放
      await _audioPlayer.stop();

      // 检查是否有本地文件
      final localFilePath = await getLocalAudioPath(audioItem.id);
      final localFile = File(localFilePath);

      // 创建MediaItem
      final mediaItem = MediaItem(
        id: audioItem.id,
        title: audioItem.title,
        artist: audioItem.uploader,
        artUri: Uri.parse(audioItem.fixedThumbnail),
        album: 'Bilibili Music',
        displayTitle: audioItem.title,
        displaySubtitle: audioItem.uploader,
      );

      if (await localFile.exists()) {
        // 使用本地文件播放
        final audioSource = AudioSource.uri(
          Uri.file(localFilePath),
          tag: mediaItem,
        );
        await _audioPlayer.setAudioSource(audioSource);
      } else {
        // 使用在线URL播放
        final audioSource = AudioSource.uri(
          Uri.parse(audioItem.audioUrl),
          tag: mediaItem,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com/',
            'Origin': 'https://www.bilibili.com',
          },
        );
        await _audioPlayer.setAudioSource(audioSource);
      }

      await _audioPlayer.play();
      _isPlaying = true;
      isPlayingNotifier.value = true;
      _updateNotificationState();
      notifyListeners();
    } catch (e) {
      debugPrint('播放音频失败: $e');
      _isPlaying = false;
      isPlayingNotifier.value = false;
      notifyListeners();
    }
  }

  // 暂停播放
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      isPlayingNotifier.value = false;
      _updateNotificationState();
      notifyListeners();
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
        isPlayingNotifier.value = true;
        _updateNotificationState();
        notifyListeners();
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
    } catch (e) {
      debugPrint('停止音频失败: $e');
    }
  }

  // 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('跳转失败: $e');
    }
  }

  // 设置音量
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume);
      _volume = volume;
      notifyListeners();
    } catch (e) {
      debugPrint('设置音量失败: $e');
    }
  }

  // 设置播放速度
  Future<void> setSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
      _speed = speed;
      notifyListeners();
    } catch (e) {
      debugPrint('设置播放速度失败: $e');
    }
  }

  // 切换循环模式
  Future<void> toggleLoopMode() async {
    _isLoopMode = !_isLoopMode;
    await _audioPlayer.setLoopMode(_isLoopMode ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  // 切换随机播放
  Future<void> toggleShuffleMode() async {
    _isShuffleMode = !_isShuffleMode;
    await _audioPlayer.setShuffleModeEnabled(_isShuffleMode);
    notifyListeners();
  }

  // 播放下一首
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    int nextIndex;
    if (_isShuffleMode) {
      nextIndex = _getRandomIndex();
    } else {
      nextIndex = (_currentIndex + 1) % _playlist.length;
    }

    if (nextIndex != _currentIndex) {
      _currentIndex = nextIndex;
      await playAudio(_playlist[_currentIndex]);
    }
  }

  // 播放上一首
  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    int previousIndex;
    if (_isShuffleMode) {
      previousIndex = _getRandomIndex();
    } else {
      previousIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    }

    if (previousIndex != _currentIndex) {
      _currentIndex = previousIndex;
      await playAudio(_playlist[_currentIndex]);
    }
  }

  // 获取随机索引
  int _getRandomIndex() {
    if (_playlist.length <= 1) return 0;
    int randomIndex;
    do {
      randomIndex = DateTime.now().millisecondsSinceEpoch % _playlist.length;
    } while (randomIndex == _currentIndex);
    return randomIndex;
  }

  // 获取本地音频文件路径
  Future<String> getLocalAudioPath(String audioId) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$audioId.mp3';
  }

  // 保存播放列表
  Future<void> _savePlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistJson = _playlist.map((item) => item.toJson()).toList();
      await prefs.setString('playlist', jsonEncode(playlistJson));
    } catch (e) {
      debugPrint('保存播放列表失败: $e');
    }
  }

  // 加载播放列表
  Future<void> _loadPlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistJson = prefs.getString('playlist');
      if (playlistJson != null) {
        final List<dynamic> decoded = jsonDecode(playlistJson);
        _playlist = decoded.map((item) => AudioItem.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载播放列表失败: $e');
    }
  }

  // 获取当前播放的音频
  AudioItem? get currentAudio => _currentAudio;

  // 获取播放状态
  bool get isPlaying => _isPlaying;

  // 获取当前播放位置
  Duration get position => _position;

  // 获取音频总时长
  Duration get duration => _duration;

  // 获取音量
  double get volume => _volume;

  // 获取播放速度
  double get speed => _speed;

  // 获取循环模式状态
  bool get isLoopMode => _isLoopMode;

  // 获取随机播放状态
  bool get isShuffleMode => _isShuffleMode;

  // 获取播放列表
  List<AudioItem> get playlist => _playlist;

  // 获取当前索引
  int get currentIndex => _currentIndex;

  // 获取播放进度比例
  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0.0;

  // 从本地存储加载收藏夹
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? favoritesJson = prefs.getStringList('favorites');
      if (favoritesJson != null) {
        _favorites = favoritesJson
            .map((itemJson) => AudioItem.fromJson(json.decode(itemJson)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载收藏夹失败: $e');
    }
  }

  // 添加到收藏夹
  Future<void> addToFavorites(AudioItem audioItem) async {
    if (!_favorites.any((item) => item.id == audioItem.id)) {
      _favorites.add(audioItem);
      await _saveFavorites();
      notifyListeners();
    }
  }

  // 从收藏夹移除
  Future<void> removeFromFavorites(String audioId) async {
    _favorites.removeWhere((item) => item.id == audioId);
    await _saveFavorites();
    notifyListeners();
  }

  // 检查是否已收藏
  bool isFavorite(String audioId) {
    return _favorites.any((item) => item.id == audioId);
  }

  // 保存收藏夹到本地存储
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> favoritesJson =
          _favorites.map((item) => json.encode(item.toJson())).toList();
      await prefs.setStringList('favorites', favoritesJson);
    } catch (e) {
      debugPrint('保存收藏夹失败: $e');
    }
  }

  // 下载音频
  Future<bool> downloadAudio(AudioItem audioItem) async {
    // 检查存储权限
    if (!await _checkStoragePermission()) {
      return false;
    }

    final String audioId = audioItem.id;

    // 创建下载状态通知器
    _downloadProgressNotifiers[audioId] = ValueNotifier(0.0);
    _downloadStatusNotifiers[audioId] = ValueNotifier('正在准备下载...');

    try {
      // 获取下载目录
      final directory = await getApplicationDocumentsDirectory();
      final savePath = '${directory.path}/audios/$audioId.mp3';

      // 创建目录
      final saveDir = Directory('${directory.path}/audios');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 检查文件是否已存在
      final file = File(savePath);
      if (await file.exists()) {
        _downloadStatusNotifiers[audioId]!.value = '文件已存在';
        _downloadProgressNotifiers[audioId]!.value = 1.0;
        return true;
      }

      // 开始下载
      _downloadStatusNotifiers[audioId]!.value = '正在下载...';

      await _dio.download(
        audioItem.audioUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _downloadProgressNotifiers[audioId]!.value = progress;
            _downloadStatusNotifiers[audioId]!.value =
                '下载中: ${(progress * 100).toStringAsFixed(0)}%';
          }
        },
      );

      _downloadStatusNotifiers[audioId]!.value = '下载完成';
      _downloadProgressNotifiers[audioId]!.value = 1.0;

      return true;
    } catch (e) {
      debugPrint('下载音频失败: $e');
      _downloadStatusNotifiers[audioId]!.value = '下载失败: $e';
      return false;
    }
  }

  // 获取下载进度通知器
  ValueNotifier<double>? getDownloadProgressNotifier(String audioId) {
    return _downloadProgressNotifiers[audioId];
  }

  // 获取下载状态通知器
  ValueNotifier<String>? getDownloadStatusNotifier(String audioId) {
    return _downloadStatusNotifiers[audioId];
  }

  // 检查音频是否已下载
  Future<bool> isAudioDownloaded(String audioId) async {
    final path = await getLocalAudioPath(audioId);
    return await File(path).exists();
  }

  // 检查存储权限
  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      return true; // iOS不需要显式请求存储权限
    }
    return false;
  }

  // 释放资源
  @override
  void dispose() {
    _audioPlayer.dispose();
    currentAudioNotifier.dispose();
    isPlayingNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();

    // 清理下载进度通知器
    for (final notifier in _downloadProgressNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _downloadStatusNotifiers.values) {
      notifier.dispose();
    }

    super.dispose();
    debugPrint('AudioPlayerManager资源已释放');
  }

  Future<void> playVideo(VideoItem video, String audioUrl) async {
    try {
      if (_currentVideo?.id != video.id) {
        _currentVideo = video;

        // 使用AudioSource.uri替代setUrl并添加MediaItem标签
        final audioSource = AudioSource.uri(
          Uri.parse(audioUrl),
          tag: MediaItem(
            id: video.id,
            title: video.title,
            artist: video.uploader,
            artUri: video.thumbnail != null ? Uri.parse(video.thumbnail) : null,
            album: 'Bilibili音频',
            displayTitle: video.title,
            displaySubtitle: video.uploader,
          ),
        );

        await _audioPlayer.setAudioSource(audioSource);
      }

      // 确保音频会话保持活跃
      await _audioPlayer.play();
      _isPlaying = true;
      isPlayingNotifier.value = true;

      debugPrint('音频播放成功');
      notifyListeners();
    } catch (e) {
      debugPrint('播放失败: $e');
      _isPlaying = false;
      isPlayingNotifier.value = false;
      notifyListeners();
    }
  }

  Future<void> toggleShuffle() async {
    _isShuffleMode = !_isShuffleMode;
    notifyListeners();
  }

  // 清空播放列表
  Future<void> clearPlaylist() async {
    _playlist.clear();
    _currentIndex = -1;
    await _savePlaylist();
    notifyListeners();
  }

  // 从播放列表中移除
  Future<void> removeFromPlaylist(String audioId) async {
    final index = _playlist.indexWhere((item) => item.id == audioId);
    if (index != -1) {
      _playlist.removeAt(index);
      if (index == _currentIndex) {
        _currentIndex = -1;
      } else if (index < _currentIndex) {
        _currentIndex--;
      }
      await _savePlaylist();
      notifyListeners();
    }
  }
}
