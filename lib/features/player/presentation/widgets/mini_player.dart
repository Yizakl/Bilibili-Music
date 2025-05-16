import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/audio_player_manager.dart';
import '../../../../core/models/audio_item.dart';
import '../pages/audio_player_page.dart';
import 'playlist_dialog.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerManager>();

    // 如果没有当前音频，不显示迷你播放器
    if (player.currentItemNotifier.value == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        final currentAudio = player.currentItemNotifier.value;
        if (currentAudio != null) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AudioPlayerPage(
                  bvid: currentAudio.id, audioItem: currentAudio)));
        }
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
            // 音频缩略图
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  player.currentItemNotifier.value?.thumbnail ?? '',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[300],
                      child: const Icon(Icons.music_note),
                    );
                  },
                ),
              ),
            ),

            // 音频标题和艺术家
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.currentItemNotifier.value?.title ?? '未播放',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    player.currentItemNotifier.value?.uploader ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 播放控制按钮
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
                ValueListenableBuilder<bool>(
                  valueListenable: player.isPlayingNotifier,
                  builder: (context, isPlaying, child) {
                    return IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: () {
                        if (isPlaying) {
                          player.pause();
                        } else {
                          final currentAudio = player.currentItemNotifier.value;
                          if (currentAudio != null) {
                            player.resume();
                          }
                        }
                      },
                    );
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
