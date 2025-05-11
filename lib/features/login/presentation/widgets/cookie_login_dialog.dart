import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/browser_login_helper.dart';

class CookieLoginDialog extends StatefulWidget {
  const CookieLoginDialog({Key? key}) : super(key: key);

  @override
  State<CookieLoginDialog> createState() => _CookieLoginDialogState();
}

class _CookieLoginDialogState extends State<CookieLoginDialog>
    with SingleTickerProviderStateMixin {
  final _cookieController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  Future<void> _loginWithCookie() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 解析Cookie字符串
      final cookieStr = _cookieController.text.trim();
      final Map<String, String> cookies = {};

      // 处理多行或分号分隔的cookie
      final cookieParts = cookieStr.replaceAll('\n', ';').split(';');
      for (var part in cookieParts) {
        part = part.trim();
        if (part.contains('=')) {
          final keyValue = part.split('=');
          if (keyValue.length >= 2) {
            final key = keyValue[0].trim();
            final value = keyValue[1].trim();
            cookies[key] = value;
          }
        }
      }

      if (cookies.isEmpty) {
        setState(() {
          _errorMessage = '无法解析Cookie，请检查格式';
          _isLoading = false;
        });
        return;
      }

      // 检查是否有必要的Cookie
      if (!cookies.containsKey('SESSDATA') ||
          !cookies.containsKey('bili_jct') ||
          !cookies.containsKey('DedeUserID')) {
        setState(() {
          _errorMessage = '缺少必要的Cookie (SESSDATA, bili_jct, DedeUserID)';
          _isLoading = false;
        });
        return;
      }

      // 使用AuthService登录
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.loginWithCookies(cookies);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true); // 返回true表示登录成功
        } else {
          setState(() {
            _errorMessage = '登录失败: ${authService.error}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '登录出错: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cookie登录'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '请输入B站的Cookie',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cookieController,
              decoration: const InputDecoration(
                hintText: 'SESSDATA=xxx; bili_jct=xxx; DedeUserID=xxx',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              minLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入Cookie';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '获取方法：\n'
              '1. 在电脑浏览器中登录B站\n'
              '2. 按F12打开开发者工具\n'
              '3. 找到"应用"或"Application"选项卡\n'
              '4. 在左侧找到"Cookies"\n'
              '5. 复制SESSDATA、bili_jct和DedeUserID的值',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _loginWithCookie,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录'),
        ),
      ],
    );
  }
}
