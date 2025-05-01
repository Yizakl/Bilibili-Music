import 'dart:math';
import 'package:flutter/material.dart';

class WaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;

  const WaveVisualizer({
    Key? key,
    required this.isPlaying,
    required this.color,
    this.height = 100,
  }) : super(key: key);

  @override
  State<WaveVisualizer> createState() => _WaveVisualizerState();
}

class _WaveVisualizerState extends State<WaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 根据播放状态决定是否运行动画
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(WaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 根据播放状态更新动画
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: WavePainter(
              animation: _controller,
              isPlaying: widget.isPlaying,
              color: widget.color,
              random: _random,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final Animation<double> animation;
  final bool isPlaying;
  final Color color;
  final Random random;

  WavePainter({
    required this.animation,
    required this.isPlaying,
    required this.color,
    required this.random,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = isPlaying ? color : color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;

    if (isPlaying) {
      // 播放状态下绘制动态波形
      final path = Path();

      // 波浪的基础参数
      final double frequency = 0.8; // 波浪频率
      final double baseAmplitude = height * 0.2; // 基础振幅

      // 添加随机变化，使波形看起来更自然
      final double randomFactor = random.nextDouble() * 0.2 + 0.9;
      final double animationValue = animation.value;

      // 移动到起始点
      path.moveTo(0, centerY);

      // 绘制波形
      for (int i = 0; i < width; i++) {
        // 创建多个正弦波叠加，使波形更自然
        final double x = i.toDouble();

        // 主波
        final double y1 =
            sin((x / width * 4 * pi) + (animationValue * 2 * pi)) *
                baseAmplitude *
                randomFactor;

        // 次波 (频率较高，振幅较小)
        final double y2 =
            sin((x / width * 8 * pi) + (animationValue * 4 * pi)) *
                baseAmplitude *
                0.3;

        // 叠加波形
        final double y = centerY + y1 + y2;

        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    } else {
      // 非播放状态下绘制一条直线
      canvas.drawLine(
        Offset(0, centerY),
        Offset(width, centerY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.color != color;
  }
}
