import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/video_item.dart';
import '../../../../core/services/bilibili_service.dart';
import '../widgets/video_list_item.dart';

class HotVideosPage extends StatefulWidget {
  const HotVideosPage({super.key});

  @override
  State<HotVideosPage> createState() => _HotVideosPageState();
}

class _HotVideosPageState extends State<HotVideosPage> {
  final ScrollController _scrollController = ScrollController();
  List<VideoItem> _videos = [];
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bilibiliService = context.read<BilibiliService>();
      final videos = await bilibiliService.getHotVideos();

      setState(() {
        _videos.addAll(videos);
        _hasMore = videos.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadVideos();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _videos.clear();
      _hasMore = true;
    });
    await _loadVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('热门榜'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _videos.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _videos.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return VideoListItem(video: _videos[index]);
          },
        ),
      ),
    );
  }
}
