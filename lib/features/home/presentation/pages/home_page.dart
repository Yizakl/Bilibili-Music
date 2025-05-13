import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/audio_player_manager.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../features/player/models/audio_item.dart' as player_models;
import '../../../../core/models/video_item.dart';
import '../../../../core/services/favorites_service.dart';
import 'hot_videos_page.dart';
import '../widgets/video_list_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeTabView(),
    const SearchTabView(),
    const LibraryTabView(),
  ];

  @override
  Widget build(BuildContext context) {
    final audioManager = Provider.of<AudioPlayerManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilibili Music'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          )
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini Player
          Consumer<AudioPlayerManager>(
            builder: (context, manager, _) {
              final currentItem = manager.currentAudio;
              if (currentItem == null) {
                return const SizedBox.shrink();
              }

              return GestureDetector(
                onTap: () {
                  context.push('/player', extra: {'audio_item': currentItem});
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey[300],
                        child: Center(
                          child: Text(
                            "HandshakeException: Connection terminated during handshake",
                            style: const TextStyle(fontSize: 8),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentItem.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentItem.uploader,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          manager.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: () {
                          if (manager.isPlaying) {
                            manager.pause();
                          } else {
                            manager.resume();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Navigation Bar
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: '搜索',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: '收藏',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeTabView extends StatefulWidget {
  const HomeTabView({super.key});

  @override
  _HomeTabViewState createState() => _HomeTabViewState();
}

class _HomeTabViewState extends State<HomeTabView> {
  List<VideoItem> _recentlyPlayed = [];
  List<VideoItem> _hotVideos = [];
  bool _isLoadingHistory = true;
  bool _isLoadingHot = true;

  @override
  void initState() {
    super.initState();
    _loadPlayHistory();
    _loadHotVideos();
  }

  Future<void> _loadPlayHistory() async {
    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);

      // 检查服务是否可用
      if (!context.mounted) {
        return;
      }

      final history = await bilibiliService.getPlayHistory();

      if (!context.mounted) {
        return;
      }

      setState(() {
        _recentlyPlayed = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _recentlyPlayed = [];
          _isLoadingHistory = false;
        });
      }
      debugPrint('加载播放历史失败: $e');
    }
  }

  Future<void> _loadHotVideos() async {
    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);

      // 检查服务是否可用
      if (!context.mounted) {
        return;
      }

      final videos = await bilibiliService.getHotVideos();

      if (!context.mounted) {
        return;
      }

      setState(() {
        _hotVideos = videos;
        _isLoadingHot = false;
      });
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _isLoadingHot = false;
        });
      }
      debugPrint('加载热门视频失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bilibiliService =
        Provider.of<BilibiliService>(context, listen: false);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadPlayHistory(),
          _loadHotVideos(),
        ]);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息卡片
            if (authService.isLoggedIn && authService.currentUser != null)
              UserInfoCard(user: authService.currentUser!)
            else
              const LoginPrompt(),

            const SizedBox(height: 24),

            // 热门榜
            _buildSectionWithMoreButton(context, '热门榜', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HotVideosPage(),
                ),
              );
            }),
            const SizedBox(height: 8),
            _isLoadingHot
                ? const Center(child: CircularProgressIndicator())
                : _hotVideos.isEmpty
                    ? const Center(child: Text('暂无热门视频'))
                    : SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              _hotVideos.length > 5 ? 5 : _hotVideos.length,
                          itemBuilder: (context, index) {
                            final video = _hotVideos[index];
                            return RecommendCard(
                              title: video.title,
                              subtitle: video.uploader,
                              imageUrl: video.fixedThumbnail,
                              onTap: () {
                                _playVideo(context, video);
                              },
                            );
                          },
                        ),
                      ),

            const SizedBox(height: 24),

            // 推荐区块
            _buildSectionWithMoreButton(context, '推荐内容', () {
              // 查看更多推荐内容
            }),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return RecommendCard(
                    title: '推荐内容 ${index + 1}',
                    subtitle: '推荐理由',
                    imageUrl: 'https://via.placeholder.com/150',
                    onTap: () {
                      _playDemoAudio(context, '推荐内容 ${index + 1}', '推荐理由');
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // 最近播放
            _buildSectionWithMoreButton(context, '最近播放', () {
              // 查看更多最近播放
            }),
            const SizedBox(height: 8),

            // 播放历史列表
            _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _recentlyPlayed.isEmpty
                    ? const Center(child: Text('暂无播放历史'))
                    : ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _recentlyPlayed.length > 3
                            ? 3
                            : _recentlyPlayed.length,
                        itemBuilder: (context, index) {
                          final video = _recentlyPlayed[index];
                          return _buildPlayHistoryItem(
                            context,
                            video.title,
                            video.uploader,
                            video.fixedThumbnail,
                            video.id,
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionWithMoreButton(
      BuildContext context, String title, VoidCallback onMorePressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onMorePressed,
          child: const Text('查看更多'),
        ),
      ],
    );
  }

  Widget _buildPlayHistoryItem(
    BuildContext context,
    String title,
    String uploader,
    String thumbnailUrl,
    String videoId,
  ) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          image: thumbnailUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(thumbnailUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: thumbnailUrl.isEmpty
            ? const Center(child: Icon(Icons.music_note))
            : null,
      ),
      title: Text(title),
      subtitle: Text(uploader),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: () {
          final video = VideoItem(
            id: videoId,
            bvid: videoId,
            title: title,
            uploader: uploader,
            thumbnail: thumbnailUrl,
            duration: const Duration(seconds: 0),
            uploadTime: DateTime.now(),
            viewCount: 0,
            likeCount: 0,
            commentCount: 0,
          );
          _playVideo(context, video);
        },
      ),
    );
  }

  void _playVideo(BuildContext context, VideoItem video) async {
    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);
      final audioManager =
          Provider.of<AudioPlayerManager>(context, listen: false);

      // 显示加载中提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在获取音频信息...')),
      );

      // 获取音频URL
      String audioUrl =
          await bilibiliService.getAudioUrl(video.id, cid: video.cid);

      if (audioUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取音频失败')),
        );
        return;
      }

      // 创建音频项并播放
      final audioItem = video.toAudioItem(audioUrl: audioUrl);
      audioManager.playAudio(audioItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在播放: ${video.title}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }

  void _playDemoAudio(BuildContext context, String title, String uploader) {
    // 播放示例音频
    final audioManager =
        Provider.of<AudioPlayerManager>(context, listen: false);

    // 创建一个模拟的音频项目
    final demoAudio = player_models.AudioItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      uploader: uploader,
      thumbnail: 'https://via.placeholder.com/60',
      audioUrl: 'https://example.com/audio.mp3', // 模拟URL
      addedTime: DateTime.now(),
    );

    // 尝试播放
    try {
      audioManager.playAudio(demoAudio);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在播放: $title')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }
}

