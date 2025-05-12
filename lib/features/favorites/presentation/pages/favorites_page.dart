import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/video_item.dart';
import '../../../../core/services/favorites_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearConfirmation(context),
          ),
        ],
      ),
      body: Consumer<FavoritesService>(
        builder: (context, favoritesService, child) {
          final favorites = favoritesService.favorites;

          if (favorites.isEmpty) {
            return const Center(
              child: Text('暂无收藏视频'),
            );
          }

          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final video = favorites[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      video.fixedThumbnail,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
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
                        onPressed: () => _removeFavorite(context, video),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          // TODO: 实现播放功能
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    // TODO: 实现播放功能
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _removeFavorite(BuildContext context, VideoItem video) async {
    try {
      final favoritesService =
          Provider.of<FavoritesService>(context, listen: false);
      await favoritesService.removeFavorite(video.id);
      EasyLoading.showSuccess('已取消收藏');
    } catch (e) {
      EasyLoading.showError('取消收藏失败: $e');
    }
  }

  Future<void> _showClearConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空收藏'),
        content: const Text('确定要清空所有收藏吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final favoritesService =
            Provider.of<FavoritesService>(context, listen: false);
        await favoritesService.clearFavorites();
        EasyLoading.showSuccess('已清空收藏');
      } catch (e) {
        EasyLoading.showError('清空收藏失败: $e');
      }
    }
  }
}
