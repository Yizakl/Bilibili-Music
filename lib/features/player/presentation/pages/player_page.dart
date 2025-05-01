import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import '../../models/audio_item.dart';
import '../../../../core/services/bilibili_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import '../../../../core/services/audio_player_manager.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/wave_visualizer.dart';
import '../widgets/real_audio_visualizer.dart';

class PlayerPage extends StatefulWidget {
  final AudioItem audioItem;

  const PlayerPage({super.key, required this.audioItem});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _errorMessage;
  bool _isLoading = true;
  late AudioItem _currentAudioItem;
  bool _isShuffle = false;
  bool _isRepeat = false;
  bool _showLyrics = false;
  late AnimationController _playPauseController;
  late AudioPlayerManager _audioPlayerManager;
  int _visualizerType = 0; // 0: 波形, 1: 柱状图, 2: 实时频谱

  final List<String> _mockLyrics = [
    "[00:01.00]这是歌词示例",
    "[00:05.00]实际歌词将从服务器获取",
    "[00:10.00]或者通过解析字幕文件生成",
    "[00:15.00]目前显示的是模拟数据",
    "[00:20.00]用于展示歌词滚动效果",
    "[00:25.00]实际开发中可对接相应API",
    "[00:30.00]感谢您的使用与支持",
  ];

  // 音量控制
  double _volume = 1.0;
  bool _showVolumeSlider = false;

