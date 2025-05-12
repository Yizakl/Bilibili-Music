import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/audio_player_manager.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerManager>(
      builder: (context, player, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Slider(
              value: player.progress,
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds:
                      (value * player.duration.inMilliseconds).round(),
                );
                player.seekTo(newPosition);
              },
            ),

            // 时间显示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(player.position),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    _formatDuration(player.duration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // 控制按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 循环按钮
                  IconButton(
                    icon: Icon(
                      player.isLoopMode ? Icons.repeat_one : Icons.repeat,
                      color: player.isLoopMode
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    onPressed: player.toggleLoopMode,
                  ),

                  // 上一首按钮
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () {
                      // TODO: 实现上一首功能
                    },
                  ),

                  // 播放/暂停按钮
                  IconButton(
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 48,
                    ),
                    onPressed: () {
                      if (player.isPlaying) {
                        player.pause();
                      } else {
                        player.resume();
                      }
                    },
                  ),

                  // 下一首按钮
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {
                      // TODO: 实现下一首功能
                    },
                  ),

                  // 播放速度按钮
                  IconButton(
                    icon: Text(
                      '${player.speed}x',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      _showSpeedDialog(context, player);
                    },
                  ),
                ],
              ),
            ),

            // 音量控制
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.volume_down),
                  Expanded(
                    child: Slider(
                      value: player.volume,
                      onChanged: (value) {
                        player.setVolume(value);
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  void _showSpeedDialog(BuildContext context, AudioPlayerManager player) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('播放速度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return ListTile(
              title: Text('${speed}x'),
              selected: player.speed == speed,
              onTap: () {
                player.setSpeed(speed);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
