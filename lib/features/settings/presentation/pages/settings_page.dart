import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/models/user.dart';
import '../../../login/presentation/widgets/cookie_login_dialog.dart';
import '../../../login/presentation/widgets/browser_login_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isThemeDark = false;
  bool _isHighQualityEnabled = true;

  void _navigateToLogin() {
    context.push('/login');
  }

  void _showCantLoginOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('登录方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cookie_outlined),
              title: const Text('Cookie登录'),
              subtitle: const Text('手动输入B站Cookie进行登录'),
              onTap: () {
                Navigator.of(context).pop();
                _showCookieLoginDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('浏览器登录'),
              subtitle: const Text('通过浏览器登录并获取Cookie'),
              onTap: () {
                Navigator.of(context).pop();
                _showBrowserLoginDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showCookieLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => const CookieLoginDialog(),
    );
  }

  void _showBrowserLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => const BrowserLoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              context.go('/');
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // 用户信息部分
          if (authService.isLoggedIn && user != null)
            _buildUserInfoSection(user, authService)
          else
            _buildLoginPrompt(),

          const Divider(),

          // 常规设置
          ListTile(
            title: const Text('外观'),
            leading: const Icon(Icons.dark_mode),
            trailing: Switch(
              value: _isThemeDark,
              onChanged: (value) {
                setState(() {
                  _isThemeDark = value;
                });
              },
            ),
            subtitle: Text(_isThemeDark ? '暗色模式' : '亮色模式'),
          ),

          ListTile(
            title: const Text('音频质量'),
            leading: const Icon(Icons.high_quality),
            trailing: Switch(
              value: _isHighQualityEnabled,
              onChanged: (value) {
                setState(() {
                  _isHighQualityEnabled = value;
                });
              },
            ),
            subtitle: Text(_isHighQualityEnabled ? '高品质' : '标准品质'),
          ),

          const Divider(),

          // 关于
          ListTile(
            title: const Text('关于'),
            leading: const Icon(Icons.info_outline),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Bilibili Music',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(
                  Icons.music_note,
                  color: Colors.pink,
                  size: 40,
                ),
                children: [
                  const Text('一个简单的B站音频播放器。'),
                ],
              );
            },
          ),

          ListTile(
            title: const Text('检查更新'),
            leading: const Icon(Icons.system_update),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已是最新版本')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection(User user, AuthService authService) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue,
            child: Text(
              user.username.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 30,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.username,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'UID: ${user.id}',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          Text(
            'LV ${user.level}',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await authService.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Icon(
            Icons.account_circle,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '未登录',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '登录后可以同步您的B站收藏和历史记录',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _navigateToLogin,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 45),
            ),
            child: const Text('登录B站账号'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showCantLoginOptions,
            child: const Text('无法登录？'),
          ),
        ],
      ),
    );
  }
}
