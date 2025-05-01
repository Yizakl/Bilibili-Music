import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/audio_player_manager.dart';
import '../../../player/models/audio_item.dart';
import 'package:go_router/go_router.dart';

class MiniPlayer extends StatelessWidget {
  final AudioItem currentAudio;
  final VoidCallback onTap;

  const MiniPlayer({
    Key? key,
    required this.currentAudio,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audioPlayerManager = Provider.of<AudioPlayerManager>(context);

    return Material(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Theme.of(context).cardColor,
          child: Row(
            children: [
              // 封面图片
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  image: DecorationImage(
                    image: NetworkImage(currentAudio.thumbnail),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 标题和上传者
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentAudio.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentAudio.uploader,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 播放/暂停按钮
              IconButton(
                icon: Icon(
                  audioPlayerManager.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  if (audioPlayerManager.isPlaying) {
                    audioPlayerManager.pause();
                  } else {
                    // 确保播放当前音频
                    audioPlayerManager.playAudio(currentAudio);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
