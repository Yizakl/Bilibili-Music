import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../core/models/video_item.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../player/models/audio_item.dart' as player_models;
import 'package:go_router/go_router.dart';
import '../widgets/video_card.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final List<String> _categories = [
    '推荐',
    '音乐',
    '舞蹈',
    '游戏',
    '知识',
    '生活',
    '美食',
    '动画'
  ];
  String _selectedCategory = '推荐';
  List<VideoItem> _videos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);
      List<VideoItem> videos;

      // 根据选择的分类加载不同的视频
      if (_selectedCategory == '推荐') {
        videos = await bilibiliService.getHotRecommendations();
      } else {
        // 将分类名称映射到分类ID
        final categoryMap = {
          '音乐': 1,
          '舞蹈': 2,
          '游戏': 3,
          '知识': 4,
          '生活': 5,
          '美食': 6,
          '动画': 7,
        };
        final categoryId = categoryMap[_selectedCategory] ?? 1;
        videos = await bilibiliService.getCategoryVideos(categoryId);
      }

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: CustomScrollView(
        slivers: [
          // 顶部 AppBar
          SliverAppBar(
            floating: true,
            title: const Text('发现'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadVideos,
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () {
                  // 跳转到设置页面（包含用户信息）
                  DefaultTabController.of(context).animateTo(3);
                },
              ),
            ],
          ),
          // 搜索栏
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                hintText: '搜索视频、UP主',
                leading: const Icon(Icons.search),
                onTap: () {
                  // 跳转到搜索页面
                  DefaultTabController.of(context).animateTo(2);
                },
              ),
            ),
          ),
          // 分类标签
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ..._categories.map((label) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(label),
                          selected: label == _selectedCategory,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = label;
                              });
                              _loadVideos();
                            }
                          },
                        ),
                      )),
                ],
              ),
            ),
          ),

          // 加载指示器
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // 错误信息
          if (_error != null)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVideos,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 推荐内容网格
          if (!_isLoading && _error == null)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final video = _videos[index];
                    return VideoCard(video: video);
                  },
                  childCount: _videos.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
