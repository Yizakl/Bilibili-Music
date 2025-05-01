import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../player/models/audio_item.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../core/models/video_item.dart';
import '../../../player/models/audio_item.dart' as player_models;
import 'package:go_router/go_router.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<VideoItem> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bilibiliService =
          Provider.of<BilibiliService>(context, listen: false);
      final results = await bilibiliService.searchVideos(keyword);

      setState(() {
        _searchResults = results;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
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
        audioUrl: audioUrl,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
      ),
      body: Column(
        children: [
          // 搜索输入框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入BV号、AV号或视频标题',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),

          // 搜索按钮
          ElevatedButton(
            onPressed: _performSearch,
            child: const Text('搜索'),
          ),

          const SizedBox(height: 16),

          // 搜索结果或加载状态
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasSearched && _searchResults.isEmpty
                    ? const Center(child: Text('未找到结果'))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final video = _searchResults[index];
                          return ListTile(
                            leading: Image.network(
                              video.thumbnail,
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
                            title: Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(video.uploader),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => _navigateToPlayer(video),
                            ),
                            onTap: () => _navigateToPlayer(video),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
