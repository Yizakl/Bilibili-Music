import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/bilibili_service.dart';
import '../../../../core/models/user_model.dart';
import 'login_page.dart';
import 'browser_login_page.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _audioQualityKey = 'audio_quality';
  static const String _maxCacheSizeKey = 'max_cache_size';
  static const String _backgroundPlayKey = 'background_play';
  
  String _audioQuality = '标准';
  int _maxCacheSize = 1024; // MB
  bool _backgroundPlay = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserInfo();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _audioQuality = prefs.getString(_audioQualityKey) ?? '标准';
      _maxCacheSize = prefs.getInt(_maxCacheSizeKey) ?? 1024;
      _backgroundPlay = prefs.getBool(_backgroundPlayKey) ?? true;
    });
  }

  Future<void> _loadUserInfo() async {
    final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
    final userData = await bilibiliService.getUserInfo();
    setState(() {
      _user = userData;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioQualityKey, _audioQuality);
    await prefs.setInt(_maxCacheSizeKey, _maxCacheSize);
    await prefs.setBool(_backgroundPlayKey, _backgroundPlay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 用户信息卡
          _buildUserInfoCard(),
          
          const SizedBox(height: 20),
          
          // 播放器设置
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '播放器设置',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                
                SwitchListTile(
                  title: const Text('后台播放'),
                  subtitle: const Text('允许应用在后台继续播放音频'),
                  value: _backgroundPlay,
                  onChanged: (value) {
                    setState(() {
                      _backgroundPlay = value;
                    });
                    _saveSettings();
                  },
                ),
                
                ListTile(
                  title: const Text('音频质量'),
                  subtitle: Text(_audioQuality),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showAudioQualityDialog(),
                ),
                
                ListTile(
                  title: const Text('最大缓存大小'),
                  subtitle: Text('${_maxCacheSize} MB'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showCacheSizeDialog(),
                ),
              ],
            ),
          ),
          
          // 缓存设置
          const ListTile(
            title: Text('缓存设置'),
            tileColor: Colors.black12,
          ),
          ListTile(
            title: const Text('清除缓存'),
            subtitle: const Text('0MB'),  // TODO: 显示实际缓存大小
            onTap: _clearCache,
          ),

          // 关于
          const ListTile(
            title: Text('关于'),
            tileColor: Colors.black12,
          ),
          const ListTile(
            title: Text('版本'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            title: const Text('开源许可'),
            onTap: () {
              showLicensePage(context: context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    // 弹出选择对话框
    final loginMethod = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择登录方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('账号密码登录'),
              onTap: () => Navigator.pop(context, 'password'),
            ),
            ListTile(
              leading: const Icon(Icons.web),
              title: const Text('浏览器登录 (推荐)'),
              subtitle: const Text('使用B站网页登录，更加安全可靠'),
              onTap: () => Navigator.pop(context, 'browser'),
            ),
          ],
        ),
      ),
    );
    
    if (loginMethod == null) return;
    
    bool result = false;
    
    if (loginMethod == 'browser') {
      // 使用浏览器登录
      result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const BrowserLoginPage()),
      ) ?? false;
    } else if (loginMethod == 'password') {
      // 使用账号密码登录
      result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      ) ?? false;
    }
    
    if (result) {
      final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
      final userData = await bilibiliService.getUserInfo();
      setState(() {
        _user = userData;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
        );
      }
    }
  }
  
  Future<void> _handleLogout() async {
    final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await bilibiliService.logout();
      setState(() {
        _user = {
          'isLogin': false,
          'username': '',
          'avatar': '',
        };
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已退出登录')),
        );
      }
    }
  }

  void _showAudioQualityDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('音频质量'),
        children: [
          for (final quality in ['标准', '高质量', '超高质量'])
            RadioListTile<String>(
              title: Text(quality),
              value: quality,
              groupValue: _audioQuality,
              onChanged: (value) {
                setState(() {
                  _audioQuality = value!;
                  _saveSettings();
                });
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  void _showCacheSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('最大缓存空间'),
        children: [
          for (final size in [512, 1024, 2048, 4096])
            RadioListTile<int>(
              title: Text('${size}MB'),
              value: size,
              groupValue: _maxCacheSize,
              onChanged: (value) {
                setState(() {
                  _maxCacheSize = value!;
                  _saveSettings();
                });
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: 实现缓存清理
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清除')),
      );
    }
  }

  // 用户信息卡
  Widget _buildUserInfoCard() {
    final isLoggedIn = _user != null && _user!['isLogin'] == true;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: isLoggedIn && _user!['avatar'] != null && _user!['avatar'].isNotEmpty 
                ? NetworkImage(_user!['avatar'])
                : null,
              child: isLoggedIn ? null : const Icon(Icons.person),
            ),
            title: Text(
              isLoggedIn ? _user!['username'] : '未登录', 
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              isLoggedIn ? (_user!['isVip'] ? 'VIP用户' : '普通用户') : '登录以使用更多功能',
            ),
            trailing: isLoggedIn ? const Icon(Icons.check_circle, color: Colors.green) : null,
          ),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(isLoggedIn ? Icons.logout : Icons.login),
                label: Text(isLoggedIn ? '退出登录' : '登录'),
                onPressed: isLoggedIn ? _handleLogout : _handleLogin,
              ),
            ],
          ),
        ],
      ),
    );
  }
} 