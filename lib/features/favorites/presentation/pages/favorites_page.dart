import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/audio_player_manager.dart';
import '../../../player/models/audio_item.dart';
import 'package:go_router/go_router.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late AudioPlayerManager _audioPlayerManager;
  List<AudioItem> _favorites = [];

  @override
  void initState() {
    super.initState();
    _audioPlayerManager =
        Provider.of<AudioPlayerManager>(context, listen: false);
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() {
      _favorites = _audioPlayerManager.favorites;
    });
  }

  void _playAudio(AudioItem audioItem) {
    _audioPlayerManager.playAudio(audioItem);

    // 可选：跳转到播放页面
    context.push('/player', extra: {'audio_item': audioItem});
  }

  void _removeFromFavorites(AudioItem audioItem) async {
    await _audioPlayerManager.removeFromFavorites(audioItem.id);
    setState(() {
      _favorites = _audioPlayerManager.favorites;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${audioItem.title} 已从收藏夹中移除'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              await _audioPlayerManager.addToFavorites(audioItem);
              setState(() {
                _favorites = _audioPlayerManager.favorites;
              });
            },
          ),
        ),
      );
    }
  }

  void _playAllFavorites() {
    if (_favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收藏夹为空')),
      );
      return;
    }

    _audioPlayerManager.setPlaylist(_favorites);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在播放收藏列表')),
    );
  }

  void _shufflePlayFavorites() {
    if (_favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收藏夹为空')),
      );
      return;
    }

    _audioPlayerManager.setPlaylist(_favorites);
    _audioPlayerManager.toggleShuffleMode();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在随机播放收藏列表')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '我的收藏',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: '随机播放',
            onPressed: _shufflePlayFavorites,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: '播放全部',
            onPressed: _playAllFavorites,
          ),
        ],
      ),
      body: _favorites.isEmpty ? _buildEmptyView() : _buildFavoritesList(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 72,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '收藏夹为空',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '在播放页面点击❤️将音频添加到收藏夹',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final audioItem = _favorites[index];
        return Dismissible(
          key: Key(audioItem.id),
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
          onDismissed: (direction) {
            _removeFromFavorites(audioItem);
          },
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  audioItem.thumbnail,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey,
                      child: const Icon(Icons.music_note),
                    );
                  },
                ),
              ),
              title: Text(
                audioItem.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                audioItem.uploader,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playAudio(audioItem),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () => _removeFromFavorites(audioItem),
                  ),
                ],
              ),
              onTap: () => _playAudio(audioItem),
            ),
          ),
        );
      },
    );
  }
}
