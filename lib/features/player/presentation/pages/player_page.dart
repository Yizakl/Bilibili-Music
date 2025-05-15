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
import '../widgets/player_controls.dart';

class PlayerPage extends StatefulWidget {
  final AudioItem audioItem;

  const PlayerPage({
    Key? key,
    required this.audioItem,
  }) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 确保音频播放器已经初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudio();
    });
  }

  Future<void> _playAudio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final player = context.read<AudioPlayerManager>();
      final bilibiliService = context.read<BilibiliService>();

      // 尝试播放音频
      if (widget.audioItem.audioUrl.isNotEmpty) {
        await player.playAudio(widget.audioItem);
      } else {
        // 获取视频详情中的cid
        final videoDetail =
            await bilibiliService.getVideoDetail(widget.audioItem.id);
        if (videoDetail != null && videoDetail.cid != null) {
          final cid = int.tryParse(videoDetail.cid!) ?? 0;

          // 使用新的API获取音频URL
          final audioUrl = await bilibiliService
              .getAudioUrl(widget.audioItem.id, cid: cid.toString());

          if (audioUrl.isNotEmpty) {
            // 使用新的音频URL创建新的AudioItem
            final newAudioItem = widget.audioItem.copyWith(audioUrl: audioUrl);
            // 播放新的音频
            await player.playAudio(newAudioItem);
          } else {
            setState(() {
              _errorMessage = '无法获取音频地址';
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '播放失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerManager>();
    final currentAudio = player.currentAudio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('正在播放'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _playAudio,
                        child: const Text('重试'),
                      )
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 封面图片
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                currentAudio?.fixedThumbnail ??
                                    widget.audioItem.fixedThumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 歌曲信息
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              currentAudio?.title ?? widget.audioItem.title,
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentAudio?.uploader ??
                                  widget.audioItem.uploader,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 进度条
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
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
                              value: _isDragging
                                  ? _dragValue
                                  : player.position.inMilliseconds.toDouble(),
                              max: player.duration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                setState(() {
                                  _isDragging = true;
                                  _dragValue = value;
                                });
                              },
                              onChangeEnd: (value) {
                                setState(() {
                                  _isDragging = false;
                                });
                                player.seekTo(
                                    Duration(milliseconds: value.toInt()));
                              },
                            ),
                          ),

                          // 时间显示
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(player.position),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(player.duration),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 控制按钮
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 随机播放
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: player.isShuffleMode
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                            ),
                            onPressed: () => player.toggleShuffleMode(),
                          ),

                          // 上一首
                          IconButton(
                            icon: const Icon(Icons.skip_previous, size: 32),
                            onPressed: () => player.playPrevious(),
                          ),

                          // 播放/暂停
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).primaryColor,
                            ),
                            child: IconButton(
                              icon: Icon(
                                player.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: () {
                                if (player.isPlaying) {
                                  player.pause();
                                } else {
                                  player.resume();
                                }
                              },
                            ),
                          ),

                          // 下一首
                          IconButton(
                            icon: const Icon(Icons.skip_next, size: 32),
                            onPressed: () => player.playNext(),
                          ),

                          // 循环播放
                          IconButton(
                            icon: Icon(
                              Icons.repeat,
                              color: player.isLoopMode
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                            ),
                            onPressed: () => player.toggleLoopMode(),
                          ),
                        ],
                      ),
                    ),

                    // 音量控制
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_down, size: 20),
                          Expanded(
                            child: Slider(
                              value: player.volume,
                              onChanged: (value) => player.setVolume(value),
                            ),
                          ),
                          const Icon(Icons.volume_up, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
