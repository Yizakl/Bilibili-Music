import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/audio_player_manager.dart';
import '../pages/player_page.dart';
import 'playlist_dialog.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerManager>();
    final currentAudio = player.currentAudio;

    if (currentAudio == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlayerPage(audioItem: currentAudio),
          ),
        );
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 封面图片
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image: NetworkImage(currentAudio.fixedThumbnail),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 歌曲信息
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentAudio.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentAudio.uploader,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 播放控制
            Row(
              children: [
                // 播放列表
                IconButton(
                  icon: const Icon(Icons.playlist_play),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const PlaylistDialog(),
                    );
                  },
                ),

                // 上一首
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => player.playPrevious(),
                ),

                // 播放/暂停
                IconButton(
                  icon: Icon(
                    player.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () {
                    if (player.isPlaying) {
                      player.pause();
                    } else {
                      player.resume();
                    }
                  },
                ),

                // 下一首
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => player.playNext(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
