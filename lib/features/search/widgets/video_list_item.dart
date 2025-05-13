import 'package:flutter/material.dart';
import '../../../core/models/video_item.dart';
import 'package:provider/provider.dart';
import '../../../core/services/bilibili_service.dart';
import '../../../core/services/audio_player_manager.dart';

class VideoListItem extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onTap;

  const VideoListItem({
    Key? key,
    required this.video,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ??
          () async {
            try {
              // 显示加载中提示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在获取音频信息...')),
              );

              // 获取必要的服务
              final bilibiliService =
                  Provider.of<BilibiliService>(context, listen: false);
              final audioManager =
                  Provider.of<AudioPlayerManager>(context, listen: false);

              // 获取音频URL
              final audioUrl =
                  await bilibiliService.getAudioUrl(video.id, cid: video.cid);

              if (audioUrl.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('获取音频失败')),
                  );
                }
                return;
              }

              // 创建音频项并播放
              final audioItem = video.toAudioItem(audioUrl: audioUrl);
              if (context.mounted) {
                audioManager.playAudio(audioItem);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('正在播放: ${video.title}')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('播放失败: $e')),
                );
              }
            }
          },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                video.fixedThumbnail,
                width: 120,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, url, error) => Container(
                  width: 120,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            // 视频信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    video.uploader,
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      Icon(
                        Icons.play_arrow,
                        size: 16.0,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        video.formattedPlayCount,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Icon(
                        Icons.access_time,
                        size: 16.0,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        _formatDuration(video.duration),
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
