import 'package:intl/intl.dart';
import '../../features/player/models/audio_item.dart' as player_models;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class VideoItem {
  final String id; // BV号或AV号
  final String title; // 视频标题
  final String uploader; // UP主名称
  final String uploaderId; // UP主ID
  final String thumbnail; // 封面图URL
  final String description; // 视频描述
  final int? playCount; // 播放次数
  final int? likeCount; // 点赞数
  final int? coinCount; // 投币数
  final int? favoriteCount; // 收藏数
  final int? shareCount; // 分享数
  final int? commentCount; // 评论数
  final int? danmakuCount; // 弹幕数
  final String duration; // 视频时长，格式：00:00:00
  final DateTime? publishedAt; // 发布时间
  final List<String> tags; // 视频标签
  final String? cid; // 视频CID，用于获取弹幕
  final String? audioUrl; // 音频URL，可能为空
  final bool isLive; // 是否为直播
  final bool isAd; // 是否为广告
  final String publishDate; // 发布日期

  const VideoItem({
    required this.id,
    required this.title,
    required this.uploader,
    required this.uploaderId,
    required this.thumbnail,
    required this.playCount,
    required this.duration,
    required this.publishDate,
    this.description = '',
    this.likeCount,
    this.coinCount,
    this.favoriteCount,
    this.shareCount,
    this.commentCount,
    this.danmakuCount,
    this.publishedAt,
    this.tags = const [],
    this.cid,
    this.audioUrl,
    this.isLive = false,
    this.isAd = false,
  });

  // 获取修复后的缩略图URL
  String get fixedThumbnail {
    if (thumbnail.isEmpty) {
      return 'https://i0.hdslb.com/bfs/archive/1c471796343e25a9f76895e393d4e3d4e2f32d98.jpg';
    }
    return thumbnail.startsWith('//') ? 'https:$thumbnail' : thumbnail;
  }

  // 工厂构造函数，从JSON构建
  factory VideoItem.fromJson(Map<String, dynamic> json) {
    try {
      // 解析时间
      DateTime? publishTime;
      if (json['pubdate'] != null) {
        try {
          publishTime =
              DateTime.fromMillisecondsSinceEpoch(json['pubdate'] * 1000);
        } catch (e) {
          // 忽略解析错误
        }
      }

      // 创建标签列表
      List<String> tagList = [];
      if (json['tag'] != null && json['tag'] is String) {
        tagList = json['tag'].toString().split(',');
      } else if (json['tname'] != null) {
        tagList.add(json['tname'].toString());
      }

      // 获取视频时长
      String videoDuration = '00:00';
      if (json['duration'] != null) {
        if (json['duration'] is int) {
          final int seconds = json['duration'];
          final int minutes = seconds ~/ 60;
          final int remainingSeconds = seconds % 60;
          videoDuration =
              '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
        } else {
          videoDuration = json['duration'].toString();
        }
      }

      // 获取视频ID
      String videoId = '';
      if (json['bvid'] != null) {
        videoId = json['bvid'];
      } else if (json['aid'] != null) {
        videoId = 'av${json['aid']}';
      }

      return VideoItem(
        id: videoId,
        title: json['title'] ?? '未知标题',
        uploader: json['author'] ?? '未知UP主',
        uploaderId: json['mid']?.toString() ?? '',
        thumbnail: json['pic'] ?? '',
        playCount: json['play'] ?? 0,
        duration: videoDuration,
        publishDate: json['pubdate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['pubdate'] * 1000)
                .toString()
                .substring(0, 10)
            : '',
        description: json['desc'] ?? json['introduction'] ?? '',
        likeCount: json['like'] ?? json['stat']?['like'],
        coinCount: json['coin'] ?? json['stat']?['coin'],
        favoriteCount: json['favorite'] ?? json['stat']?['favorite'],
        shareCount: json['share'] ?? json['stat']?['share'],
        commentCount: json['reply'] ?? json['stat']?['reply'],
        danmakuCount: json['danmaku'] ?? json['stat']?['danmaku'],
        publishedAt: publishTime,
        tags: tagList,
        cid: json['cid']?.toString(),
        audioUrl: json['url'] ?? '',
        isLive: json['live'] == 1,
        isAd: json['isad'] == 1,
      );
    } catch (e) {
      // 解析失败时返回基本数据
      return VideoItem(
        id: json['bvid'] ?? json['aid']?.toString() ?? '未知ID',
        title: json['title'] ?? '未知标题',
        uploader: json['author'] ?? '未知UP主',
        uploaderId: json['mid']?.toString() ?? '',
        thumbnail: json['pic'] ?? '',
        playCount: json['play'] ?? 0,
        duration: _formatDuration(
            int.tryParse(json['duration']?.toString() ?? '0') ?? 0),
        publishDate: json['pubdate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['pubdate'] * 1000)
                .toString()
                .substring(0, 10)
            : '',
      );
    }
  }

  // 将播放次数格式化为友好的字符串
  String get formattedPlayCount {
    if (playCount == null) return '0';
    if (playCount! < 10000) return playCount.toString();
    if (playCount! < 100000000) {
      return '${(playCount! / 10000).toStringAsFixed(1)}万';
    }
    return '${(playCount! / 100000000).toStringAsFixed(1)}亿';
  }

  // 复制并创建一个新对象，可选择性地更新某些字段
  VideoItem copyWith({
    String? id,
    String? title,
    String? uploader,
    String? uploaderId,
    String? thumbnail,
    String? description,
    int? playCount,
    int? likeCount,
    int? coinCount,
    int? favoriteCount,
    int? shareCount,
    int? commentCount,
    int? danmakuCount,
    String? duration,
    DateTime? publishedAt,
    List<String>? tags,
    String? cid,
    String? audioUrl,
    bool? isLive,
    bool? isAd,
    String? publishDate,
  }) {
    return VideoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      uploader: uploader ?? this.uploader,
      uploaderId: uploaderId ?? this.uploaderId,
      thumbnail: thumbnail ?? this.thumbnail,
      description: description ?? this.description,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      coinCount: coinCount ?? this.coinCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      shareCount: shareCount ?? this.shareCount,
      commentCount: commentCount ?? this.commentCount,
      danmakuCount: danmakuCount ?? this.danmakuCount,
      duration: duration ?? this.duration,
      publishedAt: publishedAt ?? this.publishedAt,
      tags: tags ?? this.tags,
      cid: cid ?? this.cid,
      audioUrl: audioUrl ?? this.audioUrl,
      isLive: isLive ?? this.isLive,
      isAd: isAd ?? this.isAd,
      publishDate: publishDate ?? this.publishDate,
    );
  }

  // 转换为AudioItem对象
  player_models.AudioItem toAudioItem() {
    return player_models.AudioItem(
      id: id,
      title: title,
      uploader: uploader,
      thumbnail: thumbnail,
      audioUrl: '',
      addedTime: DateTime.now(),
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'bvid': id,
      'title': title,
      'author': uploader,
      'mid': uploaderId,
      'pic': thumbnail,
      'play': playCount,
      'duration': duration,
      'pubdate': publishDate,
      'description': description,
      'likeCount': likeCount,
      'coinCount': coinCount,
      'favoriteCount': favoriteCount,
      'shareCount': shareCount,
      'commentCount': commentCount,
      'danmakuCount': danmakuCount,
      'publishedAt': publishedAt?.millisecondsSinceEpoch,
      'tags': tags,
      'cid': cid,
      'audioUrl': audioUrl,
      'isLive': isLive,
      'isAd': isAd,
    };
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
