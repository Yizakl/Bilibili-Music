import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/video_item.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../player/models/audio_item.dart' as player_models;
import 'package:go_router/go_router.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<VideoItem> _history;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      _history = bilibiliService.getPlayHistory();
    } catch (e) {
      // 处理错误
      debugPrint('加载历史记录失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _clearHistory() async {
    final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要清空所有历史记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              bilibiliService.clearPlayHistory();
              setState(() {
                _history = [];
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('历史记录已清空')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
        title: const Text('播放历史'),
        actions: [
          if (!_isLoading && _history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearHistory,
              tooltip: '清空历史记录',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无播放历史',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.home),
                        label: const Text('返回首页'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    return Dismissible(
                      key: Key('${_history[index].id}_$index'),
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
                        final removedItem = _history[index];
                        Provider.of<BilibiliService>(context, listen: false)
                            .removeFromPlayHistory(removedItem.id);
                        
                        setState(() {
                          _history.removeAt(index);
                        });
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已从历史记录中移除: ${removedItem.title}'),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _navigateToPlayer(_history[index]),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _history[index].thumbnail,
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
                                        _history[index].title,
                                        style: Theme.of(context).textTheme.titleSmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _history[index].uploader,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.history,
                                            size: 16,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '最近播放',
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
                                            _history[index].duration,
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