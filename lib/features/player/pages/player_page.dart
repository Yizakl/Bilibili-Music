import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../core/services/audio_player_service.dart';

class PlayerPage extends StatefulWidget {
  final String bvid;
  final String? cid;
  final String? title;
  final String? uploader;

  const PlayerPage({
    Key? key,
    required this.bvid,
    this.cid,
    this.title,
    this.uploader,
  }) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final BilibiliService _bilibiliService;
  late final AudioPlayerService _audioPlayerService;
  bool _isLoading = false;
  String _loadingText = '';
  String? _errorMessage;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _bilibiliService = Provider.of<BilibiliService>(context, listen: false);
    _audioPlayerService = AudioPlayerService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudio();
    });
  }

  void _playAudio() async {
    setState(() {
      _isLoading = true;
      _loadingText = '准备播放音频...';
    });

    try {
      final bvid = widget.bvid;
      String? audioUrl;

      // 获取音频URL
      if (widget.cid != null) {
        setState(() {
          _loadingText = '获取音频URL...';
        });

        // 使用带回退机制的方法获取音频URL
        audioUrl = await _bilibiliService.getAudioUrlWithFallback(
            bvid, int.parse(widget.cid!));
      } else {
        setState(() {
          _loadingText = '获取视频信息...';
        });

        // 先获取视频信息
        final videoInfo = await _bilibiliService.getVideoInfo(bvid);
        if (videoInfo != null && videoInfo.cid != null) {
          setState(() {
            _loadingText = '获取音频URL...';
          });

          audioUrl = await _bilibiliService.getAudioUrlWithFallback(
              bvid, int.parse(videoInfo.cid!));
        }
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '无法获取音频URL';
        });
        return;
      }

      setState(() {
        _loadingText = '开始播放...';
      });

      if (audioUrl.contains('m4s')) {
        // 使用专用方法播放m4s格式
        await _audioPlayerService.playUrl(audioUrl, headers: {
          'Referer': 'https://www.bilibili.com/video/$bvid',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        });
      } else {
        // 使用常规方法播放其他格式
        await _audioPlayerService.play(
          audioUrl,
          title: widget.title ?? '未知标题',
          artist: widget.uploader ?? '未知UP主',
        );
      }

      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '播放失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('播放器'),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(_loadingText),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _playAudio,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPlaying ? Icons.music_note : Icons.play_arrow,
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(widget.title ?? '未知标题',
                        style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 8),
                    Text(widget.uploader ?? '未知UP主'),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (_isPlaying) {
                          _audioPlayerService.pause();
                          setState(() => _isPlaying = false);
                        } else {
                          _audioPlayerService.resume();
                          setState(() => _isPlaying = true);
                        }
                      },
                      child: Text(_isPlaying ? '暂停' : '播放'),
                    ),
                  ],
                ),
    );
  }
}
