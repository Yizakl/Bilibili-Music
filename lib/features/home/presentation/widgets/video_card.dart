import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/video_item.dart';
import '../../../../core/services/audio_player_manager.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;

  const VideoCard({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (video.audioUrl != null) {
            final player = context.read<AudioPlayerManager>();
            player.playVideo(video, video.audioUrl!);
            context.push('/player');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法播放：音频地址无效')),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缩略图
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                video.fixedThumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.music_note,
                      size: 48,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),

            // 视频信息
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // UP主和播放量
                  Row(
                    children: [
                      Text(
                        video.uploader,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        video.formattedPlayCount,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
}
