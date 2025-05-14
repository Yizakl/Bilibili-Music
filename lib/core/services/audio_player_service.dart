import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentTitle;
  String? _currentUrl;
  bool _isInitialized = false;

  AudioPlayer get audioPlayer => _audioPlayer;
  bool get isPlaying => _isPlaying;
  String? get currentTitle => _currentTitle;
  String? get currentUrl => _currentUrl;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _configureAudioSession();
      _isInitialized = true;
    } catch (e) {
      debugPrint('初始化音频播放器失败: $e');
    }
  }

  Future<void> _configureAudioSession() async {
    if (Platform.isWindows) {
      debugPrint('在Windows平台配置音频播放器');
      // Windows平台特定配置
      // 注意：setAudioLoadConfiguration不是标准API
      // 我们暂时移除这部分代码，使用标准配置
    }
  }

  Future<void> play(String url, {String? title, String? artist}) async {
    try {
      if (_currentUrl != url) {
        await _audioPlayer.stop();
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(url),
            tag: MediaItem(
              id: url,
              title: title ?? 'Unknown',
              artist: artist ?? 'Unknown',
            ),
          ),
        );
        _currentUrl = url;
        _currentTitle = title;
      }
      await _audioPlayer.play();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _currentUrl = null;
    _currentTitle = null;
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (_currentUrl == null) return;

    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> playUrl(String url, {Map<String, String>? headers}) async {
    try {
      await initialize();

      if (url.contains('m4s')) {
        debugPrint(
            '处理m4s格式URL: ${url.substring(0, url.length > 50 ? 50 : url.length)}...');

        headers ??= {};
        headers.addAll({
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://www.bilibili.com/',
          'Accept-Encoding': 'identity;q=1, *;q=0',
          'Range': 'bytes=0-',
        });

        final audioSource = ProgressiveAudioSource(
          Uri.parse(url),
          headers: headers,
        );

        await _audioPlayer.setAudioSource(audioSource);
      } else {
        headers ??= {};
        await _audioPlayer.setUrl(url, headers: headers);
      }

      await _audioPlayer.play();
    } catch (e) {
      debugPrint('播放音频URL失败: $e');
      rethrow;
    }
  }

  Future<String?> cacheAudioFile(String url, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final localPath = '${tempDir.path}/audio_cache/$fileName.mp3';

      final cacheDir = Directory('${tempDir.path}/audio_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final file = File(localPath);
      if (await file.exists()) {
        debugPrint('使用缓存音频文件: $localPath');
        return localPath;
      }

      return null;
    } catch (e) {
      debugPrint('缓存音频文件失败: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
