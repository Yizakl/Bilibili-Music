import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final int mid;
  final String? uid;
  final String? username;
  final String? avatar;
  final bool isLoggedIn;
  final bool isVip;

  const UserModel({
    required this.mid,
    this.uid,
    this.username,
    this.avatar,
    this.isLoggedIn = false,
    this.isVip = false,
  });

  // 从本地存储加载用户信息
  static Future<UserModel> fromPrefs(SharedPreferences prefs) async {
    final uid = prefs.getString('user_uid');
    final username = prefs.getString('user_name');
    final avatar = prefs.getString('user_avatar');
    final isLoggedIn = prefs.getBool('user_logged_in') ?? false;
    final isVip = prefs.getBool('user_vip') ?? false;
    final mid = prefs.getInt('user_mid') ?? 0;

    return UserModel(
      mid: mid,
      uid: uid,
      username: username,
      avatar: avatar,
      isLoggedIn: isLoggedIn,
      isVip: isVip,
    );
  }

  // 保存用户信息到本地存储
  Future<void> saveToPrefs(SharedPreferences prefs) async {
    if (uid != null) await prefs.setString('user_uid', uid!);
    if (username != null) await prefs.setString('user_name', username!);
    if (avatar != null) await prefs.setString('user_avatar', avatar!);
    await prefs.setBool('user_logged_in', isLoggedIn);
    await prefs.setBool('user_vip', isVip);
    await prefs.setInt('user_mid', mid);
  }

  // 创建一个模拟登录的用户
  static UserModel mockLoggedInUser() {
    return UserModel(
      mid: 10086,
      uid: '10086',
      username: '测试用户',
      avatar: 'https://i0.hdslb.com/bfs/face/member/noface.jpg',
      isLoggedIn: true,
      isVip: false,
    );
  }

  // 登出
  static Future<void> logout(SharedPreferences prefs) async {
    await prefs.remove('user_uid');
    await prefs.remove('user_name');
    await prefs.remove('user_avatar');
    await prefs.setBool('user_logged_in', false);
    await prefs.setBool('user_vip', false);
    await prefs.remove('user_mid');
  }
} 