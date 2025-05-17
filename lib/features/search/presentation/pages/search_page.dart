import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../player/models/audio_item.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../core/models/video_item.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/favorites_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<VideoItem> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  List<String> _searchHistory = [];
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final text = _searchController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _searchSuggestions = [];
      });
      return;
    }

    // 从搜索历史中过滤建议
    setState(() {
      _searchSuggestions = _searchHistory
          .where(
              (history) => history.toLowerCase().contains(text.toLowerCase()))
          .toList();
      _showSuggestions = true;
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveSearchHistory(String keyword) async {
    if (keyword.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];

    // 移除重复项并将新搜索添加到开头
    history.remove(keyword);
    history.insert(0, keyword);

    // 只保留最近的20条记录
    if (history.length > 20) {
      history.removeLast();
    }

    await prefs.setStringList('search_history', history);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    setState(() {
      _searchHistory = [];
    });
  }

  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });

    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);
      final results = await bilibiliService.searchVideos(keyword);

      await _saveSearchHistory(keyword);

      setState(() {
        _searchResults = results;
        _isLoading = false;
        _hasSearched = true;
      });

      _animationController.forward(from: 0.0);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索失败: $e'),
            action: SnackBarAction(
              label: '重试',
              onPressed: _performSearch,
            ),
          ),
        );
      }
    }
  }

  void _navigateToPlayer(VideoItem video) async {
    final bilibiliService =
        Provider.of<BilibiliService>(context, listen: false);

    try {
      setState(() => _isLoading = true);

      // 使用新的音频URL获取方法
      final audioUrl = await bilibiliService.getAudioUrl(video.bvid);
      if (audioUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取音频URL')),
          );
        }
        return;
      }

      // 创建AudioItem
      final audioItem = AudioItem(
        id: video.id,
        bvid: video.bvid,
        title: video.title,
        uploader: video.uploader,
        thumbnail: video.fixedThumbnail,
        audioUrl: audioUrl,
        addedTime: DateTime.now(),
      );

      if (mounted) {
        context.push('/player', extra: {'audio_item': audioItem});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取音频失败: $e'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _navigateToPlayer(video),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleFavorite(VideoItem video) async {
    final favoritesService =
        Provider.of<FavoritesService>(context, listen: false);
    final isFavorite = favoritesService.isFavorite(video.id);

    try {
      if (isFavorite) {
        await favoritesService.removeFavorite(video.id);
        EasyLoading.showSuccess('已取消收藏');
      } else {
        await favoritesService.addFavorite(video);
        EasyLoading.showSuccess('已添加到收藏');
      }
    } catch (e) {
      EasyLoading.showError('操作失败: $e');
    }
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _clearSearchHistory,
                icon: const Icon(Icons.delete_outline),
                label: const Text('清除'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchHistory.length,
          itemBuilder: (context, index) {
            final keyword = _searchHistory[index];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(keyword),
              onTap: () {
                _searchController.text = keyword;
                _performSearch();
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchSuggestions() {
    if (!_showSuggestions || _searchSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _searchSuggestions[index];
          return ListTile(
            leading: const Icon(Icons.search),
            title: Text(suggestion),
            onTap: () {
              _searchController.text = suggestion;
              _performSearch();
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
      ),
      body: RefreshIndicator(
        onRefresh: _performSearch,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // 搜索输入框
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '输入BV号、AV号或视频标题',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _showSuggestions = false;
                                    _searchSuggestions = [];
                                  });
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _performSearch,
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),

                  // 搜索建议
                  _buildSearchSuggestions(),

                  // 搜索历史
                  if (!_hasSearched && !_isLoading) _buildSearchHistory(),
                ],
              ),
            ),

            // 搜索结果
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_hasSearched)
              if (_searchResults.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '未找到结果',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final video = _searchResults[index];
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ListTile(
                          leading: Hero(
                            tag: 'video_thumbnail_${video.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                video.fixedThumbnail,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.grey,
                                    child: const Icon(Icons.error),
                                  );
                                },
                              ),
                            ),
                          ),
                          title: Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(video.uploader),
                              Text(
                                '播放量: ${video.formattedPlayCount}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Consumer<FavoritesService>(
                                builder: (context, favoritesService, child) {
                                  final isFavorite =
                                      favoritesService.isFavorite(video.id);
                                  return IconButton(
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFavorite ? Colors.red : null,
                                    ),
                                    onPressed: () => _toggleFavorite(video),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () => _navigateToPlayer(video),
                              ),
                            ],
                          ),
                          onTap: () => _navigateToPlayer(video),
                        ),
                      );
                    },
                    childCount: _searchResults.length,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
