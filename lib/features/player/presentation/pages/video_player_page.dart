import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/video_item.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/models/advanced_settings.dart';

class VideoPlayerPage extends StatefulWidget {
  final VideoItem video;

  const VideoPlayerPage({Key? key, required this.video}) : super(key: key);

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  late String _videoUrl;
  bool _isFullScreen = false;
  bool _showControls = true;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    // 初始化一个默认的控制器，防止 LateInitializationError
    _controller = VideoPlayerController.network('');
    _initializeVideoPlayerFuture = _controller.initialize();
    _fetchVideoUrl();
  }

  Future<void> _fetchVideoUrl() async {
    try {
      // 使用 SharedPreferences 初始化 BilibiliService
      final prefs = await SharedPreferences.getInstance();
      final bilibiliService = BilibiliService(prefs: prefs);
      final videoUrl = await bilibiliService.getVideoPlayUrl(widget.video.bvid);

      // 重新初始化控制器
      await _controller.dispose(); // 先释放之前的控制器
      setState(() {
        _videoUrl = videoUrl;
        _controller = VideoPlayerController.network(_videoUrl);
        _initializeVideoPlayerFuture = _controller.initialize().then((_) {
          _controller.setLooping(true);
          _controller.play();
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('视频加载失败: $e')),
      );
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _changePlaybackSpeed() {
    final speeds = [0.5, 1.0, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    setState(() {
      _playbackSpeed = speeds[nextIndex];
      _controller.setPlaybackSpeed(_playbackSpeed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);

    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: Text(widget.video.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showPlayerSettings(settingsService),
                ),
              ],
            ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: FutureBuilder(
                future: _initializeVideoPlayerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
            ),
            if (_showControls) _buildVideoControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Container(
      color: Colors.black54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  });
                },
              ),
              IconButton(
                icon:
                    const Icon(Icons.replay_10, color: Colors.white, size: 36),
                onPressed: () {
                  final currentPosition = _controller.value.position;
                  _controller
                      .seekTo(currentPosition - const Duration(seconds: 10));
                },
              ),
              IconButton(
                icon:
                    const Icon(Icons.forward_10, color: Colors.white, size: 36),
                onPressed: () {
                  final currentPosition = _controller.value.position;
                  _controller
                      .seekTo(currentPosition + const Duration(seconds: 10));
                },
              ),
              IconButton(
                icon: Text(
                  '${_playbackSpeed}x',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                onPressed: _changePlaybackSpeed,
              ),
            ],
          ),
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
          ),
        ],
      ),
    );
  }

  void _showPlayerSettings(SettingsService settingsService) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '播放器设置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('播放器类型'),
                trailing: DropdownButton<PlayerType>(
                  value: settingsService.advancedSettings.playerType,
                  onChanged: (PlayerType? newType) {
                    if (newType != null) {
                      settingsService.setPlayerType(newType);
                    }
                  },
                  items: PlayerType.values
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                                type == PlayerType.native ? '原生播放器' : '外部播放器'),
                          ))
                      .toList(),
                ),
              ),
              SwitchListTile(
                title: const Text('交叉淡入淡出'),
                value: settingsService.advancedSettings.enableCrossfade,
                onChanged: (bool value) {
                  settingsService.setCrossfade(value);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
