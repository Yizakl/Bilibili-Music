import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
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
      // Configure audio session
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Set up event listeners
      _audioPlayer.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        notifyListeners();
      });

      _isInitialized = true;
      debugPrint('AudioPlayerService: initialized successfully');
    } catch (e) {
      debugPrint('AudioPlayerService: failed to initialize: $e');
    }
  }

  Future<void> play(String url, {String? title, String? artist}) async {
    try {
      await initialize();

      debugPrint('AudioPlayerService: playing $url');

      // If we're playing the same URL and it's already playing, return
      if (_currentUrl == url && _isPlaying) {
        debugPrint('AudioPlayerService: already playing this URL');
        return;
      }

      // If it's a new URL, stop any current playback
      if (_currentUrl != url) {
        await _audioPlayer.stop();
        _currentUrl = url;
        _currentTitle = title;
      }

      // Use simple setUrl for best compatibility
      await _audioPlayer.setUrl(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://www.bilibili.com/',
          'Accept-Encoding': 'identity;q=1, *;q=0',
          'Range': 'bytes=0-',
        },
      );

      // Soft start approach to prevent audio pops
      await _audioPlayer.setVolume(0.0);
      await _audioPlayer.play();

      // Gradually raise volume after playback starts
      await Future.delayed(const Duration(milliseconds: 300));
      await _audioPlayer.setVolume(1.0);

      _isPlaying = true;
      notifyListeners();

      debugPrint('AudioPlayerService: playback started successfully');
    } catch (e) {
      debugPrint('AudioPlayerService: error playing audio: $e');
      _isPlaying = false;
      notifyListeners();
      rethrow; // Allow caller to handle the error
    }
  }

  Future<void> playUrl(String url, {Map<String, String>? headers}) async {
    try {
      await initialize();

      debugPrint('AudioPlayerService: playing URL with custom headers');

      // Ensure we have basic headers for streaming
      headers = headers ?? {};
      if (!headers.containsKey('Range')) {
        headers['Range'] = 'bytes=0-';
      }
      if (!headers.containsKey('Accept-Encoding')) {
        headers['Accept-Encoding'] = 'identity;q=1, *;q=0';
      }

      // For m4s files, ensure we have the correct headers
      if (url.contains('.m4s')) {
        debugPrint('AudioPlayerService: handling m4s format');
        headers['Accept'] = '*/*';

        // Try to play using ProgressiveAudioSource for better streaming support
        try {
          final audioSource = ProgressiveAudioSource(
            Uri.parse(url),
            headers: headers,
          );

          await _audioPlayer.setAudioSource(audioSource);
        } catch (e) {
          debugPrint(
              'AudioPlayerService: failed to use ProgressiveAudioSource, falling back to setUrl: $e');
          await _audioPlayer.setUrl(url, headers: headers);
        }
      } else {
        // Use standard approach for other formats
        await _audioPlayer.setUrl(url, headers: headers);
      }

      // Soft start to prevent audio pops
      await _audioPlayer.setVolume(0.0);
      await _audioPlayer.play();

      // Gradually raise volume
      await Future.delayed(const Duration(milliseconds: 300));
      await _audioPlayer.setVolume(1.0);

      _isPlaying = true;
      _currentUrl = url;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioPlayerService: failed to play URL: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioPlayerService: failed to pause: $e');
    }
  }

  Future<void> resume() async {
    if (_currentUrl == null) return;

    try {
      await _audioPlayer.play();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioPlayerService: failed to resume: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioPlayerService: failed to stop: $e');
    }
  }

  Future<void> togglePlay() async {
    if (_currentUrl == null) return;

    if (_isPlaying) {
      await pause();
    } else {
      await resume();
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
