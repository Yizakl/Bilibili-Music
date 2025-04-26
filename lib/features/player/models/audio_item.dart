class AudioItem {
  final String id;
  final String title;
  final String uploader;
  final String thumbnail;
  final String audioUrl;
  final DateTime addedTime;
  final bool isFavorite;
  final bool isDownloaded;
  final int? playCount;

  AudioItem({
    required this.id,
    required this.title,
    required this.uploader,
    required this.thumbnail,
    required this.audioUrl,
    required this.addedTime,
    this.isFavorite = false,
    this.isDownloaded = false,
    this.playCount,
  });

  AudioItem copyWith({
    String? id,
    String? title,
    String? uploader,
    String? thumbnail,
    String? audioUrl,
    DateTime? addedTime,
    bool? isFavorite,
    bool? isDownloaded,
    int? playCount,
  }) {
    return AudioItem(
      id: id ?? this.id,
      title: title ?? this.title,
      uploader: uploader ?? this.uploader,
      thumbnail: thumbnail ?? this.thumbnail,
      audioUrl: audioUrl ?? this.audioUrl,
      addedTime: addedTime ?? this.addedTime,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      playCount: playCount ?? this.playCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      title: json['title'] as String,
      uploader: json['uploader'] as String,
      thumbnail: json['thumbnail'] as String,
      audioUrl: json['audioUrl'] as String,
      addedTime: DateTime.parse(json['addedTime'] as String),
      isFavorite: json['isFavorite'] as bool,
      isDownloaded: json['isDownloaded'] as bool,
      playCount: json['playCount'] as int?,
    );
  }
} 