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
import 'package:go_router/go_router.dart';

class PlayerPage extends StatefulWidget {
  final AudioItem? audioItem;

  const PlayerPage({super.key, this.audioItem});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  String? _errorMessage;
  bool _isLoading = true;
  late AudioItem _currentAudioItem;
  bool _isShuffle = false;
  bool _isRepeat = false;
  bool _showLyrics = false;
  late AnimationController _playPauseController;
  late AudioPlayerManager _audioPlayerManager;
  int _visualizerType = 0; // 0: 波形, 1: 柱状图, 2: 实时频谱
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isFavorite = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

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
    _currentAudioItem = widget.audioItem!;

    // 更新全局播放管理器
    _audioPlayerManager =
        Provider.of<AudioPlayerManager>(context, listen: false);
    _audioPlayerManager.currentAudioNotifier.value = _currentAudioItem;

    _initializePlayer();

    // 播放当前音频
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudio();
      _checkDownloadStatus();
      _checkFavoriteStatus();
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

    // 监听当前音频变化
    _audioPlayerManager.currentAudioNotifier.addListener(() {
      if (mounted && _audioPlayerManager.currentAudioNotifier.value != null) {
        setState(() {
          _currentAudioItem = _audioPlayerManager.currentAudioNotifier.value!;
        });
      }
    });
  }

  void _initializePlayer() {
    final audioManager =
        Provider.of<AudioPlayerManager>(context, listen: false);
    if (widget.audioItem != null &&
        widget.audioItem?.id != audioManager.currentAudio?.id) {
      audioManager.playAudio(widget.audioItem!);
    }
  }

  @override
  void dispose() {
    // 不再在这里dispose音频播放器，让它继续在后台播放
    _playPauseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
      _audioPlayerManager.pause();
    } else {
      _audioPlayerManager.playAudio(_currentAudioItem);
    }
  }

  void _toggleRepeat() {
    setState(() {
      _isRepeat = !_isRepeat;
    });

    if (_isRepeat) {
      _audioPlayerManager.player.setLoopMode(LoopMode.one);
    } else {
      _audioPlayerManager.player.setLoopMode(LoopMode.off);
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
    _audioPlayerManager.player.setVolume(value);
  }

  Future<void> _playAudio() async {
    await _audioPlayerManager.playAudio(widget.audioItem!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('正在播放'),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Consumer<AudioPlayerManager>(
        builder: (context, audioManager, _) {
          final currentAudio = audioManager.currentAudio;

          if (currentAudio == null) {
            return const Center(
              child: Text('没有正在播放的内容'),
            );
          }

          return Column(
            children: [
              // 顶部背景区域（模糊的封面）
              Container(
                height: MediaQuery.of(context).size.height * 0.4,
                width: double.infinity,
                color: Colors.grey.shade300,
                child: Stack(
                  children: [
                    // 背景模糊
                    Container(
                      color: Colors.black.withOpacity(0.5),
                    ),
                    // 居中的封面
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.music_note,
                            size: 80,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 播放信息区域
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题和UP主
                      Text(
                        currentAudio.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentAudio.uploader,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 进度条
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: audioManager.position.inSeconds.toDouble(),
                          max: audioManager.duration.inSeconds > 0
                              ? audioManager.duration.inSeconds.toDouble()
                              : 180, // 默认3分钟
                          onChanged: (value) {
                            audioManager.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),

                      // 时间显示
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(audioManager.position)),
                            Text(
                              audioManager.duration.inSeconds > 0
                                  ? _formatDuration(audioManager.duration)
                                  : '03:00',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 控制按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous, size: 32),
                            onPressed: () {
                              // 上一首
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              audioManager.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 64,
                            ),
                            onPressed: () {
                              if (audioManager.isPlaying) {
                                audioManager.player.pause();
                              } else {
                                audioManager.player.play();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, size: 32),
                            onPressed: () {
                              // 下一首
                            },
                          ),
                        ],
                      ),

                      const Spacer(),

                      // 底部操作栏
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(Icons.repeat, '循环'),
                          _buildActionButton(Icons.favorite_border, '收藏'),
                          _buildActionButton(Icons.download_outlined, '下载'),
                          _buildActionButton(Icons.share_outlined, '分享'),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label 功能开发中')),
            );
          },
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  // 检查下载状态
  Future<void> _checkDownloadStatus() async {
    final isDownloaded =
        await _audioPlayerManager.isAudioDownloaded(_currentAudioItem.id);
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
      });
    }
  }

  // 检查收藏状态
  void _checkFavoriteStatus() {
    final isFavorite = _audioPlayerManager.isFavorite(_currentAudioItem.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  // 下载当前音频
  Future<void> _downloadCurrentAudio() async {
    if (_isDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音频已下载')),
      );
      return;
    }

    if (_isDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在下载中...')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    // 获取下载状态通知器
    final progressNotifier =
        _audioPlayerManager.getDownloadProgressNotifier(_currentAudioItem.id);
    final statusNotifier =
        _audioPlayerManager.getDownloadStatusNotifier(_currentAudioItem.id);

    if (progressNotifier != null) {
      progressNotifier.addListener(() {
        if (mounted) {
          setState(() {
            _downloadProgress = progressNotifier.value;
          });
        }
      });
    }

    if (statusNotifier != null) {
      statusNotifier.addListener(() {
        if (mounted) {
          setState(() {
            _downloadStatus = statusNotifier.value;
          });
        }
      });
    }

    final success = await _audioPlayerManager.downloadAudio(_currentAudioItem);

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isDownloaded = success;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '下载完成' : '下载失败')),
      );
    }
  }

  // 切换收藏状态
  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _audioPlayerManager.removeFromFavorites(_currentAudioItem.id);
    } else {
      await _audioPlayerManager.addToFavorites(_currentAudioItem);
    }

    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFavorite ? '已加入收藏' : '已移出收藏')),
      );
    }
  }

  // 切换随机播放模式
  void _toggleShuffleMode() {
    _audioPlayerManager.toggleShuffleMode();
    setState(() {
      _isShuffle = _audioPlayerManager.isShuffleMode;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isShuffle ? '随机播放已开启' : '随机播放已关闭')),
    );
  }

  // 播放上一首
  void _playPrevious() {
    _audioPlayerManager.playPreviousAudio();
  }

  // 播放下一首
  void _playNext() {
    _audioPlayerManager.playNextAudio();
  }
}
