import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum LyricSource { bilibili, netease, manual }

class LyricsService {
  final Dio _dio = Dio();

  Future<String?> fetchLyrics({
    required String title,
    required String artist,
    LyricSource source = LyricSource.netease,
  }) async {
    try {
      switch (source) {
        case LyricSource.bilibili:
          return await _fetchBilibiliLyrics(title, artist);
        case LyricSource.netease:
          return await _fetchNeteaseLyrics(title, artist);
        case LyricSource.manual:
          return null; // 手动输入歌词的占位
      }
    } catch (e) {
      if (kDebugMode) {
        print('获取歌词失败: $e');
      }
      return null;
    }
  }

  Future<String?> _fetchNeteaseLyrics(String title, String artist) async {
    try {
      final response = await _dio.get(
        'https://music.163.com/api/search/get/web',
        queryParameters: {
          's': '$title $artist',
          'type': 1,
          'limit': 1,
        },
      );

      // 解析网易云歌词 (这里需要根据实际API返回结构调整)
      final songId = response.data['result']['songs'][0]['id'];
      final lyricsResponse = await _dio.get(
        'https://music.163.com/api/song/lyric',
        queryParameters: {
          'id': songId,
          'lv': -1,
          'kv': -1,
          'tv': -1,
        },
      );

      return lyricsResponse.data['lrc']['lyric'];
    } catch (e) {
      if (kDebugMode) {
        print('获取网易云歌词失败: $e');
      }
      return null;
    }
  }

  Future<String?> _fetchBilibiliLyrics(String title, String artist) async {
    try {
      // 模拟B站字幕获取逻辑
      final response = await _dio.get(
        'https://api.bilibili.com/x/web-interface/search/all/v2',
        queryParameters: {
          'keyword': '$title $artist',
          'search_type': 'video',
        },
      );

      // 解析B站视频字幕 (这里需要根据实际API返回结构调整)
      final subtitles = response.data['data']['result']
          .where((item) => item['title'].contains(title))
          .map((item) => item['subtitle'])
          .toList();

      return subtitles.isNotEmpty ? subtitles.first : null;
    } catch (e) {
      if (kDebugMode) {
        print('获取B站字幕失败: $e');
      }
      return null;
    }
  }

  Future<String?> manuallyInputLyrics(String lyrics) async {
    // 手动输入歌词的处理逻辑
    return lyrics;
  }

  // 歌词同步和编辑功能
  String? synchronizeLyrics(String? originalLyrics, Duration offset) {
    if (originalLyrics == null) return null;

    // 简单的歌词时间戳偏移处理
    final lines = originalLyrics.split('\n');
    final adjustedLines = lines.map((line) {
      final timeMatch = RegExp(r'\[(\d+):(\d+\.\d+)\]').firstMatch(line);
      if (timeMatch != null) {
        final minutes = int.parse(timeMatch.group(1)!);
        final seconds = double.parse(timeMatch.group(2)!);

        // 应用时间偏移
        final totalSeconds =
            minutes * 60 + seconds + offset.inMilliseconds / 1000;

        final newMinutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
        final newSeconds =
            (totalSeconds % 60).toStringAsFixed(2).padLeft(5, '0');

        return line.replaceFirst(
            timeMatch.group(0)!, '[$newMinutes:$newSeconds]');
      }
      return line;
    }).toList();

    return adjustedLines.join('\n');
  }
}