class SearchTabView extends StatefulWidget {
  const SearchTabView({super.key});

  @override
  State<SearchTabView> createState() => _SearchTabViewState();
}

class _SearchTabViewState extends State<SearchTabView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<VideoItem> _searchResults = [];
  String _searchQuery = '';
  bool _isSearchLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _isSearchLoading = true;
      _isSearching = true;
    });

    try {
      // 使用Provider获取BilibiliService实例执行搜索
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);
      final results = await bilibiliService.searchVideos(query);

      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    } catch (e) {
      debugPrint('搜索失败: $e');
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索栏
          SearchBar(
            controller: _searchController,
            hintText: '搜索歌曲、视频、UP主',
            leading: const Icon(Icons.search),
            trailing: [
              if (_isSearching)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                    });
                  },
                ),
            ],
            onSubmitted: _performSearch,
          ),

          const SizedBox(height: 16),

          // 搜索结果或热门搜索
          Expanded(
            child: _searchResults.isNotEmpty
                ? _buildSearchResults()
                : _buildHotSearches(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final video = _searchResults[index];
        return VideoListItem(
          video: video,
          onTap: () {
            _playVideo(context, video);
          },
        );
      },
    );
  }

  Widget _buildHotSearches() {
    // 获取搜索历史
    final bilibiliService =
        Provider.of<BilibiliService>(context, listen: false);
    final searchHistory = bilibiliService.getSearchHistory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 历史搜索
        if (searchHistory.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  bilibiliService.clearSearchHistory();
                  setState(() {});
                },
                child: const Text('清除'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: searchHistory
                .map((term) => ActionChip(
                      label: Text(term),
                      onPressed: () {
                        _searchController.text = term;
                        _performSearch(term);
                      },
                    ))
                .toList(),
          ),
          const Divider(height: 24),
        ],

        // 热门搜索
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '热门搜索',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HotVideosPage(),
                  ),
                );
              },
              child: const Text('热门榜'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '周杰伦',
            '薛之谦',
            '华晨宇',
            '林俊杰',
            '陈奕迅',
            '李荣浩',
          ]
              .map((term) => ActionChip(
                    label: Text(term),
                    onPressed: () {
                      _searchController.text = term;
                      _performSearch(term);
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  void _playVideo(BuildContext context, VideoItem video) async {
    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);
      final audioManager =
          Provider.of<AudioPlayerManager>(context, listen: false);

      // 显示加载中提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在获取音频信息...')),
      );

      // 获取音频URL
      String audioUrl =
          await bilibiliService.getAudioUrl(video.id, cid: video.cid);

      if (audioUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取音频失败')),
        );
        return;
      }

      // 创建音频项并播放
      final audioItem = video.toAudioItem(audioUrl: audioUrl);
      audioManager.playAudio(audioItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在播放: ${video.title}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }
}

