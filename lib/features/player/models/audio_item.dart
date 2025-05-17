class AudioItem {
  final String id;
  final String bvid;
  final String title;
  final String uploader;
  final String thumbnail;
  final String audioUrl;
  final DateTime addedTime;
  final bool isFavorite;
  final bool isDownloaded;
  final int? playCount;

  const AudioItem({
    required this.id,
    required this.bvid,
    required this.title,
    required this.uploader,
    required this.thumbnail,
    required this.audioUrl,
    required this.addedTime,
    this.isFavorite = false,
    this.isDownloaded = false,
    this.playCount,
  });

  // 获取修复后的缩略图URL
  String get fixedThumbnail {
    if (thumbnail.isEmpty) {
      return 'https://i0.hdslb.com/bfs/archive/0b2557b186a418cb3d8f307a5db85adb87bb25b0.jpg';
    }

    // 处理无scheme的URL
    if (thumbnail.startsWith('//')) {
      return 'https:$thumbnail';
    }

    // 处理http链接
    if (thumbnail.startsWith('http://')) {
      return thumbnail.replaceFirst('http://', 'https://');
    }

    // 处理file:///开头的URL (不支持的scheme)
    if (thumbnail.startsWith('file:///')) {
      return 'https://i0.hdslb.com/bfs/archive/0b2557b186a418cb3d8f307a5db85adb87bb25b0.jpg';
    }

    return thumbnail;
  }

  AudioItem copyWith({
    String? id,
    String? bvid,
    String? title,
    String? uploader,
    String? audioUrl,
    String? thumbnail,
    DateTime? addedTime,
    bool? isFavorite,
    bool? isDownloaded,
    int? playCount,
  }) {
    return AudioItem(
      id: id ?? this.id,
      bvid: bvid ?? this.bvid,
      title: title ?? this.title,
      uploader: uploader ?? this.uploader,
      audioUrl: audioUrl ?? this.audioUrl,
      thumbnail: thumbnail ?? this.thumbnail,
      addedTime: addedTime ?? this.addedTime,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      playCount: playCount ?? this.playCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bvid': bvid,
      'title': title,
      'uploader': uploader,
      'thumbnail': thumbnail,
      'audioUrl': audioUrl,
      'addedTime': addedTime.toIso8601String(),
      'isFavorite': isFavorite,
      'isDownloaded': isDownloaded,
      'playCount': playCount,
    };
  }

  factory AudioItem.fromJson(Map<String, dynamic> json) {
    return AudioItem(
      id: json['id'] as String,
      bvid: json['bvid'] as String,
      title: json['title'] as String,
      uploader: json['uploader'] as String,
      audioUrl: json['audioUrl'] as String,
      thumbnail: json['thumbnail'] as String,
      addedTime: DateTime.parse(json['addedTime'] as String),
      isFavorite: json['isFavorite'] as bool,
      isDownloaded: json['isDownloaded'] as bool,
      playCount: json['playCount'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioItem &&
          id == other.id &&
          bvid == other.bvid &&
          title == other.title &&
          uploader == other.uploader &&
          audioUrl == other.audioUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      bvid.hashCode ^
      title.hashCode ^
      uploader.hashCode ^
      audioUrl.hashCode;

  // 获取格式化的添加时间
  String get formattedAddedTime {
    final now = DateTime.now();
    final difference = now.difference(addedTime);

    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inHours < 1) return '${difference.inMinutes}分钟前';
    if (difference.inDays < 1) return '${difference.inHours}小时前';
    if (difference.inDays < 30) return '${difference.inDays}天前';
    return '${addedTime.year}-${addedTime.month}-${addedTime.day}';
  }

  // 获取缩略图，如果为空则返回默认图片
  String get safeThumnail {
    return thumbnail.isEmpty
        ? 'https://i0.hdslb.com/bfs/archive/0b2557b186a418cb3d8f307a5db85adb87bb25b0.jpg'
        : thumbnail;
  }
}
