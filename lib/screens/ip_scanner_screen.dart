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
  final List<String> _activeIPs = [];
  bool _isScanning = false;
  String _localIP = '';
  double _progress = 0.0;
  late AnimationController _animationController;
  final _arpService = getIt<ARPService>();
  final ValueNotifier<int> _deviceCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // 立即开始新的扫描
    _startScan();
  }

  @override
  void dispose() {
    // 取消正在进行的扫描
    _arpService.cancel();
    _animationController.dispose();
    _deviceCount.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    // 如果正在扫描，先取消当前扫描
    if (_isScanning) {
      _arpService.cancel();
    }
    
    // 重置所有状态
    setState(() {
      _isScanning = true;
      _activeIPs.clear();
      _localIP = '';
      _progress = 0.0;
    });
    _deviceCount.value = 0;

    try {
      // 确保之前的扫描已经完全取消
      await Future.delayed(const Duration(milliseconds: 100));
      
      final devices = await _arpService.scanNetwork(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
        onDeviceFound: (device) {
          if (mounted) {
            setState(() {
              _activeIPs.add(device);
              _deviceCount.value = _activeIPs.length;
            });
          }
        },
      );
      
      if (mounted && !_arpService.isCancelled) {
        setState(() {
          if (devices.isNotEmpty) {
            _localIP = devices.first; // 第一个是本机IP
          }
        });
      }

    } catch (e) {
      debugPrint('扫描错误: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _progress = 1.0;
        });
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
                  Text(
                    '本机IP: $_localIP',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isScanning
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
                                CircularProgressIndicator(
                                  value: _progress,
                                  backgroundColor: Colors.grey[200],
                                  strokeWidth: 8,
                                  color: Colors.blue,
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
                              Text(
                                '${(_progress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
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
                          child: ListView.builder(
                            itemCount: _activeIPs.length,
                            itemBuilder: (context, index) {
                              final ip = _activeIPs[index];
                              return ListTile(
                                leading: const Icon(Icons.devices),
                                title: Text(ip),
                                subtitle: Text(ip == _localIP ? '(本机)' : '在线设备'),
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
          ],
        ),
      ),
    );
  }
}

// 自定义扫描动画画笔
class _ScannerPainter extends CustomPainter {
  final Color color;

  _ScannerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // 绘制雷达扫描线
    for (var i = 0; i < 4; i++) {
      final startAngle = (i * pi / 2);
      final sweepAngle = pi / 4;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScannerPainter oldDelegate) => false;
}
