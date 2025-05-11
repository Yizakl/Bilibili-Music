import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/browser_login_helper.dart';

class BrowserLoginDialog extends StatefulWidget {
  const BrowserLoginDialog({Key? key}) : super(key: key);

  @override
  State<BrowserLoginDialog> createState() => _BrowserLoginDialogState();
}

class _BrowserLoginDialogState extends State<BrowserLoginDialog> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _webviewAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkWebviewAvailability();
  }

  Future<void> _checkWebviewAvailability() async {
    final available = await BrowserLoginHelper.isWebViewAvailable();
    if (mounted) {
      setState(() {
        _webviewAvailable = available;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // 使用WebView登录
  Future<void> _loginWithWebView() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await BrowserLoginHelper.loginWithWebView(
        context,
        (String cookieStr) async {
          debugPrint('获取到Cookie: $cookieStr');

          // 使用AuthService进行登录
          final authService = Provider.of<AuthService>(context, listen: false);
          final success = await authService.loginWithCookies({
            'Cookie': cookieStr,
          });

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
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '登录出错: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 使用系统浏览器登录
  Future<void> _loginWithSystemBrowser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = _urlController.text.trim();

      // 使用AuthService登录
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.loginWithBrowserUrl(url);

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

  // 打开系统浏览器
  void _openSystemBrowser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await BrowserLoginHelper.loginWithSystemBrowser();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '打开浏览器失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('浏览器登录'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_webviewAvailable) ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loginWithWebView,
                icon: const Icon(Icons.web),
                label: const Text('使用内置浏览器登录'),
              ),
              const SizedBox(height: 16),
              const Text(
                '- 或者 -',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _openSystemBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('打开系统浏览器登录'),
            ),
            const SizedBox(height: 24),
            const Text(
              '登录后，复制浏览器地址栏URL:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'https://www.bilibili.com/...',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入URL';
                }
                if (!value.contains('bilibili.com')) {
                  return '请输入有效的B站URL';
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _loginWithSystemBrowser,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('使用URL登录'),
        ),
      ],
    );
  }
}
