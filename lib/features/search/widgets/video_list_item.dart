import 'package:flutter/material.dart';
import '../../../core/models/video_item.dart';
import '../../../features/player/presentation/pages/player_page.dart';
import '../../../features/player/models/audio_item.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
          () {
            // 将VideoItem转换为AudioItem
            final audioItem = AudioItem(
              id: video.id,
              title: video.title,
              uploader: video.uploader,
              thumbnail: video.fixedThumbnail,
              audioUrl: '', // 这个会在PlayerPage中设置
              addedTime: DateTime.now(),
              playCount: video.playCount,
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerPage(audioItem: audioItem),
              ),
            );
          },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: CachedNetworkImage(
                imageUrl: video.fixedThumbnail,
                width: 120,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 120,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
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
                        video.duration,
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
}
