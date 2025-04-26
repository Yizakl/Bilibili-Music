import 'package:flutter/material.dart';
import '../../services/audio_player_service.dart';

class PlayerControls extends StatefulWidget {
  final AudioPlayerService audioPlayer;

  const PlayerControls({
    super.key,
    required this.audioPlayer,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _isPlaying = false;
  Duration? _position;
  Duration? _duration;
  
  @override
  void initState() {
    super.initState();
    _listenToPlaybackState();
  }

  void _listenToPlaybackState() {
    widget.audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    widget.audioPlayer.positionStream.listen((position) {
      if (mounted && position != null) {
        setState(() {
          _position = position;
        });
      }
    });

    widget.audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('定时关闭'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('15分钟'),
              onTap: () {
                widget.audioPlayer.setSleepTimer(const Duration(minutes: 15));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('30分钟'),
              onTap: () {
                widget.audioPlayer.setSleepTimer(const Duration(minutes: 30));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('60分钟'),
              onTap: () {
                widget.audioPlayer.setSleepTimer(const Duration(minutes: 60));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('取消定时'),
              onTap: () {
                widget.audioPlayer.setSleepTimer(null);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度条
        if (_position != null && _duration != null)
          Slider(
            value: _position!.inMilliseconds.toDouble(),
            max: _duration!.inMilliseconds.toDouble(),
            onChanged: (value) {
              widget.audioPlayer.seek(Duration(milliseconds: value.toInt()));
            },
          ),
        
        // 时间显示
        if (_position != null && _duration != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position!)),
                Text(_formatDuration(_duration!)),
              ],
            ),
          ),

        // 控制按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.timer),
              onPressed: _showSleepTimerDialog,
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () {
                // TODO: 上一曲
              },
            ),
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
              iconSize: 48,
              onPressed: () {
                if (_isPlaying) {
                  widget.audioPlayer.pause();
                } else {
                  widget.audioPlayer.play();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () {
                // TODO: 下一曲
              },
            ),
            IconButton(
              icon: const Icon(Icons.playlist_play),
              onPressed: () {
                // TODO: 显示播放列表
              },
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}