  @override
  void initState() {
    super.initState();
    // 初始化播放/暂停按钮动画控制器
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 初始化当前音频项
    _currentAudioItem = widget.audioItem;

    // 更新全局播放管理器
    _audioPlayerManager =
        Provider.of<AudioPlayerManager>(context, listen: false);
    _audioPlayerManager.currentAudioNotifier.value = _currentAudioItem;

    _initAudioPlayer();

    // 播放当前音频
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudio();
    });

    // 设置监听器
    _setupListeners();
  }

  void _setupListeners() {
    // 监听播放状态变化
    _audioPlayerManager.player.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          // 强制刷新可视化效果
          _refreshVisualizer();
        });
      }
    });

    // 监听播放位置变化
    _audioPlayerManager.player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // 监听音频总时长变化
    _audioPlayerManager.player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  Future<void> _initAudioPlayer() async {
    // 监听播放状态
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;

          // 处理播放错误
          if (state.processingState == ProcessingState.completed) {
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.pause();
            _playPauseController.reverse();
          }
        });

        // 控制动画
        if (state.playing) {
          _playPauseController.forward();
        } else {
          _playPauseController.reverse();
        }
      }
    });

    // 监听播放进度
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // 监听音频总时长
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // 监听错误
    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('播放器错误: $e');
        debugPrint('错误堆栈: $st');
        if (mounted) {
          setState(() {
            _errorMessage = '播放错误: $e';
            _isLoading = false;
          });
        }
      },
    );

    // 设置音频源
    await _loadAndPlayAudio();
  }

  Future<void> _loadAndPlayAudio() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 使用 mir6 API 丰富音频信息
      if (_currentAudioItem.audioUrl.isEmpty ||
          _currentAudioItem.thumbnail.isEmpty) {
        try {
          final bilibiliService =
              Provider.of<BilibiliService>(context, listen: false);

          // 先获取视频详情以获取完整信息
          final videoDetail =
              await bilibiliService.getVideoDetail(_currentAudioItem.id);
          if (videoDetail != null) {
            // 使用视频详情更新封面和标题
            setState(() {
              _currentAudioItem = _currentAudioItem.copyWith(
                thumbnail: videoDetail.thumbnail,
                title: videoDetail.title,
                uploader: videoDetail.uploader,
              );
            });
            debugPrint('成功获取视频详情: ${videoDetail.title}');
          }

          // 尝试先丰富音频信息
          final enrichedAudio =
              await bilibiliService.enrichVideoWithMir6Api(_currentAudioItem);
          if (enrichedAudio != null && enrichedAudio.audioUrl.isNotEmpty) {
            if (mounted) {
              setState(() {
                _currentAudioItem = enrichedAudio;
              });
              debugPrint(
                  '成功丰富音频信息并获取URL: ${enrichedAudio.audioUrl.length > 50 ? enrichedAudio.audioUrl.substring(0, 50) + "..." : enrichedAudio.audioUrl}');
            }
          } else {
            // 如果丰富信息失败，直接获取音频URL
            debugPrint('丰富音频信息失败，尝试直接获取URL');
            final audioUrl =
                await bilibiliService.getAudioUrl(_currentAudioItem.id);
            if (mounted && audioUrl.isNotEmpty) {
              setState(() {
                _currentAudioItem =
                    _currentAudioItem.copyWith(audioUrl: audioUrl);
              });
              debugPrint(
                  '成功获取音频URL: ${audioUrl.length > 50 ? audioUrl.substring(0, 50) + "..." : audioUrl}');
            }
          }
        } catch (e) {
          debugPrint('获取音频信息失败: $e');
          if (mounted) {
            setState(() {
              _errorMessage = '获取音频地址失败，请重试';
              _isLoading = false;
            });
            return;
          }
        }
      }

      debugPrint('尝试播放音频: ${_currentAudioItem.audioUrl}');
      debugPrint('封面: ${_currentAudioItem.thumbnail}');
      debugPrint('标题: ${_currentAudioItem.title}');

      if (_currentAudioItem.audioUrl.isEmpty) {
        throw Exception('音频URL为空');
      }

      // 设置用户代理和引用页
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://www.bilibili.com/video/${_currentAudioItem.id}',
        'Origin': 'https://www.bilibili.com',
        'Accept': '*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Range': 'bytes=0-', // 支持断点续传
      };

      // 尝试播放音频
      try {
        // 创建MediaItem用于后台播放
        final mediaItem = MediaItem(
          id: _currentAudioItem.id,
          title: _currentAudioItem.title,
          artist: _currentAudioItem.uploader,
          artUri: Uri.parse(_currentAudioItem.thumbnail),
          extras: {'url': _currentAudioItem.audioUrl},
        );

        // 检查URL是否是mir6 API的MP4流
        if (_currentAudioItem.audioUrl.contains('api.mir6.com')) {
          // 对于mir6 API的MP4流，不需要设置headers
          await _audioPlayer.setAudioSource(
            AudioSource.uri(
              Uri.parse(_currentAudioItem.audioUrl),
              tag: mediaItem,
            ),
          );
        } else {
          // 对于其他来源，设置headers
          await _audioPlayer.setAudioSource(
            AudioSource.uri(
              Uri.parse(_currentAudioItem.audioUrl),
              tag: mediaItem,
              headers: headers,
            ),
          );
        }

        // 设置音量
        await _audioPlayer.setVolume(_volume);

        // 播放音频
        await _audioPlayer.play();

        debugPrint('音频开始播放');

        setState(() {
          _isLoading = false;
        });

        // 更新全局播放管理器
        _audioPlayerManager.currentAudioNotifier.value = _currentAudioItem;
      } catch (e) {
        debugPrint('播放失败: $e');
        setState(() {
          _errorMessage = '无法播放音频，请检查网络连接';
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '重试',
              onPressed: _loadAndPlayAudio,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('音频播放错误: $e');

      if (mounted) {
        setState(() {
          _errorMessage = '加载音频失败，请重试';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '重试',
              onPressed: _loadAndPlayAudio,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _playPauseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  String _formatPlayCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万播放';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}千播放';
    } else {
      return '$count 播放';
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _toggleRepeat() {
    setState(() {
      _isRepeat = !_isRepeat;
    });

    if (_isRepeat) {
      _audioPlayer.setLoopMode(LoopMode.one);
    } else {
      _audioPlayer.setLoopMode(LoopMode.off);
    }
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffle = !_isShuffle;
    });
    // 实际应用中，这里应当处理播放列表随机逻辑
  }

  void _toggleLyrics() {
    setState(() {
      _showLyrics = !_showLyrics;
    });
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value;
    });
    _audioPlayer.setVolume(value);
  }

  Future<void> _playAudio() async {
    await _audioPlayerManager.playAudio(widget.audioItem);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.black.withOpacity(0.9),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部控制栏
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      color: Colors.white,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Text(
                      '正在播放',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        // 添加可视化效果切换按钮
                        IconButton(
                          icon: Icon(
                            _visualizerType == 0
                                ? Icons.waves
                                : (_visualizerType == 1
                                    ? Icons.bar_chart
                                    : Icons.equalizer),
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _visualizerType = (_visualizerType + 1) % 3;
                            });
                          },
                          tooltip: '切换可视化效果',
                        ),
                        IconButton(
                          icon: Icon(
                            _showLyrics ? Icons.lyrics_outlined : Icons.lyrics,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _showLyrics = !_showLyrics;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 主体内容
              Expanded(
                child: _isLoading
                    ? _buildLoadingView()
                    : _errorMessage != null
                        ? _buildErrorView()
                        : _buildPlayerContent(),
              ),

              // 底部控制栏
              _buildControlBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            '加载中...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 70,
              color: Colors.red.withOpacity(0.8),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? '未知错误',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueGrey.shade900,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: _loadAndPlayAudio,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    return _showLyrics ? _buildLyricsView() : _buildAlbumView();
  }

  Widget _buildAlbumView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 封面图片
            Hero(
              tag: 'cover-${_currentAudioItem.id}',
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: _currentAudioItem.thumbnail,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white54),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade800,
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white54,
                        size: 70,
                      ),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 视频标题
            Text(
              _currentAudioItem.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // UP主
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person,
                  color: Colors.white60,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  _currentAudioItem.uploader,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
                if (_currentAudioItem.playCount != null) ...[
                  const SizedBox(width: 15),
                  const Icon(
                    Icons.remove_red_eye,
                    color: Colors.white60,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatPlayCount(_currentAudioItem.playCount!),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 50),

            // 可视化效果
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _visualizerType == 0
                  ? WaveVisualizer(
                      isPlaying: _isPlaying,
                      color: Theme.of(context).colorScheme.primary,
                      height: 100,
                    )
                  : _visualizerType == 1
                      ? AudioVisualizer(
                          audioPlayer: _audioPlayerManager.player,
                          color: Theme.of(context).colorScheme.primary,
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                        )
                      : RealAudioVisualizer(
                          audioPlayer: _audioPlayerManager.player,
                          color: Theme.of(context).colorScheme.primary,
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                        ),
            ),

            // 额外控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: Icons.repeat,
                  active: _isRepeat,
                  onPressed: _toggleRepeat,
                  tooltip: '单曲循环',
                ),
                _buildControlButton(
                  icon: Icons.favorite_border,
                  tooltip: '收藏',
                  onPressed: () {
                    // 实现收藏功能
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('收藏功能开发中')),
                    );
                  },
                ),
                _buildControlButton(
                  icon: Icons.shuffle,
                  active: _isShuffle,
                  onPressed: _toggleShuffle,
                  tooltip: '随机播放',
                ),
                _buildControlButton(
                  icon: Icons.playlist_add,
                  tooltip: '添加到播放列表',
                  onPressed: () {
                    // 实现添加到播放列表功能
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('播放列表功能开发中')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsView() {
    // 模拟歌词滚动视图，实际应用中应当解析LRC文件或从API获取歌词
    final int currentLyricIndex =
        (_position.inSeconds ~/ 5) % _mockLyrics.length;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      itemCount: _mockLyrics.length,
      itemBuilder: (context, index) {
        final bool isCurrentLyric = index == currentLyricIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              _mockLyrics[index].substring(_mockLyrics[index].indexOf(']') + 1),
              style: TextStyle(
                color: isCurrentLyric
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                fontSize: isCurrentLyric ? 18 : 16,
                fontWeight:
                    isCurrentLyric ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 4,
            ),
            child: Slider(
              min: 0,
              max: _duration.inSeconds.toDouble(),
              value: _position.inSeconds
                  .toDouble()
                  .clamp(0, _duration.inSeconds.toDouble()),
              onChanged: (value) {
                _audioPlayer.seek(Duration(seconds: value.toInt()));
              },
            ),
          ),

          // 时间显示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 音量控制
          if (_showVolumeSlider) ...[
            Row(
              children: [
                const Icon(Icons.volume_down, color: Colors.white70, size: 20),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white70,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.white,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 2,
                    ),
                    child: Slider(
                      min: 0,
                      max: 1.0,
                      value: _volume,
                      onChanged: _setVolume,
                    ),
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.white70, size: 20),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // 播放控制
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 上一曲
              IconButton(
                icon: const Icon(
                  Icons.skip_previous,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  // 实现播放上一曲功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('播放列表功能开发中')),
                  );
                },
              ),

              // 播放/暂停
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedIcon(
                      icon: AnimatedIcons.play_pause,
                      progress: _playPauseController,
                      color: Colors.blueGrey.shade900,
                      size: 36,
                    ),
                  ),
                ),
              ),

              // 下一曲
              IconButton(
                icon: const Icon(
                  Icons.skip_next,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  // 实现播放下一曲功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('播放列表功能开发中')),
                  );
                },
              ),

              // 音量控制
              IconButton(
                icon: Icon(
                  _showVolumeSlider
                      ? Icons.volume_up
                      : Icons.volume_up_outlined,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () {
                  setState(() {
                    _showVolumeSlider = !_showVolumeSlider;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          color: active ? Colors.pinkAccent : Colors.white70,
          size: 24,
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.blueGrey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white70),
              title: const Text('分享', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // 实现分享功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.white70),
              title: const Text('下载', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // 实现下载功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white70),
              title: const Text('详情', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // 显示详情
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined,
                  color: Colors.white70),
              title: const Text('报告问题', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // 报告问题
              },
            ),
          ],
        ),
      ),
    );
  }

  // 添加刷新可视化效果的方法
  void _refreshVisualizer() {
    // 临时切换可视化效果类型来触发重建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _visualizerType = (_visualizerType + 1) % 3;
        });

        // 再切换回来
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() {
              _visualizerType = (_visualizerType + 2) % 3;
            });
          }
        });
      }
    });
  }
}
