import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioVisualizer extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Color color;
  final Color backgroundColor;

  const AudioVisualizer({
    Key? key,
    required this.audioPlayer,
    required this.color,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<double> _barHeights;
  final Random _random = Random();
  final int _barCount = 30;
  late List<double> _audioData;

  @override
  void initState() {
    super.initState();

    // 初始化音频数据数组
    _audioData = List.filled(_barCount, 0.0);

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // 生成初始柱状高度
    _generateBarHeights();

    // 使用播放位置变化来触发可视化更新
    widget.audioPlayer.positionStream.listen((_) {
      if (mounted) {
        setState(() {
          // 更新音频数据
          _updateAudioData();
        });
      }
    });

    // 监听播放状态，仅在播放时运行动画
    widget.audioPlayer.playingStream.listen((isPlaying) {
      if (isPlaying) {
        // 播放状态：启动动画
        _animationController.repeat(reverse: true);
      } else {
        // 非播放状态：停止动画
        _animationController.stop();
      }
    });

    // 如果当前正在播放，则启动动画
    if (widget.audioPlayer.playing) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果音频播放器实例变化，可以在这里处理
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 生成随机柱状高度
  void _generateBarHeights() {
    _barHeights =
        List.generate(_barCount, (_) => _random.nextDouble() * 0.8 + 0.2);
  }

  // 更新音频数据以模拟频谱分析
  void _updateAudioData() {
    if (!widget.audioPlayer.playing) return;

    for (int i = 0; i < _barCount; i++) {
      // 生成随机值模拟音频频谱，但保持一定的连续性
      if (_random.nextDouble() > 0.7) {
        // 只更新部分数据点，使动画更平滑
        _audioData[i] = _random.nextDouble() * 0.8 + 0.2;
      }
    }
  }

  // 更新柱状高度模拟音频活动
  void _updateBarHeights() {
    for (int i = 0; i < _barHeights.length; i++) {
      if (_random.nextBool()) {
        _barHeights[i] = _random.nextDouble() * 0.8 + 0.2;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否在播放
    final isPlaying = widget.audioPlayer.playing;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // 播放状态下更新柱状高度
        if (isPlaying &&
            (_animationController.value == 0 ||
                _animationController.value == 1)) {
          _updateBarHeights();
        }

        return Container(
          height: 160,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_barCount, (index) {
              // 计算高度
              double height;
              if (isPlaying) {
                // 使用实时音频数据
                final double audioValue = _audioData[index % _audioData.length];
                final double animationFactor =
                    0.5 + 0.5 * _animationController.value;
                height = (audioValue * 0.8 + _barHeights[index] * 0.2) *
                    animationFactor;
              } else {
                // 暂停状态：固定低高度
                height = 0.05;
              }

              return Container(
                width: 6,
                height: max(120 * height, 3.0),
                decoration: BoxDecoration(
                  color: widget.color
                      .withOpacity(isPlaying ? (0.7 + 0.3 * height) : 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
