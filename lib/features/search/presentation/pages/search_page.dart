import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../player/models/audio_item.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../../core/services/bilibili_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  List<AudioItem> _searchResults = [];
  List<String> _searchHistory = [];
  List<AudioItem> _hotRecommendations = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final bilibiliService = context.read<BilibiliService>();
      _hotRecommendations = await bilibiliService.getHotRecommendations();
    } catch (e) {
      setState(() => _error = '加载推荐失败：$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bilibiliService = context.read<BilibiliService>();
      final results = await bilibiliService.searchVideos(query);
      
      setState(() {
        _searchResults = results;
        if (!_searchHistory.contains(query)) {
          _searchHistory.insert(0, query);
          if (_searchHistory.length > 10) {
            _searchHistory.removeLast();
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = '搜索失败：$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Form(
          key: _formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索B站视频',
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults.clear();
                        });
                      },
                    ),
                  ),
                  onFieldSubmitted: _performSearch,
                  textInputAction: TextInputAction.search,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  _performSearch(_searchController.text);
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // 搜索历史和热门推荐
          if (_searchResults.isEmpty && !_isLoading)
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: '搜索历史'),
                        Tab(text: '热门推荐'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildSearchHistory(),
                          _buildHotRecommendations(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 加载指示器
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // 错误提示
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          // 搜索结果
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        item.thumbnail,
                        width: 80,
                        height: 45,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 45,
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          );
                        },
                      ),
                    ),
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(child: Text(item.uploader)),
                        if (item.playCount != null) ...[
                          Icon(
                            Icons.play_arrow,
                            size: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 2),
                          Text(_formatPlayCount(item.playCount!)),
                        ],
                      ],
                    ),
                    onTap: () => _playAudio(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _playAudio(AudioItem item) async {
    try {
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载音频...'),
            ],
          ),
        ),
      );
      
      try {
        // 获取音频URL
        final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
        final audioUrl = await bilibiliService.getAudioUrl(item.id);
        
        // 关闭加载对话框
        if (mounted) {
          Navigator.pop(context);
        }
        
        // 创建完整的音频项
        final audioItem = item.copyWith(audioUrl: audioUrl);
        
        // 打开播放器页面
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerPage(audioItem: audioItem),
            ),
          );
        }
      } catch (e) {
        // 关闭加载对话框
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('获取音频失败: $e'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '重试',
                onPressed: () => _playAudio(item),
              ),
            ),
          );
        }
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取音频失败: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _playAudio(item),
            ),
          ),
        );
      }
    }
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return const Center(child: Text('暂无搜索历史'));
    }

    return ListView.builder(
      itemCount: _searchHistory.length,
      itemBuilder: (context, index) {
        final query = _searchHistory[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(query),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _searchHistory.removeAt(index);
              });
            },
          ),
          onTap: () {
            _searchController.text = query;
            _performSearch(query);
          },
        );
      },
    );
  }

  Widget _buildHotRecommendations() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_hotRecommendations.isEmpty) {
      return const Center(child: Text('暂无推荐'));
    }

    return ListView.builder(
      itemCount: _hotRecommendations.length,
      itemBuilder: (context, index) {
        final item = _hotRecommendations[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              item.thumbnail,
              width: 80,
              height: 45,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  height: 45,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                );
              },
            ),
          ),
          title: Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Expanded(child: Text(item.uploader)),
              if (item.playCount != null) ...[
                Icon(
                  Icons.play_arrow,
                  size: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 2),
                Text(_formatPlayCount(item.playCount!)),
              ],
            ],
          ),
          onTap: () => _playAudio(item),
        );
      },
    );
  }

  String _formatPlayCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}千';
    } else {
      return count.toString();
    }
  }
} 