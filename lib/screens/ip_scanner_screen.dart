import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import '../services/service_locator.dart';
import '../services/arp_service.dart';

class IpScannerScreen extends StatefulWidget {
  const IpScannerScreen({super.key});

  @override
  State<IpScannerScreen> createState() => _IpScannerScreenState();
}

class _IpScannerScreenState extends State<IpScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final _arpService = getIt<ARPService>();
  final ValueNotifier<bool> _isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<String> _localIP = ValueNotifier<String>('');
  final ValueNotifier<List<String>> _activeIPs = ValueNotifier<List<String>>([]);
  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);
  final ValueNotifier<int> _deviceCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // 立即开始新的扫描
    _startScan();
  }

  @override
  void dispose() {
    // 取消正在进行的扫描
    _arpService.cancel();
    _animationController.dispose();
    _isScanning.dispose();
    _localIP.dispose();
    _activeIPs.dispose();
    _progress.dispose();
    _deviceCount.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    // 如果正在扫描，先取消当前扫描
    if (_isScanning.value) {
      _arpService.cancel();
    }
    
    // 重置所有状态
    _isScanning.value = true;
    _localIP.value = '';
    _activeIPs.value = [];
    _progress.value = 0.0;
    _deviceCount.value = 0;

    try {
      // 确保之前的扫描已经完全取消
      await Future.delayed(const Duration(milliseconds: 100));
      
      final devices = await _arpService.scanNetwork(
        onProgress: (progress) {
          if (mounted) {
            _progress.value = progress;
          }
        },
        onDeviceFound: (device) {
          if (mounted) {
            if (!_activeIPs.value.contains(device)) {
              _activeIPs.value = [..._activeIPs.value, device];
              _deviceCount.value = _activeIPs.value.length;
            }
          }
        },
      );
      
      if (mounted && !_arpService.isCancelled) {
        if (devices.isNotEmpty) {
          _localIP.value = devices.first; // 第一个是本机IP
        }
      }

    } catch (e) {
      debugPrint('扫描错误: $e');
    } finally {
      if (mounted) {
        _isScanning.value = false;
        _progress.value = 1.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 返回前取消扫描
        _arpService.cancel();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('局域网IP扫描'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.computer, color: Colors.blue),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: _localIP,
                    builder: (context, localIP, child) {
                      return Text(
                        '本机IP: $localIP',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isScanning,
                builder: (context, isScanning, child) => isScanning
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 扫描动画
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 旋转的外圈
                                RotationTransition(
                                  turns: _animationController,
                                  child: CustomPaint(
                                    size: const Size(200, 200),
                                    painter: _ScannerPainter(
                                      color: Colors.blue.withOpacity(0.3),
                                    ),
                                  ),
                                ),
                                // 进度圈
                                ValueListenableBuilder<double>(
                                  valueListenable: _progress,
                                  builder: (context, progress, child) {
                                    return CircularProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey[200],
                                      strokeWidth: 8,
                                      color: Colors.blue,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          // 扫描信息
                          Column(
                            children: [
                              Icon(
                                Icons.wifi_find,
                                size: 40,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(height: 16),
                              ValueListenableBuilder<double>(
                                valueListenable: _progress,
                                builder: (context, progress, child) {
                                  return Text(
                                    '${(progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '正在扫描局域网设备...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ValueListenableBuilder<int>(
                                valueListenable: _deviceCount,
                                builder: (context, count, child) {
                                  return Text(
                                    '已发现 $count 个设备',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<List<String>>(
                            valueListenable: _activeIPs,
                            builder: (context, ips, child) {
                              return ValueListenableBuilder<String>(
                                valueListenable: _localIP,
                                builder: (context, localIP, child) {
                                  return ListView.builder(
                                    itemCount: ips.length,
                                    itemBuilder: (context, index) {
                                      final ip = ips[index];
                                      return ListTile(
                                        leading: const Icon(Icons.devices),
                                        title: Text(ip),
                                        subtitle: Text(ip == localIP ? '(本机)' : '在线设备'),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ValueListenableBuilder<int>(
                            valueListenable: _deviceCount,
                            builder: (context, count, child) {
                              return Text(
                                '已发现 $count 个在线设备',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 自定义扫描动画画笔
class _ScannerPainter extends CustomPainter {
  final Color color;
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  
  _ScannerPainter({required this.color}) {
    _paint.color = color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    
    // 使用Path一次性绘制所有扫描线
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final startAngle = (i * pi / 2);
      final sweepAngle = pi / 4;
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
      );
    }
    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(_ScannerPainter oldDelegate) => 
    oldDelegate.color != color;
}
