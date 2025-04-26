import 'package:bilibili_music/features/player/models/audio_item.dart';
import 'package:flutter/material.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐库'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '收藏'),
            Tab(text: '历史'),
            Tab(text: '下载'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FavoritesTab(),
          _HistoryTab(),
          _DownloadsTab(),
        ],
      ),
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    return const AudioList(
      title: '收藏',
      emptyMessage: '还没有收藏的音频',
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return const AudioList(
      title: '历史记录',
      emptyMessage: '还没有播放历史',
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context) {
    return const AudioList(
      title: '下载管理',
      emptyMessage: '还没有下载的音频',
    );
  }
}

class AudioList extends StatelessWidget {
  final String title;
  final String emptyMessage;

  const AudioList({
    super.key,
    required this.title,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: 从数据库加载数据
    final List<AudioItem> items = [];

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return AudioListTile(item: item);
      },
    );
  }
}

class AudioListTile extends StatelessWidget {
  final AudioItem item;

  const AudioListTile({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          item.thumbnail,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 56,
              height: 56,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: const Icon(Icons.music_note),
            );
          },
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.uploader,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'play',
            child: Text('播放'),
          ),
          const PopupMenuItem(
            value: 'download',
            child: Text('下载'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('删除'),
          ),
        ],
        onSelected: (value) {
          // TODO: 处理菜单操作
        },
      ),
      onTap: () {
        // TODO: 播放音频
      },
    );
  }
} 