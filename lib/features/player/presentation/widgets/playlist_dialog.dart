import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/audio_player_manager.dart';
import '../../models/audio_item.dart';

class PlaylistDialog extends StatelessWidget {
  const PlaylistDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerManager>();
    final playlist = player.playlist;
    final currentIndex = player.currentIndex;

    return Dialog(
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '播放列表',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const Divider(),

            // 播放列表
            Expanded(
              child: ListView.builder(
                itemCount: playlist.length,
                itemBuilder: (context, index) {
                  final audio = playlist[index];
                  final isPlaying = index == currentIndex;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(
                          image: NetworkImage(audio.fixedThumbnail),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    title: Text(
                      audio.title,
                      style: TextStyle(
                        color:
                            isPlaying ? Theme.of(context).primaryColor : null,
                        fontWeight: isPlaying ? FontWeight.bold : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      audio.uploader,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPlaying)
                          const Icon(
                            Icons.music_note,
                            color: Colors.blue,
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            player.removeFromPlaylist(audio.id);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      player.playAudio(audio);
                    },
                  );
                },
              ),
            ),

            // 底部按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: Text(
                    '随机播放',
                    style: TextStyle(
                      color: player.isShuffleMode
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                  onPressed: () => player.toggleShuffleMode(),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.repeat),
                  label: Text(
                    '循环播放',
                    style: TextStyle(
                      color: player.isLoopMode
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                  onPressed: () => player.toggleLoopMode(),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('清空列表'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('清空播放列表'),
                        content: const Text('确定要清空播放列表吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              player.clearPlaylist();
                              Navigator.of(context).pop();
                            },
                            child: const Text('确定'),
                          ),
                        ],
                      ),
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
}
