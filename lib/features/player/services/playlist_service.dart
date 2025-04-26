import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/audio_item.dart';

class PlaylistService {
  static const String _favoritesKey = 'favorites';
  static const String _historyKey = 'history';
  static const String _downloadsKey = 'downloads';
  
  final SharedPreferences _prefs;
  final _favoritesController = StreamController<List<AudioItem>>.broadcast();
  final _historyController = StreamController<List<AudioItem>>.broadcast();
  final _downloadsController = StreamController<List<AudioItem>>.broadcast();

  List<AudioItem> _favorites = [];
  List<AudioItem> _history = [];
  List<AudioItem> _downloads = [];

  PlaylistService(SharedPreferences prefs) : _prefs = prefs {
    _loadData();
  }
  Stream<List<AudioItem>> get favoritesStream => _favoritesController.stream;
  Stream<List<AudioItem>> get historyStream => _historyController.stream;
  Stream<List<AudioItem>> get downloadsStream => _downloadsController.stream;

  // 获取当前数据
  List<AudioItem> get favorites => List.unmodifiable(_favorites);
  List<AudioItem> get history => List.unmodifiable(_history);
  List<AudioItem> get downloads => List.unmodifiable(_downloads);

  // 加载数据
  Future<void> _loadData() async {
    _favorites = _loadItems(_favoritesKey);
    _history = _loadItems(_historyKey);
    _downloads = _loadItems(_downloadsKey);
    
    _notifyListeners();
  }

  List<AudioItem> _loadItems(String key) {
    final String? data = _prefs.getString(key);
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = json.decode(data);
      return jsonList.map((item) => AudioItem.fromJson(item)).toList();
    } catch (e) {
      print('Error loading $key: $e');
      return [];
    }
  }

  // 保存数据
  Future<void> _saveItems(String key, List<AudioItem> items) async {
    final String data = json.encode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(key, data);
  }

  // 添加到收藏
  Future<void> addToFavorites(AudioItem item) async {
    if (!_favorites.any((e) => e.id == item.id)) {
      _favorites.insert(0, item.copyWith(isFavorite: true));
      await _saveItems(_favoritesKey, _favorites);
      _notifyListeners();
    }
  }

  // 从收藏中移除
  Future<void> removeFromFavorites(String id) async {
    _favorites.removeWhere((item) => item.id == id);
    await _saveItems(_favoritesKey, _favorites);
    _notifyListeners();
  }

  // 添加到历史记录
  Future<void> addToHistory(AudioItem item) async {
    _history.removeWhere((e) => e.id == item.id);
    _history.insert(0, item);
    if (_history.length > 100) {
      _history = _history.take(100).toList();
    }
    await _saveItems(_historyKey, _history);
    _notifyListeners();
  }

  // 清空历史记录
  Future<void> clearHistory() async {
    _history.clear();
    await _saveItems(_historyKey, _history);
    _notifyListeners();
  }

  // 添加到下载
  Future<void> addToDownloads(AudioItem item) async {
    if (!_downloads.any((e) => e.id == item.id)) {
      _downloads.insert(0, item.copyWith(isDownloaded: true));
      await _saveItems(_downloadsKey, _downloads);
      _notifyListeners();
    }
  }

  // 从下载中移除
  Future<void> removeFromDownloads(String id) async {
    _downloads.removeWhere((item) => item.id == id);
    await _saveItems(_downloadsKey, _downloads);
    _notifyListeners();
  }

  void _notifyListeners() {
    _favoritesController.add(_favorites);
    _historyController.add(_history);
    _downloadsController.add(_downloads);
  }

  void dispose() {
    _favoritesController.close();
    _historyController.close();
    _downloadsController.close();
  }
} 