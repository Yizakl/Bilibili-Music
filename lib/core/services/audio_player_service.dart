import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentTitle;
  String? _currentUrl;

  AudioPlayer get audioPlayer => _audioPlayer;
  bool get isPlaying => _isPlaying;
  String? get currentTitle => _currentTitle;
  String? get currentUrl => _currentUrl;

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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
