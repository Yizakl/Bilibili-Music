import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
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
  AudioItem? _currentAudio;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffleMode = false;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _processingStateSubscription;
  final Dio _dio = Dio();

  // 播放列表相关
  List<AudioItem> _playlist = [];
  int _currentIndex = -1;

  // 下载状态通知器
  final Map<String, ValueNotifier<double>> _downloadProgressNotifiers = {};
  final Map<String, ValueNotifier<String>> _downloadStatusNotifiers = {};

  // 收藏夹
  List<AudioItem> _favorites = [];

  // 当前音频播放状态的ValueNotifier
  final ValueNotifier<AudioItem?> currentAudioNotifier =
      ValueNotifier<AudioItem?>(null);

  VideoItem? _currentVideo;
  double _volume = 1.0;
  double _speed = 1.0;
  bool _isLooping = false;
  bool _isShuffling = false;

  AudioPlayerManager() {
    _initAudioPlayer();
    _loadFavorites();
  }

  void _initAudioPlayer() {
    // 确保在主线程上初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioPlayer.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        notifyListeners();
      });

      _audioPlayer.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

      _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        notifyListeners();
      }
    });

      _audioPlayer.processingStateStream.listen((state) {
      debugPrint('处理状态改变: $state');
      if (state == ProcessingState.completed) {
          if (_isLooping) {
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.play();
          }
        }
      });
    });
  }

  AudioItem? get currentAudio => _currentAudio;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  List<AudioItem> get playlist => _playlist;
  List<AudioItem> get favorites => _favorites;
  bool get isShuffleMode => _isShuffleMode;
  VideoItem? get currentVideo => _currentVideo;
  double get volume => _volume;
  double get speed => _speed;
  bool get isLooping => _isLooping;
  bool get isShuffling => _isShuffling;
  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0.0;
  AudioPlayer get player => _audioPlayer;

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

  // 设置播放列表
  void setPlaylist(List<AudioItem> playlist, {int initialIndex = 0}) {
    _playlist = List.from(playlist);
    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);
    notifyListeners();

    if (_playlist.isNotEmpty) {
      playAudio(_playlist[_currentIndex]);
    }
  }

  // 添加到播放列表
  void addToPlaylist(AudioItem audioItem) {
    if (!_playlist.any((item) => item.id == audioItem.id)) {
      _playlist.add(audioItem);
      notifyListeners();
    }
  }

  // 从播放列表中移除
  void removeFromPlaylist(String audioId) {
    _playlist.removeWhere((item) => item.id == audioId);
    notifyListeners();
  }

  // 播放下一首
  Future<void> playNextAudio() async {
    if (_playlist.isEmpty || _currentIndex < 0) return;

    int nextIndex;
    if (_isShuffleMode) {
      // 随机模式下随机选择下一首（不重复当前歌曲）
      if (_playlist.length > 1) {
        int randomIndex;
        do {
          randomIndex = math.Random().nextInt(_playlist.length);
        } while (randomIndex == _currentIndex);
        nextIndex = randomIndex;
      } else {
        nextIndex = 0;
      }
    } else {
      // 顺序模式下播放下一首
      nextIndex = (_currentIndex + 1) % _playlist.length;
    }

    _currentIndex = nextIndex;
    await playAudio(_playlist[_currentIndex]);
  }

  // 播放上一首
  Future<void> playPreviousAudio() async {
    if (_playlist.isEmpty || _currentIndex < 0) return;

    int previousIndex;
    if (_isShuffleMode) {
      // 随机模式下也随机选择
      if (_playlist.length > 1) {
        int randomIndex;
        do {
          randomIndex = math.Random().nextInt(_playlist.length);
        } while (randomIndex == _currentIndex);
        previousIndex = randomIndex;
      } else {
        previousIndex = 0;
      }
    } else {
      // 顺序模式下播放上一首
      previousIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    }

    _currentIndex = previousIndex;
    await playAudio(_playlist[_currentIndex]);
  }

  // 切换随机播放模式
  void toggleShuffleMode() {
    _isShuffleMode = !_isShuffleMode;
    notifyListeners();
  }

  // 播放新音频
  Future<void> playAudio(AudioItem audioItem) async {
    try {
      // 确保在主线程上执行
      await Future.microtask(() async {
      // 如果已经在播放这首歌，就不重新加载了
      if (_currentAudio?.id == audioItem.id) {
        if (!_isPlaying) {
            await _audioPlayer.play();
        }
        return;
      }

      _currentAudio = audioItem;
      currentAudioNotifier.value = audioItem;

      // 更新播放列表中的当前索引
      _currentIndex = _playlist.indexWhere((item) => item.id == audioItem.id);
      if (_currentIndex == -1 && _playlist.isNotEmpty) {
        // 如果当前播放的音频不在播放列表中，添加它
        _playlist.add(audioItem);
        _currentIndex = _playlist.length - 1;
      }

      // 停止当前播放
        await _audioPlayer.stop();

      // 首先检查是否有下载的本地文件
      final localFilePath = await getLocalAudioPath(audioItem.id);
      final localFile = File(localFilePath);

      if (await localFile.exists()) {
        // 使用本地文件播放
        debugPrint('使用本地文件播放: $localFilePath');
        try {
          final audioSource = AudioSource.uri(
            Uri.file(localFilePath),
            tag: MediaItem(
              id: audioItem.id,
              title: audioItem.title,
              artist: audioItem.uploader,
                artUri: _safeImageUri(audioItem.thumbnail),
            ),
          );
            await _audioPlayer.setAudioSource(audioSource);
        } catch (e) {
          debugPrint('设置本地音频源失败: $e');
          // 回退到在线播放
          await _setOnlineAudioSource(audioItem);
        }
      } else {
        // 使用在线URL播放
        await _setOnlineAudioSource(audioItem);
      }

      // 开始播放
        await _audioPlayer.play();
      _isPlaying = true;
      notifyListeners();
      debugPrint('音频播放成功');
      });
    } catch (e) {
      debugPrint('播放音频失败: $e');
      _isPlaying = false;
      notifyListeners();

      // 尝试使用备用方法
      if (e.toString().contains('PlatformException') ||
          e.toString().contains('abort') ||
          e.toString().contains('sourceNotSupported')) {
        _tryAlternativePlayback(audioItem);
      }
    }
  }

  Future<void> _setOnlineAudioSource(AudioItem audioItem) async {
    try {
      // 检查是否是解析API链接
      if (audioItem.audioUrl.contains('jx.jsonplayer.com') ||
          audioItem.audioUrl.contains('jiexi.t7g.cn')) {
        debugPrint('检测到解析API链接，使用WebView方式加载');

        // 创建一个简单的音频源
        final audioSource = AudioSource.uri(
          Uri.parse(audioItem.audioUrl),
          tag: MediaItem(
            id: audioItem.id,
            title: audioItem.title,
            artist: audioItem.uploader,
            artUri: _safeImageUri(audioItem.thumbnail),
          ),
        );

        await _audioPlayer.setAudioSource(audioSource);
        debugPrint('解析API音频源设置成功');
        return;
      }

      // B站音频链接需要特殊处理
      if (audioItem.audioUrl.contains('bilivideo.com') ||
          audioItem.audioUrl.contains('bilibili.com')) {
        debugPrint('检测到B站音频链接，添加特殊请求头');

        final audioSource = AudioSource.uri(
          Uri.parse(audioItem.audioUrl),
          tag: MediaItem(
            id: audioItem.id,
            title: audioItem.title,
            artist: audioItem.uploader,
            artUri: _safeImageUri(audioItem.thumbnail),
          ),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com/video/${audioItem.id}',
            'Origin': 'https://www.bilibili.com',
            'Accept': '*/*',
            'Accept-Encoding': 'identity',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Range': 'bytes=0-',
          },
        );

        await _audioPlayer.setAudioSource(audioSource);
        debugPrint('B站音频源设置成功');
        return;
      }

      // 标准音频URL处理
      debugPrint('使用标准方式加载音频: ${audioItem.audioUrl}');
      final audioSource = AudioSource.uri(
        Uri.parse(audioItem.audioUrl),
        tag: MediaItem(
          id: audioItem.id,
          title: audioItem.title,
          artist: audioItem.uploader,
          artUri: _safeImageUri(audioItem.thumbnail),
        ),
      );

      await _audioPlayer.setAudioSource(audioSource);
      debugPrint('标准音频源设置成功');
    } catch (e) {
      debugPrint('设置音频URL失败: $e');

      try {
        // 如果标准方式失败，尝试不同的方法
        debugPrint('尝试备用方法设置音频URL');
        await _audioPlayer
            .setUrl(audioItem.audioUrl, preload: false)
            .timeout(const Duration(seconds: 10));
        debugPrint('使用备用方法设置音频URL成功');
      } catch (e2) {
        debugPrint('所有方法设置音频URL都失败: $e2');
        throw e2;
      }
    }
  }

  // 处理图片URI，避免无效的scheme问题
  Uri _safeImageUri(String imageUrl) {
    try {
      if (imageUrl.isEmpty) {
        // 返回一个占位图URI
        return Uri.parse('https://via.placeholder.com/150');
      }

      // 处理无scheme的URL
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        return Uri.parse('https:$imageUrl');
      }

      // 处理file:///开头的URL (不支持的scheme)
      if (imageUrl.startsWith('file:///')) {
        return Uri.parse('https://via.placeholder.com/150');
      }

      return Uri.parse(imageUrl);
    } catch (e) {
      debugPrint('图片URI解析失败: $e');
      return Uri.parse('https://via.placeholder.com/150');
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

  // 设置播放质量
  void setPlaybackQuality(String quality) {
    // 在这里实现播放质量切换逻辑
    debugPrint('设置播放质量: $quality');
    // 实际应用中，可能需要重新加载当前音频的不同质量URL
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

  // 获取本地音频文件路径
  Future<String> getLocalAudioPath(String audioId) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/audios/$audioId.mp3';
  }

  // 删除已下载的音频
  Future<bool> deleteDownloadedAudio(String audioId) async {
    try {
      final path = await getLocalAudioPath(audioId);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('删除音频文件失败: $e');
      return false;
    }
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

  // 收藏功能
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

  // 释放资源
  @override
  void dispose() {
    _playbackStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _audioPlayer.dispose();
    currentAudioNotifier.dispose();

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

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // 尝试备用播放方法
  Future<void> _tryAlternativePlayback(AudioItem audioItem) async {
    try {
      debugPrint('尝试备用播放方法');

      // 如果是解析API链接，可能需要特殊处理
      if (audioItem.audioUrl.contains('jx.jsonplayer.com') ||
          audioItem.audioUrl.contains('jiexi.t7g.cn')) {
        // 这里可以添加特殊处理逻辑，比如通知用户
        debugPrint('解析API链接播放失败，可能需要使用WebView播放器');
        return;
      }

      // 尝试简单的URL播放
      await _audioPlayer.setUrl(audioItem.audioUrl);
      await _audioPlayer.play();
      _isPlaying = true;
      notifyListeners();
      debugPrint('备用播放方法成功');
    } catch (e) {
      debugPrint('备用播放方法失败: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> playVideo(VideoItem video, String audioUrl) async {
    try {
      if (_currentVideo?.id != video.id) {
        _currentVideo = video;
        await _audioPlayer.setUrl(audioUrl);
      }
      await _audioPlayer.play();
      debugPrint('音频播放成功');
    } catch (e) {
      debugPrint('播放失败: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _audioPlayer.setSpeed(_speed);
    notifyListeners();
  }

  Future<void> toggleLoop() async {
    _isLooping = !_isLooping;
    await _audioPlayer.setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _isShuffling = !_isShuffling;
    notifyListeners();
  }
}
