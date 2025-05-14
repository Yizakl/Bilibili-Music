import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../core/models/video_item.dart';
import '../../models/audio_item.dart';
import '../../../../core/services/audio_player_manager.dart';

class AudioPlayerPage extends StatefulWidget {
  final String bvid;

  const AudioPlayerPage({
    Key? key,
    required this.bvid,
  }) : super(key: key);

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  bool _loading = true;
  String? _errorMessage;
  VideoItem? _videoItem;
  AudioItem? _audioItem;

  @override
  void initState() {
    super.initState();
    _fetchVideoInfo(widget.bvid);
  }

  Future<void> _fetchVideoInfo(String bvid) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);

      // 显示加载步骤
      setState(() {
        _errorMessage = '正在获取视频信息...';
      });

      // 获取视频详情
      final videoItem = await bilibiliService.getVideoDetail(bvid);

      if (videoItem == null) {
        setState(() {
          _loading = false;
          _errorMessage = '无法获取视频信息';
        });
        return;
      }

      // 设置视频信息
      setState(() {
        _videoItem = videoItem;
        _errorMessage = '正在获取音频URL...';
      });

      // 获取音频URL - 使用增强型获取方法，优先使用备用API
      final cid = int.tryParse(videoItem.cid ?? '') ?? 0;

      setState(() {
        _errorMessage = '正在解析第三方接口...';
      });

      final audioUrl = await bilibiliService.getAudioUrlWithFallback(bvid, cid);

      if (audioUrl == null || audioUrl.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = '无法获取音频地址';
        });
        return;
      }

      setState(() {
        _errorMessage = '音频URL获取成功，准备播放...';
      });

      // 创建音频项
      final audioItem = AudioItem(
        id: videoItem.id,
        title: videoItem.title,
        uploader: videoItem.uploader,
        thumbnail: videoItem.thumbnail ?? '',
        audioUrl: audioUrl as String,
        addedTime: DateTime.now(),
      );

      // 显示音频URL (调试用)
      debugPrint('准备播放的音频URL: ${audioItem.audioUrl}');

      setState(() {
        _errorMessage = '正在连接播放器...';
      });

      // 播放音频
      final audioPlayerManager =
          Provider.of<AudioPlayerManager>(context, listen: false);

      // 判断是否为m4s格式音频
      if (audioUrl.contains('m4s')) {
        debugPrint('检测到m4s格式音频，使用特殊处理...');
        // 使用自定义的headers
        await audioPlayerManager
            .playAudioWithCustomHeaders(audioItem, headers: {
          'Referer': 'https://www.bilibili.com/video/$bvid',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept-Encoding': 'identity;q=1, *;q=0',
          'Range': 'bytes=0-',
        });
      } else {
        // 使用常规播放方法
        await audioPlayerManager.playAudio(audioItem);
      }

      setState(() {
        _loading = false;
        _errorMessage = null;
        _audioItem = audioItem;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = '加载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_videoItem?.title ?? '加载中...'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _fetchVideoInfo(widget.bvid),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _audioItem != null
                  ? Column(
                      children: [
                        // 封面图片
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            _videoItem?.thumbnail ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image, size: 64),
                            ),
                          ),
                        ),

                        // 音频信息
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _videoItem?.title ?? '',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '上传者: ${_videoItem?.uploader ?? ''}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // 底部控制器 (可以是一个简化版的播放控制器)
                        Consumer<AudioPlayerManager>(
                          builder: (context, player, child) {
                            return Container(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(player.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow),
                                    onPressed: () {
                                      if (player.isPlaying) {
                                        player.pause();
                                      } else {
                                        player.resume();
                                      }
                                    },
                                    iconSize: 48,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    )
                  : const Center(child: Text('无法加载音频')),
    );
  }
}
