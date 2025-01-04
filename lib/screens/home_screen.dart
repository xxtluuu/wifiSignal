import 'package:flutter/material.dart';
import '../services/wifi_scanner.dart';
import '../models/wifi_network.dart';
import '../widgets/wifi_list_item.dart';
import '../widgets/wifi_signal_display.dart';
import 'dart:io' show Platform;
import 'channel_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WifiScanner _scanner = WifiScanner();
  bool _isLoading = false;
  bool _isMonitoring = false;
  WifiNetwork? _currentNetwork;

  @override
  void initState() {
    super.initState();
    _loadCurrentNetwork();
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentNetwork() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    try {
      final network = await _scanner.getCurrentNetwork();
      setState(() => _currentNetwork = network);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('获取WiFi信息出错: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi信号优化助手'),
        actions: [
          // 信道分析入口
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChannelAnalysisScreen(),
                ),
              );
            },
            tooltip: '信道分析',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadCurrentNetwork,
            tooltip: '刷新WiFi信息',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCurrentNetwork,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_currentNetwork != null) ...[
                        // 信号监测控制按钮
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isMonitoring = !_isMonitoring;
                                if (_isMonitoring) {
                                  _scanner.startMonitoring();
                                } else {
                                  _scanner.stopMonitoring();
                                }
                              });
                            },
                            icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                            label: Text(_isMonitoring ? '停止监测' : '开始监测'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        
                        // 实时信号显示
                        if (_isMonitoring)
                          WifiSignalDisplay(wifiScanner: _scanner),
                        
                        const SizedBox(height: 16),
                        
                        // 当前网络信息卡片
                        Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.wifi, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      '当前WiFi连接',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                WifiListItem(network: _currentNetwork!),
                                if (Platform.isIOS)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      '注：由于iOS系统限制，部分WiFi信息可能无法获取',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ] else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.wifi_off,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '未连接到WiFi网络',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (Platform.isIOS)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      '请确保已开启WiFi并连接到网络',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
