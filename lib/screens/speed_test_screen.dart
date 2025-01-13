import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
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
            // 只允许cloudflare speed test域名的请求
            if (request.url.contains('speed.cloudflare.com')) {
              return NavigationDecision.navigate;
            }
            // 阻止其他所有导航请求
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://speed.cloudflare.com'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网速测试'),
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
