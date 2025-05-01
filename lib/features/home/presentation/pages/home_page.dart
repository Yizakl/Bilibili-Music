import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/audio_item.dart' as core_models;
import '../../../../core/services/bilibili_service.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../player/models/audio_item.dart' as player_models;
import '../../../search/presentation/pages/search_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import 'discover_page.dart' hide VideoCard;
import '../../../library/presentation/pages/library_page.dart';
import '../widgets/video_card.dart';
import '../widgets/category_selector.dart';
import '../../../../core/models/video_item.dart';
import '../widgets/mini_player.dart';
import '../../../../core/services/audio_player_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<VideoItem>> _popularVideosFuture;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'id': 1, 'name': '音乐', 'icon': Icons.music_note},
    {'id': 3, 'name': '娱乐', 'icon': Icons.movie},
    {'id': 4, 'name': '游戏', 'icon': Icons.sports_esports},
    {'id': 5, 'name': '动画', 'icon': Icons.animation},
    {'id': 119, 'name': '鬼畜', 'icon': Icons.emoji_emotions},
    {'id': 160, 'name': '生活', 'icon': Icons.restaurant},
    {'id': 181, 'name': '影视', 'icon': Icons.video_library},
    {'id': 188, 'name': '科技', 'icon': Icons.science},
  ];

  int _selectedCategoryId = 1; // 默认选择音乐分区
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPopularVideos();
  }

  void _loadPopularVideos() {
    final bilibiliService =
        Provider.of<BilibiliService>(context, listen: false);
    _popularVideosFuture = bilibiliService.getPopularVideos();
  }

  Future<List<VideoItem>> _loadCategoryVideos(int categoryId) {
    final bilibiliService =
        Provider.of<BilibiliService>(context, listen: false);
    return bilibiliService.getCategoryVideos(categoryId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onCategorySelected(int categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  void _navigateToSearch() {
    context.push('/search');
  }

  void _navigateToPlayer(VideoItem video) async {
    final bilibiliService =
        Provider.of<BilibiliService>(context, listen: false);

    try {
      // 使用mir6 API获取音频URL
      final audioUrl = await bilibiliService.getAudioUrlWithMir6Api(video.id);
      if (audioUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取音频URL')),
          );
        }
        return;
      }

      // 创建AudioItem
      final audioItem = player_models.AudioItem(
        id: video.id,
        title: video.title,
        uploader: video.uploader,
        thumbnail: video.thumbnail,
        audioUrl: audioUrl, // 使用mir6 API返回的URL
        addedTime: DateTime.now(),
      );

      if (mounted) {
        context.push('/player', extra: {'audio_item': audioItem});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取音频失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerManager = Provider.of<AudioPlayerManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilibili Music'),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          // 首页内容
          Column(
            children: [
              // 搜索栏
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '输入BV号或视频链接',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onSubmitted: (value) {
                    // 处理搜索逻辑
                    if (value.isNotEmpty) {
                      _navigateToSearch();
                    }
                  },
                ),
              ),

              // 历史记录列表
              Expanded(
                child: FutureBuilder<List<VideoItem>>(
                  future: Future.value(
                      Provider.of<BilibiliService>(context).getPlayHistory()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('暂无播放历史'),
                      );
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data![index];
                        return ListTile(
                          title: Text(item.title),
                          subtitle: Text(item.uploader),
                          leading: Image.network(
                            item.thumbnail,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey,
                                child: const Icon(Icons.error),
                              );
                            },
                          ),
                          trailing: const Icon(Icons.play_arrow),
                          onTap: () {
                            _navigateToPlayer(item);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // 发现页
          const DiscoverPage(),
          // 搜索页
          const SearchPage(),
          // 设置页
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 迷你播放器
          ValueListenableBuilder<player_models.AudioItem?>(
            valueListenable: audioPlayerManager.currentAudioNotifier,
            builder: (context, currentAudio, child) {
              if (currentAudio == null) {
                return const SizedBox.shrink();
              }

              return MiniPlayer(
                currentAudio: currentAudio,
                onTap: () {
                  context.push('/player', extra: {'audio_item': currentAudio});
                },
              );
            },
          ),

          // 底部导航栏
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: '发现',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: '搜索',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedTab() {
    final bilibiliService = Provider.of<BilibiliService>(context);
    return FutureBuilder(
      future: bilibiliService.getPopularVideos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _loadPopularVideos();
                  }),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final videos = snapshot.data ?? [];

        if (videos.isEmpty) {
          return const Center(child: Text('暂无推荐视频'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _loadPopularVideos();
            });
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              return VideoCard(
                video: videos[index],
                onTap: () => _navigateToPlayer(videos[index]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPopularTab() {
    return FutureBuilder(
      future: _popularVideosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _loadPopularVideos();
                  }),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final videos = snapshot.data ?? [];

        if (videos.isEmpty) {
          return const Center(child: Text('暂无热门视频'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _loadPopularVideos();
            });
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _navigateToPlayer(videos[index]),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            videos[index].thumbnail,
                            width: 120,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 120,
                                height: 80,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.error),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                videos[index].title,
                                style: Theme.of(context).textTheme.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                videos[index].uploader,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.play_arrow,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    videos[index].formattedPlayCount,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    videos[index].duration,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryTab() {
    return Column(
      children: [
        CategorySelector(
          categories: _categories,
          selectedCategoryId: _selectedCategoryId,
          onCategorySelected: _onCategorySelected,
        ),
        Expanded(
          child: FutureBuilder(
            future: _loadCategoryVideos(_selectedCategoryId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('加载失败: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                );
              }

              final videos = snapshot.data ?? [];

              if (videos.isEmpty) {
                return const Center(child: Text('该分区暂无视频'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _navigateToPlayer(videos[index]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 视频封面
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: Image.network(
                              videos[index].thumbnail,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: 160,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.error, size: 48),
                                );
                              },
                            ),
                          ),

                          // 视频信息
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  videos[index].title,
                                  style: Theme.of(context).textTheme.titleSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      child: Text(
                                        videos[index].uploader.substring(0, 1),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      videos[index].uploader,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.play_arrow,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      videos[index].formattedPlayCount,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesTab() {
    final bilibiliService = Provider.of<BilibiliService>(context);
    final favorites = bilibiliService.getFavorites();

    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无收藏内容',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToSearch,
              icon: const Icon(Icons.search),
              label: const Text('去搜索感兴趣的内容'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        return Dismissible(
          key: Key(favorites[index].id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red,
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          onDismissed: (direction) {
            bilibiliService.removeFromFavorites(favorites[index].id);
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已从收藏中移除: ${favorites[index].title}'),
                action: SnackBarAction(
                  label: '撤销',
                  onPressed: () {
                    bilibiliService.addToFavorites(favorites[index]);
                    setState(() {});
                  },
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _navigateToPlayer(favorites[index]),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        favorites[index].thumbnail,
                        width: 120,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 80,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.error),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            favorites[index].title,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            favorites[index].uploader,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                size: 16,
                                color: Colors.pink,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '已收藏',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                favorites[index].duration,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
