import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/video_item.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../home/presentation/widgets/video_list_item.dart';

class VideoPartsPage extends StatefulWidget {
  final String bvid;

  const VideoPartsPage({
    super.key,
    required this.bvid,
  });

  @override
  State<VideoPartsPage> createState() => _VideoPartsPageState();
}

class _VideoPartsPageState extends State<VideoPartsPage> {
  List<VideoItem> _parts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParts();
  }

  Future<void> _loadParts() async {
    try {
      final bilibiliService = context.read<BilibiliService>();
      final parts = await bilibiliService.getVideoParts(widget.bvid);

      setState(() {
        _parts = parts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadParts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频分P'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '加载失败: $_error',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_parts.isEmpty) {
      return const Center(
        child: Text('没有找到分P视频'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        itemCount: _parts.length,
        itemBuilder: (context, index) {
          final part = _parts[index];
          return VideoListItem(
            video: part,
            onTap: () {
              Navigator.pop(context, part);
            },
          );
        },
      ),
    );
  }
}
