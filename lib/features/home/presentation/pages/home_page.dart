import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/audio_item.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../player/models/audio_item.dart' as player_models;
import '../../../search/presentation/pages/search_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import 'discover_page.dart';
import '../../../library/presentation/pages/library_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _pageController = PageController();

  final List<Widget> _pages = [
    const DiscoverPage(),
    const LibraryPage(),
    const SearchPage(),
    const SettingsPage(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openAudioPlayer(AudioItem item) async {
    try {
      // 只使用旧播放器
      final playerAudioItem = player_models.AudioItem(
        id: item.id,
        title: item.title,
        uploader: item.uploader,
        thumbnail: item.thumbnail,
        audioUrl: item.audioUrl,
        addedTime: item.addedTime,
        isFavorite: item.isFavorite,
        isDownloaded: item.isDownloaded,
        playCount: item.playCount,
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerPage(audioItem: playerAudioItem),
        ),
      );
    } catch (e) {
      debugPrint('打开音频播放器失败: $e');
      // 出错时显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('打开播放器失败: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        physics: const NeverScrollableScrollPhysics(), // 禁止滑动切换
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            _pageController.jumpToPage(index);
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: '音乐库',
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
    );
  }
} 