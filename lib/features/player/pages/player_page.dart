import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/bilibili_service.dart';
import '../../../core/services/audio_player_service.dart';
import '../../player/models/audio_item.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class PlayerPage extends StatefulWidget {
  final String bvid;
  final String? cid;
  final String? title;
  final String? uploader;

  const PlayerPage({
    Key? key,
    required this.bvid,
    this.cid,
    this.title,
    this.uploader,
  }) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final BilibiliService _bilibiliService;
  late final AudioPlayerService _audioPlayerService;
  bool _isLoading = false;
  String _statusMessage = '';
  String? _errorMessage;
  bool _isPlaying = false;
  double _progress = 0.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _audioUrl;

  @override
  void initState() {
    super.initState();
    _audioPlayerService = AudioPlayerService();

    _initServices();
  }

  Future<void> _initServices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '初始化服务...';
    });

    try {
      // Initialize audio player service
      await _audioPlayerService.initialize();

      // Get SharedPreferences and initialize BilibiliService
      final prefs = await SharedPreferences.getInstance();
      _bilibiliService = BilibiliService(prefs);

      _audioPlayerService.audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
            if (_duration.inMilliseconds > 0) {
              _progress = position.inMilliseconds / _duration.inMilliseconds;
            }
          });
        }
      });

      _audioPlayerService.audioPlayer.durationStream.listen((duration) {
        if (duration != null && mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _audioPlayerService.audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });

      // Start playback
      _playAudio();
    } catch (e) {
      debugPrint('初始化服务失败: $e');
      setState(() {
        _errorMessage = '初始化失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _playAudio() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '准备播放音频...';
      _errorMessage = null;
    });

    try {
      final bvid = widget.bvid;

      // If we have a CID, use it directly
      if (widget.cid != null) {
        setState(() {
          _statusMessage = '获取音频URL...';
        });

        _audioUrl = await _bilibiliService.getAudioUrlWithFallback(
            bvid, int.parse(widget.cid!));
      } else {
        setState(() {
          _statusMessage = '获取视频信息...';
        });

        final videoInfo = await _bilibiliService.getVideoInfo(bvid);
        if (videoInfo != null && videoInfo.cid != null) {
          setState(() {
            _statusMessage = '获取音频URL...';
          });

          _audioUrl = await _bilibiliService.getAudioUrlWithFallback(
              bvid, int.parse(videoInfo.cid!));
        }
      }

      if (_audioUrl == null || _audioUrl!.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '无法获取音频URL';
        });
        return;
      }

      setState(() {
        _statusMessage = '开始播放...';
      });

      // Set up headers for Bilibili
      final headers = {
        'Referer': 'https://www.bilibili.com/video/$bvid',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept-Encoding': 'identity;q=1, *;q=0',
        'Range': 'bytes=0-',
      };

      // Play audio with appropriate method
      await _audioPlayerService.playUrl(_audioUrl!, headers: headers);

      setState(() {
        _isLoading = false;
        _isPlaying = true;
        _statusMessage = '播放中';
      });
    } catch (e) {
      debugPrint('播放失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '播放失败: $e';
      });
      EasyLoading.showError('播放失败');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '播放器'),
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            color: Colors.black12,
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _errorMessage ?? _statusMessage,
              style: TextStyle(
                color: _errorMessage != null ? Colors.red : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Main content
          Expanded(
            child: _isLoading
                ? _buildLoadingView()
                : _errorMessage != null
                    ? _buildErrorView()
                    : _buildPlayerView(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_statusMessage),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _playAudio,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Now playing indicator
        Icon(
          _isPlaying ? Icons.music_note : Icons.play_arrow,
          size: 64,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 16),

        // Title and uploader
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              Text(
                widget.title ?? '未知标题',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(widget.uploader ?? '未知UP主'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_position)),
                  Text(_formatDuration(_duration)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Play/Pause button
        ElevatedButton.icon(
          onPressed: () {
            if (_isPlaying) {
              _audioPlayerService.pause();
            } else {
              _audioPlayerService.resume();
            }
          },
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          label: Text(_isPlaying ? '暂停' : '播放'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),

        // Audio URL debugging info (only in debug mode)
        if (_audioUrl != null && false) // Set to true to enable debugging
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Debug Info:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Audio URL: ${_audioUrl!.substring(0, _audioUrl!.length > 100 ? 100 : _audioUrl!.length)}...',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    // We don't dispose the audio player service here since it's a singleton
    // and might be used by other parts of the app
    super.dispose();
  }
}
