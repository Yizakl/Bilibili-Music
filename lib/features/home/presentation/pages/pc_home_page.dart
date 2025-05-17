import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../core/services/audio_player_manager.dart';
import '../../../player/presentation/widgets/mini_player.dart';
import '../../../player/presentation/pages/audio_player_page.dart';
import '../../../search/presentation/pages/search_page.dart';
import '../../../../core/models/video_item.dart';
import '../../../player/presentation/pages/video_player_page.dart';
import '../../../player/pages/player_page.dart';

class PCHomePage extends StatefulWidget {
  const PCHomePage({Key? key}) : super(key: key);

  @override
  _PCHomePageState createState() => _PCHomePageState();
}

class _PCHomePageState extends State<PCHomePage> {
  int _selectedIndex = 0;
  final List<String> _navigationItems = ['推荐', '排行榜', '歌单', '本地'];
  late List<VideoItem> _recommendedVideos = [];
  late List<VideoItem> _rankingVideos = [];

  @override
  void initState() {
    super.initState();
    _fetchRecommendedVideos();
    _fetchRankingVideos();
  }

  Future<void> _fetchRecommendedVideos() async {
    final bilibiliService =
        Provider.of<BilibiliService>(context, listen: false);
    try {
      final popularVideos = await bilibiliService.getPopularVideos();
      setState(() {
        _recommendedVideos = popularVideos;
      });
    } catch (e) {
      debugPrint('获取推荐视频失败: $e');
    }
  }

  Future<void> _fetchRankingVideos() async {
    final bilibiliService =
        Provider.of<BilibiliService>(context, listen: false);
    try {
      // 获取音乐分区的热门视频
      final musicVideos = await bilibiliService.getRegionPopularVideos(
        BilibiliService.regionTids['音乐'] ?? 3,
      );
      setState(() {
        _rankingVideos = musicVideos;
      });
    } catch (e) {
      debugPrint('获取排行榜视频失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerManager>(
      builder: (context, audioPlayerManager, child) {
        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // 左侧导航栏
                    NavigationRail(
                      backgroundColor: Theme.of(context).cardColor,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: _navigationItems.map((item) {
                        return NavigationRailDestination(
                          icon: Icon(Icons.music_note_outlined),
                          selectedIcon: Icon(Icons.music_note),
                          label: Text(item),
                        );
                      }).toList(),
                    ),

                    // 分隔线
                    const VerticalDivider(thickness: 1, width: 1),

                    // 主内容区域
                    Expanded(
                      child: _buildMainContent(),
                    ),
                  ],
                ),
              ),

              // 迷你播放器
              const MiniPlayerWidget(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildRecommendedContent();
      case 1:
        return _buildRankingContent();
      case 2:
        return _buildPlaylistContent();
      case 3:
        return _buildLocalContent();
      default:
        return Container();
    }
  }

  Widget _buildRecommendedContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          AppBar(
            title: Text('推荐'),
            actions: [
              IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SearchPage()),
                  );
                },
              ),
            ],
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _recommendedVideos.length,
              itemBuilder: (context, index) {
                final video = _recommendedVideos[index];
                return _buildRecommendedItem(video);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedItem(VideoItem video) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerPage.fromVideo(video),
          ),
        );
      },
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                video.fixedThumbnail,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    video.uploader,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          AppBar(title: Text('排行榜')),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _rankingVideos.length,
              itemBuilder: (context, index) {
                final video = _rankingVideos[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(video.fixedThumbnail),
                  ),
                  title: Text(video.title),
                  subtitle: Text(video.uploader),
                  trailing: IconButton(
                    icon: Icon(Icons.play_circle_outline),
                    onPressed: () {
                      // TODO: 实现播放逻辑
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistContent() {
    return Column(
      children: [
        AppBar(
          title: Text('歌单'),
          actions: [
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                // TODO: 实现创建歌单逻辑
              },
            ),
          ],
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 8, // 示例数量，后续需要从 API 获取
            itemBuilder: (context, index) {
              return Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        'https://via.placeholder.com/200', // 替换为实际图片
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '歌单 $index',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocalContent() {
    return Column(
      children: [
        AppBar(title: Text('本地音乐')),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                leading: Icon(Icons.music_note),
                title: Text('本地音乐'),
                trailing: Text('0首'),
                onTap: () {
                  // TODO: 实现本地音乐列表
                },
              ),
              ListTile(
                leading: Icon(Icons.download),
                title: Text('下载管理'),
                trailing: Text('0首'),
                onTap: () {
                  // TODO: 实现下载管理
                },
              ),
              ListTile(
                leading: Icon(Icons.favorite_border),
                title: Text('我的收藏'),
                trailing: Text('0首'),
                onTap: () {
                  // TODO: 实现收藏列表
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
