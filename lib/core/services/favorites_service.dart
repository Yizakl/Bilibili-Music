import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_item.dart';

class FavoritesService extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const String _favoritesKey = 'favorites';
  List<VideoItem> _favorites = [];

  FavoritesService(this._prefs) {
    loadFavorites();
  }

  List<VideoItem> get favorites => _favorites;

  Future<void> loadFavorites() async {
    try {
      final String? favoritesJson = _prefs.getString(_favoritesKey);
      if (favoritesJson != null) {
        final List<dynamic> decoded = json.decode(favoritesJson);
        _favorites = decoded.map((item) => VideoItem.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载收藏失败: $e');
    }
  }

  // 保存收藏列表
  Future<void> _saveFavorites() async {
    try {
      final String encoded =
          json.encode(_favorites.map((v) => v.toJson()).toList());
      await _prefs.setString(_favoritesKey, encoded);
    } catch (e) {
      debugPrint('保存收藏失败: $e');
    }
  }

  // 添加收藏
  Future<void> addFavorite(VideoItem video) async {
    try {
      if (!isFavorite(video.id)) {
        _favorites.add(video);
        await _saveFavorites();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('添加收藏失败: $e');
    }
  }

  // 取消收藏
  Future<void> removeFavorite(String videoId) async {
    try {
      _favorites.removeWhere((video) => video.id == videoId);
      await _saveFavorites();
      notifyListeners();
    } catch (e) {
      debugPrint('移除收藏失败: $e');
    }
  }

  // 检查是否已收藏
  bool isFavorite(String videoId) {
    return _favorites.any((video) => video.id == videoId);
  }

  // 清空收藏列表
  Future<void> clearFavorites() async {
    try {
      _favorites.clear();
      await _saveFavorites();
      notifyListeners();
    } catch (e) {
      debugPrint('清空收藏失败: $e');
    }
  }
}
