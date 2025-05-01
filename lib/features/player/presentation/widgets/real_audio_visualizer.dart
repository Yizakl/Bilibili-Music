import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:fftea/fftea.dart';
import 'package:vector_math/vector_math_64.dart';

class RealAudioVisualizer extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Color color;
  final Color backgroundColor;

  const RealAudioVisualizer({
    Key? key,
    required this.audioPlayer,
    required this.color,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  State<RealAudioVisualizer> createState() => _RealAudioVisualizerState();
}

class _RealAudioVisualizerState extends State<RealAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final int _barCount = 30; // 显示的频谱柱状数量
  late List<double> _fftData; // 存储FFT分析后的频谱数据
  final FFT _fft = FFT(512); // 创建FFT分析器，使用512点FFT

  // 用于存储原始音频数据的缓冲区
  final List<double> _audioBuffer = List.filled(512, 0.0);
  // 用于FFT计算的复数数组
  late Float64x2List _fftBuffer;

  // 用于平滑动画的因子
  final double _smoothingFactor = 0.3;
  // 频谱显示的最小高度
  final double _minHeight = 0.05;

  @override
  void initState() {
    super.initState();

    // 初始化FFT数据数组
    _fftData = List.filled(_barCount, _minHeight);

    // 初始化FFT缓冲区
    _fftBuffer = Float64x2List(512);
    for (int i = 0; i < 512; i++) {
      _fftBuffer[i] = Float64x2(0.0, 0.0);
    }

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50), // 更快的刷新率以获得更流畅的可视化效果
    );

    // 使用播放位置变化来触发可视化更新
    widget.audioPlayer.positionStream.listen((_) {
      if (mounted && widget.audioPlayer.playing) {
        // 获取音频数据并更新可视化
        _updateAudioData();
        // 触发重绘
        _animationController.forward(from: 0.0);
      }
    });

    // 监听播放状态，仅在播放时运行动画
    widget.audioPlayer.playingStream.listen((isPlaying) {
      if (isPlaying) {
        // 播放状态：启动动画
        _animationController.repeat(reverse: false);
      } else {
        // 非播放状态：停止动画
        _animationController.stop();
        // 重置频谱数据
        if (mounted) {
          setState(() {
            _fftData = List.filled(_barCount, _minHeight);
          });
        }
      }
    });

    // 如果当前正在播放，则启动动画
    if (widget.audioPlayer.playing) {
      _animationController.repeat(reverse: false);
    }
  }

  @override
  void didUpdateWidget(RealAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果音频播放器实例变化，可以在这里处理
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 更新音频数据并进行FFT分析
  void _updateAudioData() {
    if (!widget.audioPlayer.playing) return;

    // 模拟从音频流获取数据
    // 注意：just_audio目前不直接提供原始PCM数据访问
    // 这里我们使用一个模拟的方法，根据当前播放状态生成更真实的频谱数据
    _simulateAudioData();

    // 将音频数据复制到FFT缓冲区
    for (int i = 0; i < _audioBuffer.length; i++) {
      _fftBuffer[i] = Float64x2(_audioBuffer[i], 0.0); // 实部为音频数据，虚部为0
    }

    // 执行FFT变换
    _fft.inPlaceFft(_fftBuffer);

    // 计算频谱幅度并映射到可视化柱状图
    if (mounted) {
      setState(() {
        // 将FFT结果映射到柱状图数量
        for (int i = 0; i < _barCount; i++) {
          // 计算当前柱状对应的FFT bin索引（使用对数映射以更好地表示音频频谱）
          int binIndex = _logScale(i, _barCount, 1, _fftBuffer.length ~/ 4);

          // 计算幅度（模）
          double magnitude = sqrt(
              _fftBuffer[binIndex].x * _fftBuffer[binIndex].x +
                  _fftBuffer[binIndex].y * _fftBuffer[binIndex].y);

          // 归一化并应用平滑
          double normalizedValue = min(1.0, magnitude / 50.0); // 归一化到0-1范围

          // 应用平滑过渡
          _fftData[i] = _fftData[i] * (1 - _smoothingFactor) +
              normalizedValue * _smoothingFactor;

          // 确保最小高度
          _fftData[i] = max(_fftData[i], _minHeight);
        }
      });
    }
  }

  // 模拟从音频流获取数据
  // 在实际应用中，这应该从音频引擎获取实时PCM数据
  void _simulateAudioData() {
    // 获取当前播放位置作为随机种子，使频谱变化与音乐节奏相关
    final position = widget.audioPlayer.position.inMilliseconds;
    final random = Random(position ~/ 100); // 每100毫秒变化一次

    // 生成更真实的音频数据模拟
    for (int i = 0; i < _audioBuffer.length; i++) {
      // 低频区域（低音）
      if (i < _audioBuffer.length * 0.1) {
        _audioBuffer[i] = random.nextDouble() * 0.8 + 0.2;
      }
      // 中频区域（人声、主旋律）
      else if (i < _audioBuffer.length * 0.5) {
        _audioBuffer[i] = random.nextDouble() * 0.6 + 0.1;
      }
      // 高频区域
      else {
        _audioBuffer[i] = random.nextDouble() * 0.4;
      }

      // 应用窗函数（汉宁窗）以减少频谱泄漏
      double windowFactor =
          0.5 * (1 - cos(2 * pi * i / (_audioBuffer.length - 1)));
      _audioBuffer[i] *= windowFactor;
    }
  }

  // 对数映射函数，用于更好地分布频率
  int _logScale(int index, int totalBars, int minFreq, int maxFreq) {
    // 对数映射，使低频区域有更多的柱状图
    double logPos = log(index + 1) / log(totalBars);
    return (minFreq + (maxFreq - minFreq) * logPos).round();
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否在播放
    final isPlaying = widget.audioPlayer.playing;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
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
              // 获取当前柱状的高度
              double height = isPlaying ? _fftData[index] : _minHeight;

              // 添加一些随机抖动以使可视化效果更生动
              if (isPlaying) {
                height += (Random().nextDouble() - 0.5) * 0.05;
                height = max(_minHeight, min(1.0, height));
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
