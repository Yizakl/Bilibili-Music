import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/video_item.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../player/models/audio_item.dart' as player_models;
import 'package:go_router/go_router.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late List<VideoItem> _favorites;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      _favorites = bilibiliService.getFavorites();
    } catch (e) {
      // 处理错误
      debugPrint('加载收藏失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _navigateToPlayer(VideoItem video) async {
    final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
    
    // 获取音频URL
    final audioUrl = await bilibiliService.getAudioUrl(video.id);
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
      audioUrl: audioUrl,
      addedTime: DateTime.now(),
    );
    
    if (mounted) {
      context.push('/player', extra: {'audio_item': audioItem});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(
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
                        onPressed: () => context.push('/search'),
                        icon: const Icon(Icons.search),
                        label: const Text('去搜索感兴趣的内容'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    return Dismissible(
                      key: Key(_favorites[index].id),
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
                        final removedItem = _favorites[index];
                        Provider.of<BilibiliService>(context, listen: false)
                            .removeFromFavorites(removedItem.id);
                        
                        setState(() {
                          _favorites.removeAt(index);
                        });
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已从收藏中移除: ${removedItem.title}'),
                            action: SnackBarAction(
                              label: '撤销',
                              onPressed: () {
                                Provider.of<BilibiliService>(context, listen: false)
                                    .addToFavorites(removedItem);
                                setState(() {
                                  _favorites.insert(index, removedItem);
                                });
                              },
                            ),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _navigateToPlayer(_favorites[index]),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _favorites[index].thumbnail,
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
                                        _favorites[index].title,
                                        style: Theme.of(context).textTheme.titleSmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _favorites[index].uploader,
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
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _favorites[index].duration,
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
                ),
    );
  }
} 