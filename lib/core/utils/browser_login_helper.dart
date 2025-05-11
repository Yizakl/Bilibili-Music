import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 浏览器登录辅助类
/// 提供WebView内嵌登录和系统浏览器登录两种方式
class BrowserLoginHelper {
  /// B站登录URL
  static const String bilibiliLoginUrl = 'https://passport.bilibili.com/login';

  /// 检查WebView是否可用
  static Future<bool> isWebViewAvailable() async {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// 使用WebView登录
  /// [context] 上下文
  /// [onCookieReceived] 获取到Cookie后的回调
  static Future<void> loginWithWebView(
    BuildContext context,
    Function(String) onCookieReceived,
  ) async {
    // 创建WebViewController
    WebViewController controller = WebViewController();

    // 设置JavaScript模式
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    // 设置导航委托
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String url) async {
          debugPrint('页面加载完成: $url');

          if (url.contains('bilibili.com')) {
            // 获取Cookie
            final cookies = await controller.runJavaScriptReturningResult(
              "document.cookie",
            );

            String cookieStr = cookies.toString();
            debugPrint('获取到Cookie: $cookieStr');

            if (cookieStr.contains('SESSDATA') &&
                cookieStr.contains('bili_jct') &&
                cookieStr.contains('DedeUserID')) {
              // 回调
              onCookieReceived(cookieStr);

              // 关闭WebView
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          // 允许所有导航请求
          return NavigationDecision.navigate;
        },
      ),
    );

    // 加载B站登录URL
    controller.loadRequest(Uri.parse(bilibiliLoginUrl));

    // 显示WebView
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('哔哩哔哩登录'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: WebViewWidget(controller: controller),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  /// 使用系统浏览器登录
  static Future<void> loginWithSystemBrowser() async {
    final Uri url = Uri.parse(bilibiliLoginUrl);
    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }
}
