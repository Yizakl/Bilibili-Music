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
    try {
      String id = '';
      if (json['bvid'] != null) {
        id = json['bvid'].toString();
      } else if (json['id'] != null) {
        id = json['id'].toString();
      } else if (json['aid'] != null) {
        id = 'av${json['aid']}';
      }

      String uploader = '';
      if (json['owner'] != null && json['owner']['name'] != null) {
        uploader = json['owner']['name'].toString();
      } else if (json['author'] != null) {
        uploader = json['author'].toString();
      } else if (json['uploader'] != null) {
        uploader = json['uploader'].toString();
      }

      Duration duration = Duration.zero;
      if (json['duration'] != null) {
        if (json['duration'] is int) {
          duration = Duration(seconds: json['duration']);
        } else if (json['duration'] is String) {
          try {
            String durationStr = json['duration'];
            if (durationStr.contains(':')) {
              List<String> parts = durationStr.split(':');
              if (parts.length == 2) {
                int minutes = int.tryParse(parts[0]) ?? 0;
                int seconds = int.tryParse(parts[1]) ?? 0;
                duration = Duration(seconds: minutes * 60 + seconds);
              }
            } else {
              duration = Duration(seconds: int.tryParse(durationStr) ?? 0);
            }
          } catch (e) {
            debugPrint('解析视频时长失败: $e');
            duration = Duration.zero;
          }
        }
      }

      DateTime uploadTime = DateTime.now();
      if (json['pubdate'] != null) {
        try {
          if (json['pubdate'] is int) {
            uploadTime =
                DateTime.fromMillisecondsSinceEpoch(json['pubdate'] * 1000);
          } else if (json['pubdate'] is String) {
            int timestamp = int.tryParse(json['pubdate']) ?? 0;
            uploadTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          }
        } catch (e) {
          debugPrint('解析上传时间失败: $e');
          uploadTime = DateTime.now();
        }
      } else if (json['uploadTime'] != null) {
        try {
          if (json['uploadTime'] is int) {
            uploadTime =
                DateTime.fromMillisecondsSinceEpoch(json['uploadTime']);
          }
        } catch (e) {
          debugPrint('解析上传时间失败: $e');
        }
      }

      int viewCount = 0;
      if (json['stat'] != null && json['stat']['view'] != null) {
        if (json['stat']['view'] is int) {
          viewCount = json['stat']['view'];
        } else if (json['stat']['view'] is String) {
          viewCount = int.tryParse(json['stat']['view']) ?? 0;
        }
      } else if (json['viewCount'] != null) {
        if (json['viewCount'] is int) {
          viewCount = json['viewCount'];
        } else if (json['viewCount'] is String) {
          viewCount = int.tryParse(json['viewCount']) ?? 0;
        }
      }

      int likeCount = 0;
      if (json['stat'] != null && json['stat']['like'] != null) {
        if (json['stat']['like'] is int) {
          likeCount = json['stat']['like'];
        } else if (json['stat']['like'] is String) {
          likeCount = int.tryParse(json['stat']['like']) ?? 0;
        }
      } else if (json['likeCount'] != null) {
        if (json['likeCount'] is int) {
          likeCount = json['likeCount'];
        } else if (json['likeCount'] is String) {
          likeCount = int.tryParse(json['likeCount']) ?? 0;
        }
      }

      int commentCount = 0;
      if (json['stat'] != null && json['stat']['reply'] != null) {
        if (json['stat']['reply'] is int) {
          commentCount = json['stat']['reply'];
        } else if (json['stat']['reply'] is String) {
          commentCount = int.tryParse(json['stat']['reply']) ?? 0;
        }
      } else if (json['commentCount'] != null) {
        if (json['commentCount'] is int) {
          commentCount = json['commentCount'];
        } else if (json['commentCount'] is String) {
          commentCount = int.tryParse(json['commentCount']) ?? 0;
        }
      }

      String? cid = null;
      if (json['cid'] != null) {
        cid = json['cid'].toString();
      }

      return VideoItem(
        id: id,
        bvid: id,
        title: json['title'] ?? '',
        uploader: uploader,
        thumbnail: json['pic'] ?? json['cover'] ?? json['thumbnail'] ?? null,
        duration: duration,
        uploadTime: uploadTime,
        viewCount: viewCount,
        likeCount: likeCount,
        commentCount: commentCount,
        cid: cid,
      );
    } catch (e) {
      debugPrint('VideoItem.fromJson解析失败: $e');
      // 返回一个基本的VideoItem对象，避免完全失败
      return VideoItem(
        id: json['bvid'] ?? 'unknown',
        bvid: json['bvid'] ?? 'unknown',
        title: json['title'] ?? '未知标题',
        uploader: '未知UP主',
        thumbnail: null,
        duration: Duration.zero,
        uploadTime: DateTime.now(),
        viewCount: 0,
        likeCount: 0,
        commentCount: 0,
      );
    }
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
