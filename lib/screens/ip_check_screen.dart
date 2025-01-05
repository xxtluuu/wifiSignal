import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class IpCheckScreen extends StatefulWidget {
  const IpCheckScreen({super.key});

  @override
  State<IpCheckScreen> createState() => _IpCheckScreenState();
}

class _IpCheckScreenState extends State<IpCheckScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // 只允许ipcheck.ing域名的请求
            if (request.url.startsWith('https://ipcheck.ing')) {
              return NavigationDecision.navigate;
            }
            // 阻止其他所有导航请求
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://ipcheck.ing'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公网IP检查'),
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
