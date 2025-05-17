import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../core/models/video_item.dart';
import '../../models/audio_item.dart';
import '../../../../core/services/audio_player_manager.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class AudioPlayerPage extends StatefulWidget {
  final String bvid;
  final AudioItem? audioItem;

  const AudioPlayerPage({
    Key? key,
    required this.bvid,
    this.audioItem,
  }) : super(key: key);

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  bool _loading = true;
  String _statusMessage = "正在加载...";
  VideoItem? _videoItem;
  AudioItem? _audioItem;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();

    // 如果传入了 audioItem，直接使用
    if (widget.audioItem != null) {
      _audioItem = widget.audioItem;
      _isDataLoaded = true;
    }

    _loadData();

    // 延迟执行，确保页面完全加载后处理
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<AudioPlayerManager>();

      // 如果当前没有播放，或者播放的不是当前音频，则播放
      if (!player.isCurrentlyPlaying ||
          player.currentItemNotifier.value?.id != _audioItem?.id) {
        if (_audioItem != null) {
          player.playAudio(_audioItem!);
        }
      }
    });
  }

  // 主加载方法
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _statusMessage = "正在加载视频信息...";
    });

    try {
      await _fetchVideoInfo();
      if (_videoItem != null) {
        await _fetchAudioUrl();
        if (_audioItem != null) {
          await _playAudio();
        }
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _statusMessage = "加载失败: $e";
      });
      debugPrint("加载失败: $e");
    }
  }

  // 步骤1: 获取视频信息
  Future<void> _fetchVideoInfo() async {
    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);

      final videoItem = await bilibiliService.getVideoDetail(widget.bvid);

      if (videoItem == null) {
        setState(() {
          _statusMessage = "无法获取视频信息";
          _loading = false;
        });
        return;
      }

      setState(() {
        _videoItem = videoItem;
        _statusMessage = "视频信息获取成功，正在获取音频URL...";
      });

      debugPrint("视频信息获取成功: ${videoItem.title}");
    } catch (e) {
      setState(() {
        _statusMessage = "获取视频信息失败: $e";
        _loading = false;
      });
      debugPrint("获取视频信息失败: $e");
      rethrow;
    }
  }

  // 步骤2: 获取音频URL
  Future<void> _fetchAudioUrl() async {
    if (_videoItem == null) return;

    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);
      final int cid =
          _videoItem!.cid != null ? int.tryParse(_videoItem!.cid!) ?? 0 : 0;

      // 使用新的API方式获取音频URL
      final audioUrl =
          await bilibiliService.getAudioUrl(widget.bvid, cid: cid.toString());

      if (audioUrl.isEmpty) {
        setState(() {
          _statusMessage = "无法获取音频URL";
          _loading = false;
        });
        return;
      }

      // 创建音频项
      final audioItem = AudioItem(
        id: _videoItem!.id,
        bvid: _videoItem!.bvid,
        title: _videoItem!.title,
        uploader: _videoItem!.uploader,
        thumbnail: _videoItem!.thumbnail ?? '',
        audioUrl: audioUrl,
        addedTime: DateTime.now(),
      );

      setState(() {
        _audioItem = audioItem;
        _statusMessage = "音频URL获取成功，准备播放...";
        _isDataLoaded = true;
      });

      debugPrint("音频URL获取成功，长度: ${audioUrl.length}");
    } catch (e) {
      setState(() {
        _statusMessage = "获取音频URL失败: $e";
        _loading = false;
      });
      debugPrint("获取音频URL失败: $e");
      rethrow;
    }
  }

  // 步骤3: 播放音频
  Future<void> _playAudio() async {
    if (_audioItem == null) return;

    try {
      final audioPlayerManager =
          Provider.of<AudioPlayerManager>(context, listen: false);

      setState(() {
        _statusMessage = "准备播放音频...";
        _loading = true;
      });

      // 添加状态监听
      audioPlayerManager.statusNotifier.addListener(_updateStatus);

      // 检查音频URL是否有效
      if (_audioItem!.audioUrl.isEmpty) {
        throw Exception("音频URL无效");
      }

      // 根据URL类型选择播放方式
      if (_audioItem!.audioUrl.contains('.m4s')) {
        debugPrint("检测到m4s格式，使用特殊处理");
        await audioPlayerManager.playAudioWithCustomHeaders(
          _audioItem!,
          headers: {
            'Referer': 'https://www.bilibili.com/video/${widget.bvid}',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Accept': '*/*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Accept-Encoding': 'identity;q=1, *;q=0',
            'Range': 'bytes=0-',
            'Origin': 'https://www.bilibili.com',
          },
        );
      } else {
        debugPrint("使用标准播放方式");
        await audioPlayerManager.playAudio(_audioItem!);
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _statusMessage = "播放中";
      });

      debugPrint("播放开始: ${_audioItem!.title}");
    } catch (e) {
      debugPrint("播放失败: $e");
      if (!mounted) return;

      setState(() {
        _statusMessage = "播放失败: $e";
        _loading = false;
      });

      EasyLoading.showError('播放失败，请重试');
    }
  }

  // 更新状态消息
  void _updateStatus() {
    if (!mounted) return;

    final audioPlayerManager =
        Provider.of<AudioPlayerManager>(context, listen: false);
    final status = audioPlayerManager.statusNotifier.value;

    setState(() {
      _statusMessage = status;
      // 如果状态包含错误信息，更新loading状态
      if (status.contains('失败') || status.contains('错误')) {
        _loading = false;
      }
    });

    // 显示错误消息
    if (status.contains('失败') || status.contains('错误')) {
      EasyLoading.showError(status);
      // 尝试重新播放
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _playAudio();
        }
      });
    }
  }

  @override
  void dispose() {
    // 移除状态监听
    try {
      final audioPlayerManager =
          Provider.of<AudioPlayerManager>(context, listen: false);
      audioPlayerManager.statusNotifier.removeListener(_updateStatus);
    } catch (e) {
      debugPrint("移除状态监听失败: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerManager>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bvid),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isDataLoaded ? _loadData : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            width: double.infinity,
            color: Colors.black12,
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains("失败")
                    ? Colors.red
                    : _statusMessage.contains("成功")
                        ? Colors.green
                        : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 主要内容
          Expanded(
            child: _loading
                ? _buildLoadingView()
                : _audioItem == null
                    ? _buildErrorView()
                    : _buildPlayerView(),
          ),
        ],
      ),
    );
  }

  // 加载中界面
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

  // 错误界面
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // 播放器界面
  Widget _buildPlayerView() {
    return Consumer<AudioPlayerManager>(
      builder: (context, audioPlayerManager, child) {
        return Column(
          children: [
            // 封面图
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _videoItem?.thumbnail ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.music_note, size: 64),
                    ),
                  ),
                ),
              ),
            ),

            // 音频信息
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _videoItem?.title ?? '',
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _videoItem?.uploader ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // 进度条
                  ValueListenableBuilder<Duration>(
                    valueListenable: audioPlayerManager.positionNotifier,
                    builder: (context, position, child) {
                      return ValueListenableBuilder<Duration>(
                        valueListenable: audioPlayerManager.durationNotifier,
                        builder: (context, duration, child) {
                          double value = 0.0;
                          if (duration.inMilliseconds > 0) {
                            value = position.inMilliseconds /
                                duration.inMilliseconds;
                          }

                          return Column(
                            children: [
                              Slider(
                                value:
                                    value.isNaN || value.isInfinite || value < 0
                                        ? 0.0
                                        : value > 1.0
                                            ? 1.0
                                            : value,
                                onChanged: (value) {
                                  if (duration.inMilliseconds > 0) {
                                    audioPlayerManager.seekTo(Duration(
                                        milliseconds:
                                            (value * duration.inMilliseconds)
                                                .round()));
                                  }
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(position)),
                                    Text(_formatDuration(duration)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // 控制按钮
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0, top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 播放/暂停按钮
                  ValueListenableBuilder<bool>(
                    valueListenable: audioPlayerManager.isPlayingNotifier,
                    builder: (context, isPlaying, child) {
                      return IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 64,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            audioPlayerManager.pause();
                          } else {
                            audioPlayerManager.resume();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 格式化时长
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
