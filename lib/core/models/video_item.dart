import 'package:intl/intl.dart';
import '../../features/player/models/audio_item.dart' as player_models;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class VideoItem {
  final String id;
  final String bvid;
  final String title;
  final String uploader;
  final String? thumbnail;
  final Duration duration;
  final DateTime uploadTime;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final String? cid;

  VideoItem({
    required this.id,
    required this.bvid,
    required this.title,
    required this.uploader,
    this.thumbnail,
    required this.duration,
    required this.uploadTime,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    this.cid,
  });

  String get fixedThumbnail {
    if (thumbnail == null || thumbnail!.isEmpty) {
      return 'https://i0.hdslb.com/bfs/archive/0b2557b186a418cb3d8f307a5db85adb87bb25b0.jpg';
    }
    return thumbnail!;
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['bvid'] ?? '',
      bvid: json['bvid'] ?? '',
      title: json['title'] ?? '',
      uploader: json['owner']?['name'] ?? '',
      thumbnail: json['pic'],
      duration: Duration(seconds: json['duration'] ?? 0),
      uploadTime:
          DateTime.fromMillisecondsSinceEpoch((json['pubdate'] ?? 0) * 1000),
      viewCount: json['stat']?['view'] ?? 0,
      likeCount: json['stat']?['like'] ?? 0,
      commentCount: json['stat']?['reply'] ?? 0,
      cid: json['cid']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bvid': bvid,
      'title': title,
      'uploader': uploader,
      'thumbnail': thumbnail,
      'duration': duration.inSeconds,
      'uploadTime': uploadTime.millisecondsSinceEpoch,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'cid': cid,
    };
  }

  // 将播放次数格式化为友好的字符串
  String get formattedPlayCount {
    if (viewCount < 10000) return viewCount.toString();
    if (viewCount < 100000000) {
      return '${(viewCount / 10000).toStringAsFixed(1)}万';
    }
    return '${(viewCount / 100000000).toStringAsFixed(1)}亿';
  }

  // 复制并创建一个新对象，可选择性地更新某些字段
  VideoItem copyWith({
    String? id,
    String? bvid,
    String? title,
    String? uploader,
    String? thumbnail,
    Duration? duration,
    DateTime? uploadTime,
    int? viewCount,
    int? likeCount,
    int? commentCount,
    String? cid,
  }) {
    return VideoItem(
      id: id ?? this.id,
      bvid: bvid ?? this.bvid,
      title: title ?? this.title,
      uploader: uploader ?? this.uploader,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration ?? this.duration,
      uploadTime: uploadTime ?? this.uploadTime,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      cid: cid ?? this.cid,
    );
  }

  // 转换为AudioItem对象
  player_models.AudioItem toAudioItem({String? audioUrl}) {
    return player_models.AudioItem(
      id: id,
      title: title,
      uploader: uploader,
      thumbnail: thumbnail ?? '',
      audioUrl: audioUrl ?? '',
      addedTime: DateTime.now(),
    );
  }

  static String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  static String _formatDate(int timestamp) {
    if (timestamp == 0) return '';

    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }
}