class LibraryTabView extends StatefulWidget {
  const LibraryTabView({super.key});

  @override
  State<LibraryTabView> createState() => _LibraryTabViewState();
}

class _LibraryTabViewState extends State<LibraryTabView> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favoritesService =
          Provider.of<FavoritesService>(context, listen: false);
      await favoritesService.loadFavorites(); // 确保加载收藏数据
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载收藏失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final favoritesService = Provider.of<FavoritesService>(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!authService.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.library_music,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              '登录后即可查看您的收藏',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.push('/login');
              },
              child: const Text('去登录'),
            ),
          ],
        ),
      );
    }

    final favorites = favoritesService.favorites;

    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite_border,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              '您还没有收藏任何内容',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.go('/'); // 回到首页
              },
              child: const Text('去收藏'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final video = favorites[index];
          return Dismissible(
            key: Key(video.id),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) async {
              try {
                await favoritesService.removeFavorite(video.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已移除: ${video.title}'),
                      action: SnackBarAction(
                        label: '撤销',
                        onPressed: () async {
                          await favoritesService.addFavorite(video);
                        },
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('移除失败: $e')),
                  );
                }
              }
            },
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video.fixedThumbnail,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error_outline),
                    );
                  },
                ),
              ),
              title: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${video.uploader} · ${video.formattedPlayCount}播放',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () async {
                      try {
                        await favoritesService.removeFavorite(video.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已取消收藏')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('取消收藏失败: $e')),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playVideo(context, video),
                  ),
                ],
              ),
              onTap: () => _playVideo(context, video),
            ),
          );
        },
      ),
    );
  }

  void _playVideo(BuildContext context, VideoItem video) async {
    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);
      final audioManager =
          Provider.of<AudioPlayerManager>(context, listen: false);

      // 显示加载中提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在获取音频信息...')),
      );

      // 获取音频URL
      String audioUrl =
          await bilibiliService.getAudioUrl(video.id, cid: video.cid);

      if (audioUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取音频失败')),
        );
        return;
      }

      // 创建音频项并播放
      final audioItem = video.toAudioItem(audioUrl: audioUrl);
      audioManager.playAudio(audioItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在播放: ${video.title}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }
}

class UserInfoCard extends StatelessWidget {
  final dynamic user;

  const UserInfoCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue,
              child: Text(
                user.username.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ID: ${user.id}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                context.push('/settings');
              },
              child: const Text('设置'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '登录B站账号',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '登录后即可同步您的B站收藏、历史记录和个人信息',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.push('/login');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 40),
              ),
              child: const Text('立即登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class RecommendCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;

  const RecommendCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 150,
              height: 100,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.image, size: 40),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
